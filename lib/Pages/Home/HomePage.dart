import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:another_telephony/telephony.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;

const MethodChannel smsChannel = MethodChannel("com.smsecure.app/sms");

class CustomSmsMessage {
  final String senderNumber;
  final String messageBody;
  final int dateSent;

  CustomSmsMessage({
    required this.senderNumber,
    required this.messageBody,
    required this.dateSent,
  });
}


void _initializeSmsListener() {
  smsChannel.setMethodCallHandler((call) async {
    if (call.method == "onSmsReceived") {
      try {
        // Ensure the arguments are properly formatted
        final Map<String, dynamic> smsData = Map<String, dynamic>.from(call.arguments);

        // Extract SMS data
        String senderNumber = smsData["senderNumber"] ?? "Unknown";
        String messageBody = smsData["messageBody"] ?? "No Content";
        final dateSent = smsData["dateSent"] ?? DateTime.now().millisecondsSinceEpoch;

        print("Received SMS in Flutter: $messageBody from $senderNumber");

        // Create a `CustomSmsMessage` object
        final CustomSmsMessage message = CustomSmsMessage(
          senderNumber: senderNumber,
          messageBody: messageBody,
          dateSent: dateSent,
        );

        // Pass the data to your background handler
        await backgroundMessageHandler(message);
      } catch (e) {
        print("Error processing incoming SMS: $e");
      }
    } else {
      print("Unknown method call received: ${call.method}");
    }
  });
}

Future<void> handleIncomingSms(SmsMessage smsMessage) async {
  final CustomSmsMessage customSmsMessage = CustomSmsMessage(
    senderNumber: smsMessage.address ?? "",
    messageBody: smsMessage.body ?? "",
    dateSent: smsMessage.dateSent ?? DateTime.now().millisecondsSinceEpoch,
  );

  // Call your original backgroundMessageHandler
  await backgroundMessageHandler(customSmsMessage);
}


