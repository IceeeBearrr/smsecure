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
import 'package:fl_chart/fl_chart.dart';
import 'package:smsecure/Pages/Home/push_notification_service.dart';

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

Future<void> _initializeSmsListener() async {
  smsChannel.setMethodCallHandler((call) async {
    if (call.method == "onSmsReceived") {
      try {
        // Ensure the arguments are properly formatted
        final Map<String, dynamic> smsData =
            Map<String, dynamic>.from(call.arguments);

        // Extract SMS data
        String senderNumber = smsData["senderNumber"] ?? "Unknown";
        String messageBody = smsData["messageBody"] ?? "No Content";
        final dateSent =
            smsData["dateSent"] ?? DateTime.now().millisecondsSinceEpoch;

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
      print(
          "Error: smsUserID could not be retrieved for userPhone: $userPhone.");
      return;
    }
  } catch (e) {
    print("Error fetching smsUserID: $e");
    return;
  }

  // Step 3: Retrieve chosenPredictionModel from smsUser collection
  String chosenPredictionModel = 'Bidirectional LSTM'; // Fallback value
  try {
    DocumentSnapshot smsUserDoc =
        await firestore.collection('smsUser').doc(smsUserID).get();
    if (smsUserDoc.exists) {
      chosenPredictionModel = smsUserDoc.get('selectedModel') ??
          'Bidirectional LSTM'; // Retrieve field
    } else {
      print(
          "Error: smsUser document does not exist for smsUserID: $smsUserID.");
    }
  } catch (e) {
    print("Error retrieving chosenPredictionModel: $e");
  }

  // Step 3: Format phone numbers
  String senderPhoneNumber = message.senderNumber;
  if (!senderPhoneNumber.startsWith('+')) {
    senderPhoneNumber = '+$senderPhoneNumber';
  }
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
    print(
        "Sender is whitelisted for smsUserID: $smsUserID. Skipping spam detection.");
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
      final conversationSnapshot =
          await firestore.collection('conversations').doc(conversationID).get();

      if (!conversationSnapshot.exists) {
        print(
            "Creating new blacklisted conversation with ID: $conversationID.");
        await firestore.collection('conversations').doc(conversationID).set({
          'participants': participants,
          'smsUserID': smsUserID,
          'lastMessageTimeStamp': Timestamp.now(),
          'participantData': {
            userPhone: {
              'unreadCount': FieldValue.increment(1),
              'lastReadTimestamp': null,
            },
            senderPhoneNumber: {
              'unreadCount': 0,
              'lastReadTimestamp': Timestamp.now(),
            },
          },
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

    // Step 5: Apply custom filter logic
    final words = message.messageBody
        .split(RegExp(r'\s+'))
        .map((word) => word.toLowerCase())
        .toSet();
    bool containsBlock = false;
    bool containsAllow = false;
    final Set<String> blockedKeywords = {};
    final Set<String> allowedKeywords = {};

    try {
      final customFilterSnapshot = await firestore
          .collection('customFilter')
          .where('smsUserID', isEqualTo: smsUserID)
          .get();

      for (var doc in customFilterSnapshot.docs) {
        final filterName = doc.get('filterName').toString().toLowerCase();
        final filterType =
            doc.get('criteria').toString().toLowerCase(); // "Allow" or "Block"

        if (words.contains(filterName)) {
          if (filterType == 'block') {
            containsBlock = true;
            blockedKeywords.add(filterName);
            // Save the blocked keywords as a comma-separated string
          } else if (filterType == 'allow') {
            containsAllow = true;
            allowedKeywords.add(filterName);
          }
        }
      }
    } catch (e) {
      print("Error fetching custom filter criteria: $e");
    }

    if (containsBlock || (containsBlock && containsAllow)) {
      print("Message blocked due to custom filter.");

      // Convert blocked keywords to a comma-separated string
      final keywordString = blockedKeywords.join(", ");
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
              print(
                  "Error updating isSpam field for contact: ${doc.id}, Error: $e");
            }
          }
        }

        senderName ??= "Unknown";

        // Step 4: Check if `spamContact` already exists
        final spamContactQuery = await firestore
            .collection('spamContact')
            .where('smsUserID', isEqualTo: smsUserID)
            .where('phoneNo', isEqualTo: senderPhoneNumber)
            .get();

        String spamContactID;

        if (spamContactQuery.docs.isNotEmpty) {
          // If `spamContact` exists, update `isRemoved` to false
          final existingDoc = spamContactQuery.docs.first;
          spamContactID = existingDoc.id;

          await firestore.collection('spamContact').doc(spamContactID).update({
            'isRemoved': false,
          });

          print("Updated existing spamContact: $spamContactID");
        } else {
          // If no matching `spamContact`, create a new record
          final newDoc = await firestore.collection('spamContact').add({
            'smsUserID': smsUserID,
            'phoneNo': senderPhoneNumber,
            'name': senderName,
            'isRemoved': false,
          });
          spamContactID = newDoc.id;

          print("Created new spamContact: $spamContactID");
        }

        final spamMessageID =
            '${message.dateSent}_${DateTime.now().millisecondsSinceEpoch}_$senderPhoneNumber';
        await firestore
            .collection('spamContact')
            .doc(spamContactID)
            .collection('spamMessages')
            .doc(spamMessageID)
            .set({
          'spamMessageID': spamMessageID,
          'messages': message.messageBody,
          'keyword': keywordString,
          'confidenceLevel': "100",
          'detectedAt': Timestamp.now(),
          'processingTime': 0,
          'isRemoved': false,
          'detectedDue': 'Custom Filter',
        });

        await firestore.collection('conversations').doc(conversationID).set({
          'participants': participants,
          'smsUserID': smsUserID,
          'lastMessageTimeStamp': Timestamp.now(),
          'participantData': {
            userPhone: {
              'unreadCount': FieldValue.increment(1),
              'lastReadTimestamp': null,
            },
            senderPhoneNumber: {
              'unreadCount': 0,
              'lastReadTimestamp': Timestamp.now(),
            },
          },
          'isSpam': true,
          'isBlacklisted': false,
        }, SetOptions(merge: true));

        final messageID =
            '${message.dateSent}_${DateTime.now().millisecondsSinceEpoch}_$senderPhoneNumber';
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

        PushNotificationService.sendNotificationToUser(
          smsUserID: smsUserID,
          senderName: senderName,
          senderPhone: senderPhoneNumber,
          messageContent:
              "Message blocked from $senderPhoneNumber using Custom Filter. It is now in the quarantine folder.",
        );

        return;
      } catch (e) {
        print("Error adding to spamContact collection: $e");
      }
      return;
    } else if (containsAllow) {
      print("Message allowed due to custom filter.");
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
            'participantData': {
              userPhone: {
                'unreadCount': FieldValue.increment(1),
                'lastReadTimestamp': null,
              },
              senderPhoneNumber: {
                'unreadCount': 0,
                'lastReadTimestamp': Timestamp.now(),
              },
            },
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
            print(
                "Error updating isSpam field for contact: ${doc.id}, Error: $e");
          }
        }
      }

      senderName ??= "Unknown";

      PushNotificationService.sendNotificationToUser(
        smsUserID: smsUserID,
        senderName: senderName,
        senderPhone: senderPhoneNumber,
        messageContent:
            "${message.messageBody} (Message is allowed due to Custom Filter)",
      );
      return;
    }

    // Perform spam detection for non-whitelisted and non-blacklisted users
    final predictionRequest = {
      'message': message.messageBody,
      'senderPhone': senderPhoneNumber,
      'chosenPredictionModel': chosenPredictionModel,
    };

    try {
      final response = await http.post(
        Uri.parse('http://192.168.6.243:5000/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(predictionRequest),
      );

      print("Prediction API response status: ${response.statusCode}");
      print("Prediction API response body: ${response.body}");

      if (response.statusCode != 200) {
        print("Error: Non-200 response from Flask API");
        print("Response: ${response.body}");
      }

      if (response.statusCode == 200) {
        final predictionResult = json.decode(response.body);
        if (!predictionResult.containsKey('isSpam')) {
          print("Error: Invalid API response format. Missing 'isSpam' field.");
          return;
        }
        bool isSpam = predictionResult['isSpam'] ?? false;
        String? keyword = predictionResult['keyword'];
        double confidenceLevel =
            (predictionResult['confidenceLevel'] ?? 0.0).toDouble();
        double processingTime =
            (predictionResult['processingTime'] ?? 0.0).toDouble();

        print(
            "Debug: Spam Detection - Is Spam: $isSpam, Keyword: $keyword, Confidence Level: $confidenceLevel");

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
                  print(
                      "Error updating isSpam field for contact: ${doc.id}, Error: $e");
                }
              }
            }

            senderName ??= "Unknown";

            // Step 4: Check if `spamContact` already exists
            final spamContactQuery = await firestore
                .collection('spamContact')
                .where('smsUserID', isEqualTo: smsUserID)
                .where('phoneNo', isEqualTo: senderPhoneNumber)
                .get();

            String spamContactID;

            if (spamContactQuery.docs.isNotEmpty) {
              // If `spamContact` exists, update `isRemoved` to false
              final existingDoc = spamContactQuery.docs.first;
              spamContactID = existingDoc.id;

              await firestore
                  .collection('spamContact')
                  .doc(spamContactID)
                  .update({
                'isRemoved': false,
              });

              print("Updated existing spamContact: $spamContactID");
            } else {
              // If no matching `spamContact`, create a new record
              final newDoc = await firestore.collection('spamContact').add({
                'smsUserID': smsUserID,
                'phoneNo': senderPhoneNumber,
                'name': senderName,
                'isRemoved': false,
              });
              spamContactID = newDoc.id;

              print("Created new spamContact: $spamContactID");
            }

            final spamMessageID =
                '${message.dateSent}_${DateTime.now().millisecondsSinceEpoch}_$senderPhoneNumber';
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
              'isRemoved': false,
              'detectedDue': chosenPredictionModel,
            });

            await firestore
                .collection('conversations')
                .doc(conversationID)
                .set({
              'participants': participants,
              'smsUserID': smsUserID,
              'lastMessageTimeStamp': Timestamp.now(),
              'participantData': {
                userPhone: {
                  'unreadCount': FieldValue.increment(1),
                  'lastReadTimestamp': null,
                },
                senderPhoneNumber: {
                  'unreadCount': 0,
                  'lastReadTimestamp': Timestamp.now(),
                },
              },
              'isSpam': true,
              'isBlacklisted': false,
            }, SetOptions(merge: true));

            final messageID =
                '${message.dateSent}_${DateTime.now().millisecondsSinceEpoch}_$senderPhoneNumber';
            await firestore
                .collection('conversations')
                .doc(conversationID)
                .collection('messages')
                .doc(messageID)
                .set({
              'messageID': messageID,
              'senderID': senderPhoneNumber,
              'content': message.messageBody,
              'timestamp':
                  Timestamp.fromMillisecondsSinceEpoch(message.dateSent),
              'isIncoming': true,
              'isBlacklisted': false,
            }, SetOptions(merge: true));

            PushNotificationService.sendNotificationToUser(
              smsUserID: smsUserID,
              senderName: senderName, // Will use senderPhone instead
              senderPhone: senderPhoneNumber,
              messageContent:
                  "New spam detected from $senderPhoneNumber using $chosenPredictionModel. It is now in the quarantine folder.",
            );

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
          print(
              "Error updating isSpam field for contact: ${doc.id}, Error: $e");
        }
      }
    }

    senderName ??= "Unknown";

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
        'participantData': {
          userPhone: {
            'unreadCount': FieldValue.increment(1),
            'lastReadTimestamp': null,
          },
          senderPhoneNumber: {
            'unreadCount': 0,
            'lastReadTimestamp': Timestamp.now(),
          },
        },
        'isBlacklisted': false,
        'isSpam': false,
      });
    } else {
      await firestore.collection('conversations').doc(conversationID).update({
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

    PushNotificationService.sendNotificationToUser(
      smsUserID: smsUserID,
      senderName: senderName, // Will use senderPhone instead
      senderPhone: senderPhoneNumber,
      messageContent: message.messageBody,
    );
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
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final PushNotificationService _pushNotificationService =
      PushNotificationService();

  bool _permissionsGranted = false;
  bool _isLoading = true;
  Timer? pollTimer;
  String? userPhone;
  String? smsUserID;
  int spamContactCount = 0;
  int totalContactCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _initializeSmsListener();
    _fetchStats();

    final pushNotificationService = PushNotificationService();
    pushNotificationService.getDeviceToken().then((deviceToken) {
      if (deviceToken != null) {
        pushNotificationService.saveDeviceToken(deviceToken);
      } else {
        print("Failed to retrieve device token.");
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Check if contacts and messages were already imported
    final isContactsImported =
        await secureStorage.read(key: 'isContactsImported') ?? 'false';
    final isMessagesImported =
        await secureStorage.read(key: 'isMessagesImported') ?? 'false';

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
      _showPermissionDialog(
          "SMS and Contacts permissions are required to use this app.");
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
      final bool? isDefault =
          await platform.invokeMethod<bool?>('checkDefaultSms');
      if (isDefault != null && !isDefault) {
        print(
            "App is not the default SMS handler, showing dialog"); // Debugging line
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
              _showPermissionDialog(
                  "This app needs to be set as your default SMS handler to continue.");
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
      bool smsPermissionGranted =
          await telephony.requestPhoneAndSmsPermissions ?? false;

      if (smsPermissionGranted) {
        _permissionsGranted = true;
        final isImported =
            await secureStorage.read(key: 'isMessagesImported') ?? 'false';
        if (isImported != 'true') {
          await _importSmsMessages();
          await secureStorage.write(key: 'isMessagesImported', value: 'true');
        }
        return true;
      } else {
        _permissionsGranted = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('SMS, Phone, or Contacts permissions denied')),
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
    final isContactsImported =
        await secureStorage.read(key: 'isContactsImported') ?? 'false';
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
        final contactID =
            FirebaseFirestore.instance.collection('contact').doc().id;
        final name = contact.displayName;
        String phoneNo = contact.phones.isNotEmpty
            ? contact.phones.first.number
            : 'No Number';
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
      print(
          "Contacts have been successfully imported and marked in secure storage.");
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
    final isMessagesImported =
        await secureStorage.read(key: 'isMessagesImported') ?? 'false';
    if (isMessagesImported == 'true') return; // Skip if already imported

    try {
      final incomingMessages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE_SENT,
          SmsColumn.DATE
        ],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(
            DateTime(2024, 1, 1).millisecondsSinceEpoch.toString()),
      );
      final outgoingMessages = await telephony.getSentSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE_SENT,
          SmsColumn.DATE
        ],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(
            DateTime(2024, 1, 1).millisecondsSinceEpoch.toString()),
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
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE_SENT,
          SmsColumn.DATE
        ],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThan(lastPollTime.millisecondsSinceEpoch.toString()),
      );

      for (var message in sentMessages) {
        await _storeSmsInFirestore(message, isIncoming: false);
      }
    } catch (e, stackTrace) {
      print('Error polling sent messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _storeSmsInFirestore(SmsMessage message,
      {required bool isIncoming}) async {
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
        await firestore
            .collection('conversations')
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

        await firestore.collection('conversations').doc(conversationID).set({
          'lastMessageTimeStamp': messageTimestamp,
          'participants': participants,
          'participantData': {
            userPhone: {
              'lastReadTimestamp': isIncoming ? Timestamp.now() : null,
              'unreadCount': isIncoming ? FieldValue.increment(1) : 0,
            },
            address: {
              'lastReadTimestamp': !isIncoming ? Timestamp.now() : null,
              'unreadCount': !isIncoming ? FieldValue.increment(1) : 0,
            },
          },
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

  Future<void> _fetchStats() async {
    try {
      // Step 1: Retrieve userPhone
      String? userPhone = await secureStorage.read(key: "userPhone");
      if (userPhone == null) throw Exception("User phone not found");

      // Step 2: Retrieve smsUserID
      QuerySnapshot smsUserSnapshot = await firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (smsUserSnapshot.docs.isEmpty) throw Exception("smsUserID not found");
      smsUserID = smsUserSnapshot.docs.first.id;

      // Step 3: Fetch spamContact count
      QuerySnapshot spamContactSnapshot = await firestore
          .collection('spamContact')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('isRemoved', isEqualTo: false) // Only active spam contacts
          .get();
      spamContactCount = spamContactSnapshot.docs.length;

      // Step 4: Fetch totalContact count
      QuerySnapshot contactSnapshot = await firestore
          .collection('contact')
          .where('smsUserID', isEqualTo: smsUserID)
          .get();
      totalContactCount = contactSnapshot.docs.length;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching stats: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false, // Align the title to the start
        title: const Text(
          "Home",
          style: TextStyle(
            color: Color(0xFF113953), // Match the theme color
            fontSize: 28, // Ensure the font size matches
            fontWeight: FontWeight.bold, // Bold for emphasis
          ),
        ),
        elevation: 0, // Flat design without shadow
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text(
                    "Conversations and contacts are being imported. This may take a moment.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : FutureBuilder<Map<String, dynamic>>(
              future: _fetchDashboardStats(), // Fetch dynamic stats
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "Error loading data. Please try again later.",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final data = snapshot.data ?? {};
                final conversationCount = data['conversationCount'] ?? 0;
                final spamCount = data['spamCount'] ?? 0;
                final falsePositiveCount = data['falsePositiveCount'] ?? 0;
                final falsePositiveRate = data['falsePositiveRate'] ?? 0.0;
                final detectedDueCounts = data['detectedDueCounts'] ?? {};

                return FutureBuilder<String?>(
                  future: _fetchUserName(), // Fetch user's name dynamically
                  builder: (context, nameSnapshot) {
                    String userName =
                        nameSnapshot.data ?? "User"; // Default to "User"
                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: Text(
                              "Welcome Back!",
                              style: TextStyle(
                                color: Color(0xFF113953),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 30),
                            child: Text(
                              "Hi, $userName", // Use dynamic name
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _buildDashboardWidgets(
                              spamCount,
                              conversationCount,
                              falsePositiveCount,
                              falsePositiveRate,
                              detectedDueCounts), // Updated
                          const SizedBox(height: 20),
                          _buildSpamTrendsWidget(), // Placeholder for trends
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildDashboardWidgets(
      int spamCount,
      int conversationCount,
      int falsePositiveCount,
      double falsePositiveRate,
      Map<String, int> detectedDueCounts) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildSpamDetectedWidget(
              spamCount, conversationCount, detectedDueCounts),
        ),
        const SizedBox(width: 10), // Add some spacing between widgets
        Expanded(
          child: _buildFalsePositiveWidget(
              falsePositiveCount, spamCount, falsePositiveRate),
        ),
      ],
    );
  }

  Future<String?> _fetchUserName() async {
    try {
      // Retrieve userPhone from secure storage
      final String? userPhone = await secureStorage.read(key: "userPhone");
      if (userPhone == null) return null;

      // Fetch the user's name from the smsUser collection
      final QuerySnapshot smsUserSnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (smsUserSnapshot.docs.isNotEmpty) {
        return smsUserSnapshot.docs.first.get('name') ?? "User";
      }
      return null; // Return null if no user found
    } catch (e) {
      debugPrint("Error fetching user name: $e");
      return null;
    }
  }

  Widget _buildSpamDetectedWidget(int spamCount, int conversationCount,
      Map<String, int> detectedDueCounts) {
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Chats Blocked"),
              content: SingleChildScrollView(
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    textAlign: TextAlign.justify, // Add this line
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              "Chats Blocked represents the total conversations filtered out. "
                              "Breakdown of each detection method shows below:\n\n",
                        ),
                        const TextSpan(
                          text: "- Bidirectional LSTM: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              "${detectedDueCounts['Bidirectional LSTM'] ?? 0}\n",
                        ),
                        const TextSpan(
                          text: "- Multinomial NB: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: "${detectedDueCounts['Multinomial NB'] ?? 0}\n",
                        ),
                        const TextSpan(
                          text: "- Linear SVM: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: "${detectedDueCounts['Linear SVM'] ?? 0}\n",
                        ),
                        const TextSpan(
                          text: "- Custom Filter: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: "${detectedDueCounts['Custom Filter'] ?? 0}\n",
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
      child: SizedBox(
        height: 127,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                "Chats Blocked",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: conversationCount > 0
                        ? spamCount / conversationCount
                        : 0.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF113953),
                    ),
                  ),
                  Text(
                    "$spamCount/${conversationCount > 0 ? conversationCount : 1}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpamTrendsWidget() {
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Spam Trends"),
              content: const Text(
                "The top words displayed here are extracted based on the prediction models "
                "Multinomial Naive Bayes (NB) and Linear SVM. These models analyze word frequencies "
                "to determine the likelihood of a message being spam.\n\n"
                "Note: Bidirectional LSTM is not included because it predicts spam based on the sequential "
                "structure of the entire sentence, rather than individual word contributions.",
                textAlign: TextAlign.justify,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchKeywordCounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show the bar chart
          return Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            height: 300,
            child: SpamKeywordBarChart(data: snapshot.data!),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchDashboardStats() async {
    try {
      final String? userPhone = await secureStorage.read(key: "userPhone");
      if (userPhone == null) throw Exception("User phone not found");

      final smsUserSnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (smsUserSnapshot.docs.isEmpty) throw Exception("smsUserID not found");

      final smsUserID = smsUserSnapshot.docs.first.id;

      // Fetch the count of conversations for the smsUserID
      final conversationSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .where('smsUserID', isEqualTo: smsUserID)
          .get();

      // Fetch the total number of spam contacts for the smsUserID
      final spamSnapshot = await FirebaseFirestore.instance
          .collection('spamContact')
          .where('smsUserID', isEqualTo: smsUserID)
          .get();

      // Fetch the count of spam contacts where `isRemoved` is `true`
      final falsePositiveSnapshot = await FirebaseFirestore.instance
          .collection('spamContact')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('isRemoved', isEqualTo: true)
          .get();

      // Count occurrences of detectedDue in spamMessages sub-collections
      final Map<String, int> detectedDueCounts = {
        "Bidirectional LSTM": 0,
        "Custom Filter": 0,
        "Multinomial NB": 0,
        "Linear SVM": 0,
      };

      for (var spamContactDoc in spamSnapshot.docs) {
        final spamMessagesSnapshot = await FirebaseFirestore.instance
            .collection('spamContact')
            .doc(spamContactDoc.id)
            .collection('spamMessages')
            .orderBy('detectedAt', descending: true)
            .limit(1)
            .get();

        if (spamMessagesSnapshot.docs.isNotEmpty) {
          final detectedDue =
              spamMessagesSnapshot.docs.first.get('detectedDue');
          if (detectedDueCounts.containsKey(detectedDue)) {
            detectedDueCounts[detectedDue] =
                detectedDueCounts[detectedDue]! + 1;
          }
        }
      }

      final spamCount = spamSnapshot.docs.length;
      final falsePositiveCount = falsePositiveSnapshot.docs.length;

      // Calculate False Positive Rate
      final falsePositiveRate =
          spamCount > 0 ? falsePositiveCount / spamCount : 0.0;

      return {
        'conversationCount': conversationSnapshot.docs.length,
        'spamCount': spamCount,
        'falsePositiveCount': falsePositiveCount,
        'falsePositiveRate': falsePositiveRate,
        'detectedDueCounts': detectedDueCounts,
      };
    } catch (e) {
      print("Error fetching dashboard stats: $e");
      return {};
    }
  }

  Widget _buildFalsePositiveWidget(
      int falsePositiveCount, int spamCount, double falsePositiveRate) {
    return GestureDetector(
      onLongPress: () async {
        // Fetch breakdown of false positives for each model
        final modelBreakdown = await _fetchFalsePositiveBreakdown();

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("False Positives"),
              content: SingleChildScrollView(
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    textAlign: TextAlign.justify, // Add this line
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              "False Positives represent spam messages removed by the user from the quarantine folder."
                              "Breakdown of each detection method shows below:\n\n",
                        ),
                        const TextSpan(
                          text: "- Bidirectional LSTM: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              "${modelBreakdown['Bidirectional LSTM']?.toStringAsFixed(2) ?? '0.00'}%\n",
                        ),
                        const TextSpan(
                          text: "- Multinomial NB: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              "${modelBreakdown['Multinomial NB']?.toStringAsFixed(2) ?? '0.00'}%\n",
                        ),
                        const TextSpan(
                          text: "- Linear SVM: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              "${modelBreakdown['Linear SVM']?.toStringAsFixed(2) ?? '0.00'}%\n",
                        ),
                        const TextSpan(
                          text: "- Custom Filter: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              "${modelBreakdown['Custom Filter']?.toStringAsFixed(2) ?? '0.00'}%\n",
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "False Positives",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$falsePositiveCount/$spamCount",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${(falsePositiveRate * 100).toStringAsFixed(2)}%",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF113953),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: falsePositiveRate,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF113953),
              ),
              minHeight: 10,
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, double>> _fetchFalsePositiveBreakdown() async {
    try {
      // Fetch spamContact documents where isRemoved is true
      final falsePositiveSnapshot = await FirebaseFirestore.instance
          .collection('spamContact')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('isRemoved', isEqualTo: true)
          .get();

      // Initialize model counts for detectedDue
      final Map<String, int> modelCounts = {
        "Bidirectional LSTM": 0,
        "Multinomial NB": 0,
        "Linear SVM": 0,
        "Custom Filter": 0,
      };

      // Iterate through each spamContact document
      for (var doc in falsePositiveSnapshot.docs) {
        // Query the latest spamMessage based on detectedAt timestamp
        final spamMessagesSnapshot = await FirebaseFirestore.instance
            .collection('spamContact')
            .doc(doc.id)
            .collection('spamMessages')
            .orderBy('detectedAt', descending: true)
            .limit(1)
            .get();

        // If a spamMessage exists, process its detectedDue field
        if (spamMessagesSnapshot.docs.isNotEmpty) {
          final detectedDue =
              spamMessagesSnapshot.docs.first.get('detectedDue');
          if (modelCounts.containsKey(detectedDue)) {
            modelCounts[detectedDue] = modelCounts[detectedDue]! + 1;
          }
        }
      }

      // Calculate total false positives
      final int totalFalsePositives =
          modelCounts.values.reduce((a, b) => a + b);

      // Compute percentages for each model
      final Map<String, double> percentages = {};
      modelCounts.forEach((model, count) {
        percentages[model] =
            totalFalsePositives > 0 ? (count / totalFalsePositives) * 100 : 0.0;
      });

      return percentages;
    } catch (e) {
      print("Error fetching false positive breakdown: $e");
      return {
        "Bidirectional LSTM": 0.0,
        "Multinomial NB": 0.0,
        "Linear SVM": 0.0,
        "Custom Filter": 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _fetchKeywordCounts() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('spamMessages')
          .where('detectedDue',
              whereIn: ['Multinomial NB', 'Linear SVM']).get();

      print(
          "Fetched ${querySnapshot.docs.length} spamMessages documents"); // Debugging log

      // Count individual keywords
      final Map<String, int> keywordCounts = {};
      for (var doc in querySnapshot.docs) {
        print("Processing document: ${doc.id}"); // Debugging log
        final dynamic keywordField = doc.get('keyword');

        // Handle both String and List<dynamic> types
        List<String> keywords;
        if (keywordField is String) {
          keywords = keywordField
              .split(',')
              .map((keyword) => keyword.trim()) // Trim extra spaces
              .toList();
        } else if (keywordField is List<dynamic>) {
          keywords = keywordField.map((e) => e.toString().trim()).toList();
        } else {
          print(
              "Skipping invalid keyword field in document: ${doc.id}"); // Debugging log
          continue;
        }

        for (var keyword in keywords) {
          if (keyword.isNotEmpty) {
            keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
          }
        }
      }

      print("Keyword counts: $keywordCounts"); // Debugging log

      // Convert the map to a sorted list of maps
      final List<Map<String, dynamic>> sortedKeywords = keywordCounts.entries
          .map((entry) => {'keyword': entry.key, 'count': entry.value})
          .toList();

      sortedKeywords
          .sort((a, b) => b['count'].compareTo(a['count'])); // Sort descending

      return sortedKeywords.take(5).toList();
    } catch (e) {
      print('Error fetching keyword counts: $e');
      return [];
    }
  }
}

class HomePageContent extends StatelessWidget {
  const HomePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Welcome to Home Page"));
  }
}

class SpamKeywordBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const SpamKeywordBarChart({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    // If no data is available, create a placeholder list with empty entries
    final List<Map<String, dynamic>> chartData = data.isNotEmpty
        ? data
        : List.generate(
            5,
            (index) => {'keyword': 'Keyword $index', 'count': 0},
          );

    final int maxOccurrences = data.isNotEmpty
        ? data.map((e) => e['count']).reduce((a, b) => a > b ? a : b)
        : 1; // Get the max count or default to 1
    final int interval = (maxOccurrences / 5).ceil(); // Dynamic interval

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxOccurrences + interval).toDouble(), // Set max Y dynamically
        barGroups: data.map((keywordData) {
          final index = data.indexOf(keywordData);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: keywordData['count'].toDouble(),
                color: data.isNotEmpty
                    ? const Color(0xFF113953)
                    : Colors.grey.shade300,
                width: 16,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: false, // Hide left titles
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() < data.length) {
                  return Text(
                    data[value.toInt()]['keyword'],
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // Show right titles
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value % interval == 0) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
