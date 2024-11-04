import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:another_telephony/telephony.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

Future<void> backgroundMessageHandler(SmsMessage message) async {
  final firestore = FirebaseFirestore.instance;
  final address = message.address;
  if (address == null || address.isEmpty) return;

  final conversationID = address.replaceAll(RegExp(r'[^\w]+'), '');
  final messageID = '${message.dateSent}_$address';
  final messageTimestamp = message.dateSent != null
      ? Timestamp.fromMillisecondsSinceEpoch(message.dateSent!)
      : Timestamp.now();

  await firestore.collection('conversations')
      .doc(conversationID)
      .collection('messages')
      .doc(messageID)
      .set({
        'messageID': messageID,
        'senderID': address,
        'content': message.body ?? "",
        'timestamp': messageTimestamp,
        'isIncoming': true,
      }, SetOptions(merge: true));
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
  Timer? pollTimer;
  String? userPhone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Run the default SMS handler check first
    await _checkAndSetDefaultSmsApp();

    // Load userPhone from secure storage
    await _loadUserPhone(); 

    // Check permissions and start listening to messages if permissions are granted
    await _checkAndRequestPermissions();
    if (_permissionsGranted && mounted) {
      _startMessageListeners();
      _importContactsToFirestore(); // Run without await to prevent blocking
    }
  }


  Future<void> _loadUserPhone() async {
    userPhone = await secureStorage.read(key: 'userPhone');
    setState(() {}); // Trigger a rebuild to use the updated userPhone
  }

  Future<void> _checkAndSetDefaultSmsApp() async {
    try {
      print("Checking if app is the default SMS handler"); // Debugging line
      final bool? isDefault = await platform.invokeMethod<bool?>('checkDefaultSms');
      if (isDefault != null && !isDefault) {
        print("App is not the default SMS handler, showing dialog"); // Debugging line
        _showDefaultSmsDialog();
      } else {
        print("App is already the default SMS handler"); // Debugging line
      }
    } catch (e) {
      print("Platform Exception during default SMS check: $e");
    }
  }


  

  void _showDefaultSmsDialog() {
    showDialog(
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
            },
            child: const Text('Go to Settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _redirectToDefaultSmsSettings() {
    const intent = AndroidIntent(
      action: 'android.settings.MANAGE_DEFAULT_APPS_SETTINGS',
    );
    intent.launch();
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      bool smsPermissionGranted = await telephony.requestPhoneAndSmsPermissions ?? false;

      if (smsPermissionGranted) {
        _permissionsGranted = true;
        final isImported = await secureStorage.read(key: 'isMessagesImported') ?? 'false';
        if (isImported != 'true') {
          await _importSmsMessages();
          await secureStorage.write(key: 'isMessagesImported', value: 'true');
        }
      } else {
        _permissionsGranted = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS, Phone, or Contacts permissions denied')),
        );
      }
    } catch (e) {
      print('Error requesting permissions: $e');
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
        final contactID = contact.id;
        final name = contact.displayName;
        final phoneNo = contact.phones.isNotEmpty ? contact.phones.first.number : 'No Number';

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
      print("Contacts have been successfully imported and marked in secure storage.");
    } else {
      print("Permissions not granted for importing contacts.");
    }
  }



  Future<void> _importSmsMessages() async {
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
    } catch (e, stackTrace) {
      print('Error importing SMS messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _startMessageListeners() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await _storeSmsInFirestore(message, isIncoming: true);
      },
      onBackgroundMessage: backgroundMessageHandler, 
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

      final conversationID = _generateConversationID(address);
      final messageID = _generateMessageID(message);
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
            });
        
        await firestore.collection('conversations')
            .doc(conversationID)
            .set({
              'lastMessageTimeStamp': messageTimestamp,
              'participants': [address, userPhone]
            }, SetOptions(merge: true));
      }
    } catch (e, stackTrace) {
      print('Firestore error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static String _generateConversationID(String? address) {
    return address?.replaceAll(RegExp(r'[^\w]+'), '') ?? "unknown";
  }

  static String _generateMessageID(SmsMessage message) {
    final timestamp = message.dateSent ?? message.date ?? DateTime.now().millisecondsSinceEpoch;
    final address = message.address ?? "unknown";
    final body = message.body ?? "";
    final bodyHash = base64UrlEncode(utf8.encode(body));
    return '${timestamp}_${address}_$bodyHash'.replaceAll('/', '_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home")),
      body: const HomePageContent(),
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