Future<void> backgroundMessageHandler(CustomSmsMessage message) async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final firestore = FirebaseFirestore.instance;

  // Step 1: Retrieve userPhone
  String userPhone = '';
  try {
    userPhone = await secureStorage.read(key: "userPhone") ?? "";
    if (userPhone.isEmpty) {
      print("Error: userPhone is not set in secure storage.");
      return;
    }
  } catch (e) {
    print("Error reading userPhone from secure storage: $e");
    return;
  }

  // Step 2: Retrieve smsUserID
  String? smsUserID;
  try {
    smsUserID = await getSmsUserID(userPhone);
    if (smsUserID == null) {
      print("Error: smsUserID could not be retrieved for userPhone: $userPhone.");
      return;
    }
  } catch (e) {
    print("Error fetching smsUserID: $e");
    return;
  }

  // Step 3: Format phone numbers
  String senderPhoneNumber = message.senderNumber;
  if (!senderPhoneNumber.startsWith('+')) senderPhoneNumber = '+$senderPhoneNumber';
  if (!userPhone.startsWith('+')) userPhone = '+$userPhone';

  print("User Phone: $userPhone");
  print("Sender Phone Number: $senderPhoneNumber");
  print("smsUserID: $smsUserID");

  // Step 4: Check if sender is whitelisted for the current smsUserID
  final whitelistSnapshot = await firestore
      .collection('whitelist')
      .where('smsUserID', isEqualTo: smsUserID)
      .where('phoneNo', isEqualTo: senderPhoneNumber)
      .get();

  bool isWhitelisted = whitelistSnapshot.docs.isNotEmpty;

  if (isWhitelisted) {
    print("Sender is whitelisted for smsUserID: $smsUserID. Skipping spam detection.");
  } else {
    // Step 5: Check if sender is blacklisted for the current smsUserID
    final blacklistSnapshot = await firestore
        .collection('blacklist')
        .where('smsUserID', isEqualTo: smsUserID)
        .where('phoneNo', isEqualTo: senderPhoneNumber)
        .get();

    bool isBlacklisted = blacklistSnapshot.docs.isNotEmpty;

    // Generate conversationID
    final participants = [userPhone, senderPhoneNumber];
    participants.sort();
    final conversationID = participants.join('_');

    if (isBlacklisted) {
      print("Sender is blacklisted for smsUserID: $smsUserID.");

      // Check if the conversation exists
      final conversationSnapshot = await firestore
          .collection('conversations')
          .doc(conversationID)
          .get();

      if (!conversationSnapshot.exists) {
        print("Creating new blacklisted conversation with ID: $conversationID.");
        await firestore.collection('conversations').doc(conversationID).set({
          'participants': participants,
          'smsUserID': smsUserID,
          'lastMessageTimeStamp': Timestamp.now(),
          'isBlacklisted': true,
          'isSpam': false,
        });
      } else if (conversationSnapshot.get('isBlacklisted') != true) {
        print("Updating conversation to blacklisted for ID: $conversationID.");
        await firestore
            .collection('conversations')
            .doc(conversationID)
            .update({'isBlacklisted': true});
      }

      // Add the message to the blacklisted conversation
      final messageID = '${message.dateSent}_$senderPhoneNumber';
      await firestore
          .collection('conversations')
          .doc(conversationID)
          .collection('messages')
          .doc(messageID)
          .set({
        'messageID': messageID,
        'senderID': senderPhoneNumber,
        'content': message.messageBody,
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(message.dateSent),
        'isIncoming': true,
        'isBlacklisted': true,
      }, SetOptions(merge: true));
      return; // Exit as the sender is blacklisted
    }

    // Perform spam detection for non-whitelisted and non-blacklisted users
    final predictionRequest = {
      'message': message.messageBody,
      'senderPhone': senderPhoneNumber,
    };

    try {
      final response = await http.post(
        Uri.parse('http://192.168.101.80:5000/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(predictionRequest),
      );
      print("Prediction API response status: ${response.statusCode}");
      print("Prediction API response body: ${response.body}");

      if (response.statusCode == 200) {
        final predictionResult = json.decode(response.body);
        bool isSpam = predictionResult['isSpam'] ?? false;
        String? keyword = predictionResult['keyword'] ?? "unknown";
        double confidenceLevel =
            (predictionResult['confidenceLevel'] ?? 0.0).toDouble();
        double processingTime =
            (predictionResult['processingTime'] ?? 0.0).toDouble();

        print(
            "Is Spam: $isSpam, Keyword: $keyword, Confidence: $confidenceLevel");

        if (isSpam) {
          print("Adding to spamContact collection.");
          try {
            String? senderName;

            // Check in the user's contact collection
            final contactSnapshot = await firestore
                .collection('contact')
                .where('smsUserID', isEqualTo: smsUserID)
                .where('phoneNo', isEqualTo: senderPhoneNumber)
                .get();

            if (contactSnapshot.docs.isNotEmpty) {
              senderName = contactSnapshot.docs.first.get('name');
              for (var doc in contactSnapshot.docs) {
                try {
                  await doc.reference.update({'isSpam': true});
                } catch (e) {
                  print("Error updating isSpam field for contact: ${doc.id}, Error: $e");
                }
              }
            }

            senderName ??= "Unknown"; 

            final spamContactQuery = await firestore
                .collection('spamContact')
                .where('smsUserID', isEqualTo: smsUserID)
                .where('phoneNo', isEqualTo: senderPhoneNumber)
                .get();

            String spamContactID;
            if (spamContactQuery.docs.isEmpty) {
              final newDoc = await firestore.collection('spamContact').add({
                'smsUserID': smsUserID,
                'phoneNo': senderPhoneNumber,
                'name': senderName,
                'isRemoved': false,
              });
              spamContactID = newDoc.id;
            } else {
              spamContactID = spamContactQuery.docs.first.id;
            }

            final spamMessageID = '${message.dateSent}_$senderPhoneNumber';
            await firestore
                .collection('spamContact')
                .doc(spamContactID)
                .collection('spamMessages')
                .doc(spamMessageID)
                .set({
              'spamMessageID': spamMessageID,
              'messages': message.messageBody,
              'keyword': keyword,
              'confidenceLevel': confidenceLevel.toStringAsFixed(4),
              'detectedAt': Timestamp.now(),
              'processingTime': processingTime,
            });

          await firestore.collection('conversations').doc(conversationID).set({
            'participants': participants,
            'smsUserID': smsUserID,
            'lastMessageTimeStamp': Timestamp.now(),
            'isSpam': true,
            'isBlacklisted': false,
          }, SetOptions(merge: true));

          final messageID = '${message.dateSent}_$senderPhoneNumber';
          await firestore
              .collection('conversations')
              .doc(conversationID)
              .collection('messages')
              .doc(messageID)
              .set({
            'messageID': messageID,
            'senderID': senderPhoneNumber,
            'content': message.messageBody,
            'timestamp': Timestamp.fromMillisecondsSinceEpoch(message.dateSent),
            'isIncoming': true,
            'isBlacklisted': false,
          }, SetOptions(merge: true));

          return; 

          } catch (e) {
            print("Error adding to spamContact collection: $e");
          }
        }
      }
    } catch (e) {
      print("HTTP request error during spam detection: $e");
    }
  }

  // Step 6: Store all messages in conversations and messages collections
  try {
    final participants = [userPhone, senderPhoneNumber];
    participants.sort();
    final conversationID = participants.join('_');

    final conversationSnapshot = await firestore
        .collection('conversations')
        .where('smsUserID', isEqualTo: smsUserID)
        .where('participants', arrayContains: senderPhoneNumber)
        .get();

    if (conversationSnapshot.docs.isEmpty) {
      await firestore.collection('conversations').doc(conversationID).set({
        'participants': participants,
        'smsUserID': smsUserID,
        'lastMessageTimeStamp': Timestamp.now(),
        'isBlacklisted': false,
        'isSpam': false,
      });
    } else {
      await firestore
          .collection('conversations')
          .doc(conversationID)
          .update({
        'lastMessageTimeStamp': Timestamp.now(),
      });
    }

    final messageID = '${message.dateSent}_$senderPhoneNumber';
    await firestore
        .collection('conversations')
        .doc(conversationID)
        .collection('messages')
        .doc(messageID)
        .set({
      'messageID': messageID,
      'senderID': senderPhoneNumber,
      'content': message.messageBody,
      'timestamp': Timestamp.fromMillisecondsSinceEpoch(message.dateSent),
      'isIncoming': true,
      'isBlacklisted': false,
    }, SetOptions(merge: true));
  } catch (e) {
    print("Error adding message to conversations: $e");
  }
}




Future<String?> getSmsUserID(String userPhone) async {
  final firestore = FirebaseFirestore.instance;

  // Query Firestore to get the document for the given phone number
  final snapshot = await firestore
      .collection('smsUser')
      .where('phoneNo', isEqualTo: userPhone)
      .limit(1)
      .get();

  // Check if we got any document back
  if (snapshot.docs.isNotEmpty) {
    // Return the ID of the first document found
    return snapshot.docs.first.id;
  }

  // Return null if no document was found
  return null;
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final Telephony telephony = Telephony.instance;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final MethodChannel platform = const MethodChannel("com.tarumt.smsecure/sms");

  bool _permissionsGranted = false;
  bool _isLoading = true;
  Timer? pollTimer;
  String? userPhone;
  String? smsUserID;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _initializeSmsListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Check if contacts and messages were already imported
    final isContactsImported = await secureStorage.read(key: 'isContactsImported') ?? 'false';
    final isMessagesImported = await secureStorage.read(key: 'isMessagesImported') ?? 'false';

    if (isContactsImported == 'true' && isMessagesImported == 'true') {
      setState(() {
        _isLoading = false; // Skip loading if already imported
      });
      return;
    }

    // Run the default SMS handler check and wait for acceptance
    bool isDefaultSet = await _checkAndSetDefaultSmsAppWithLoading();
    if (!isDefaultSet) return; // Stop if not set as default

    // Load userPhone from secure storage
    await _loadUserPhone();

    // Check permissions
    bool permissionsGranted = await _checkAndRequestPermissions();
    if (!permissionsGranted) {
      _showPermissionDialog("SMS and Contacts permissions are required to use this app.");
      return;
    }

    // Start imports and display loading only if both conditions are met
    if (permissionsGranted && isDefaultSet && mounted) {
      setState(() {
        _isLoading = true; // Show loading while importing
      });

      _startMessageListeners();

      if (isContactsImported != 'true') await _importContactsToFirestore();
      if (isMessagesImported != 'true') await _importSmsMessages();

      setState(() {
        _isLoading = false; // Hide loading after import completes
      });
    }
  }



  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permission Required"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("Retry"),
              onPressed: () {
                Navigator.of(context).pop();
                _initialize(); // Retry initialization
              },
            ),
            TextButton(
              child: const Text("Close App"),
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop(); // Close the app
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadUserPhone() async {
    userPhone = await secureStorage.read(key: 'userPhone');
    if (userPhone != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();
      smsUserID = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : null;
    }
    setState(() {});
  }
  
  Future<bool> _checkAndSetDefaultSmsAppWithLoading() async {
    try {
      print("Checking if app is the default SMS handler"); // Debugging line
      final bool? isDefault = await platform.invokeMethod<bool?>('checkDefaultSms');
      if (isDefault != null && !isDefault) {
        print("App is not the default SMS handler, showing dialog"); // Debugging line
        bool userAccepted = await _showDefaultSmsDialog();
        return userAccepted;
      } else {
        print("App is already the default SMS handler"); // Debugging line
        return true;
      }
    } catch (e) {
      print("Platform Exception during default SMS check: $e");
      return false;
    }
  }

  // Modified dialog to return a Future<bool> for user acceptance
  Future<bool> _showDefaultSmsDialog() async {
    bool userAccepted = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Set as Default SMS App'),
        content: const Text(
          'To access and manage SMS messages, this app needs to be set as your default SMS application.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _redirectToDefaultSmsSettings();
              userAccepted = true; // User accepted to change SMS default
            },
            child: const Text('Accept and Go to Settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showPermissionDialog("This app needs to be set as your default SMS handler to continue.");
              userAccepted = false; // User did not accept
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    return userAccepted;
  }

  void _redirectToDefaultSmsSettings() {
    const intent = AndroidIntent(
      action: 'android.settings.MANAGE_DEFAULT_APPS_SETTINGS',
    );
    intent.launch();
  }

  Future<bool> _checkAndRequestPermissions() async {
    try {
      bool smsPermissionGranted = await telephony.requestPhoneAndSmsPermissions ?? false;

      if (smsPermissionGranted) {
        _permissionsGranted = true;
        final isImported = await secureStorage.read(key: 'isMessagesImported') ?? 'false';
        if (isImported != 'true') {
          await _importSmsMessages();
          await secureStorage.write(key: 'isMessagesImported', value: 'true');
        }
        return true;
      } else {
        _permissionsGranted = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS, Phone, or Contacts permissions denied')),
        );
        return false;
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }


  Future<void> _importContactsToFirestore() async {
    // Check if contacts have already been imported
    final isContactsImported = await secureStorage.read(key: 'isContactsImported') ?? 'false';
    if (isContactsImported == 'true') {
      print("Contacts have already been imported to Firestore.");
      return;
    }


    if (_permissionsGranted) {
      print("Importing contacts to Firestore...");
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      setState(() {
        _isLoading = true;
      });
      
      // Fetch contacts and check for any issues in retrieval
      Iterable<Contact> contacts = [];
      try {
        contacts = await FlutterContacts.getContacts(withProperties: true);
      } catch (e) {
        print("Error fetching contacts: $e");
        return;
      }

      if (contacts.isEmpty) {
        print("No contacts found.");
        return;
      }

      // Retrieve userPhone from secure storage
      String? userPhone = await secureStorage.read(key: 'userPhone');
      if (userPhone == null) {
        print("User phone number not found in secure storage.");
        return;
      }

      String? userSmsUserID;
      try {
        final userSnapshot = await firestore
            .collection('smsUser')
            .where('phoneNo', isEqualTo: userPhone)
            .limit(1)
            .get();
        if (userSnapshot.docs.isNotEmpty) {
          userSmsUserID = userSnapshot.docs.first.id;
        }
      } catch (e) {
        print("Error retrieving smsUserID: $e");
        return;
      }

      for (var contact in contacts) {
        final contactID = FirebaseFirestore.instance.collection('contact').doc().id;
        final name = contact.displayName;
        String phoneNo = contact.phones.isNotEmpty ? contact.phones.first.number : 'No Number';
        phoneNo = _formatPhoneNumber(phoneNo);

        String? registeredSmsUserID;
        try {
          final contactSnapshot = await firestore
              .collection('smsUser')
              .where('phoneNo', isEqualTo: phoneNo)
              .limit(1)
              .get();
          if (contactSnapshot.docs.isNotEmpty) {
            registeredSmsUserID = contactSnapshot.docs.first.id;
          }
        } catch (e) {
          print("Error retrieving registeredSmsUserID for $phoneNo: $e");
          continue;
        }

        try {
          await firestore.collection('contact').doc(contactID).set({
            'contactID': contactID,
            'smsUserID': userSmsUserID ?? '',
            'registeredSMSUserID': registeredSmsUserID ?? '',
            'name': name,
            'phoneNo': phoneNo,
            'isBlacklisted': false,
            'isSpam': false,
          }, SetOptions(merge: true));
          print("Contact $name with phone number $phoneNo added to Firestore.");
        } catch (e) {
          print("Error adding contact $name to Firestore: $e");
        }
      }

      // Mark contacts as imported in secure storage
      await secureStorage.write(key: 'isContactsImported', value: 'true');
      setState(() {
        _isLoading = false;
      });
      print("Contacts have been successfully imported and marked in secure storage.");
    } else {
      print("Permissions not granted for importing contacts.");
    }
  }

    // Helper function to format phone numbers
  String _formatPhoneNumber(String phoneNo) {
    phoneNo = phoneNo.trim();
    if (phoneNo.startsWith('0')) {
      return '+6$phoneNo'; // Add +6 if it starts with 0
    } else if (phoneNo.startsWith('6') && !phoneNo.startsWith('+')) {
      return '+$phoneNo'; // Add + if it starts with 6 and no +
    }
    return phoneNo; // Return as is if it already has correct format
  }



  Future<void> _importSmsMessages() async {
    final isMessagesImported = await secureStorage.read(key: 'isMessagesImported') ?? 'false';
    if (isMessagesImported == 'true') return; // Skip if already imported

    try {
      final incomingMessages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(DateTime(2024, 1, 1).millisecondsSinceEpoch.toString()),
      );
      final outgoingMessages = await telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(DateTime(2024, 1, 1).millisecondsSinceEpoch.toString()),
      );

      for (var message in incomingMessages) {
        await _storeSmsInFirestore(message, isIncoming: true);
      }
      for (var message in outgoingMessages) {
        await _storeSmsInFirestore(message, isIncoming: false);
      }
      await secureStorage.write(key: 'isMessagesImported', value: 'true');
      print("Messages successfully imported to Firestore.");
    } catch (e, stackTrace) {
      print('Error importing SMS messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _startMessageListeners() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await handleIncomingSms(message); // Pass to adapter function
      },
      onBackgroundMessage: handleIncomingSms, // Use the same adapter here
    );
    _startPollingSentMessages();
  }


  void _startPollingSentMessages() {
    pollTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _pollSentMessages();
    });
  }

  Future<void> _pollSentMessages() async {
    try {
      final lastPollTime = DateTime(2024, 1, 1);
      final sentMessages = await telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(lastPollTime.millisecondsSinceEpoch.toString()),
      );

      for (var message in sentMessages) {
        await _storeSmsInFirestore(message, isIncoming: false);
      }
    } catch (e, stackTrace) {
      print('Error polling sent messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _storeSmsInFirestore(SmsMessage message, {required bool isIncoming}) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final address = message.address;
      if (address == null || address.isEmpty || userPhone == null) return;

      // Generate a consistent conversationID based on the two phone numbers
      final participants = [userPhone, address];
      participants.sort(); // Alphabetical order ensures consistency
      final conversationID = participants.join('_');

      final messageID = '${message.dateSent}_$address';

      final messageTimestamp = message.dateSent != null 
          ? Timestamp.fromMillisecondsSinceEpoch(message.dateSent!)
          : Timestamp.now();

      final messageSnapshot = await firestore
          .collection('conversations')
          .doc(conversationID)
          .collection('messages')
          .doc(messageID)
          .get();

      if (!messageSnapshot.exists) {
        await firestore.collection('conversations')
            .doc(conversationID)
            .collection('messages')
            .doc(messageID)
            .set({
              'messageID': messageID,
              'senderID': isIncoming ? address : userPhone,
              'receiverID': isIncoming ? userPhone : address,
              'content': message.body ?? "",
              'timestamp': messageTimestamp,
              'isIncoming': isIncoming,
              'isBlacklisted': false,
            });
        
        await firestore.collection('conversations')
            .doc(conversationID)
            .set({
              'lastMessageTimeStamp': messageTimestamp,
              'participants': participants,
              'smsUserID': smsUserID ?? '',
              'isBlacklisted': false,
              'isSpam': false,
            }, SetOptions(merge: true));
      }
    } catch (e, stackTrace) {
      print('Firestore error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home")),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Conversations and contacts are being imported. This may take a moment."),
                ],
              ),
            )
          : const HomePageContent(),
    );
  }
}

class HomePageContent extends StatelessWidget {
  const HomePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Welcome to Home Page"));
  }
}

