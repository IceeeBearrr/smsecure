import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:another_telephony/telephony.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:smsecure/Pages/CustomNavigationBar.dart';
import 'package:smsecure/Pages/Contact/ContactPage.dart';
import 'package:smsecure/Pages/Messages/Messages.dart';
import 'package:smsecure/Pages/Profile/Profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final Telephony telephony = Telephony.instance;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final MethodChannel platform = const MethodChannel("com.tarumt.smsecure/sms");

  bool _permissionsGranted = false;
  Timer? pollTimer;
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const HomePageContent(), // Replace with your actual home page content
    const Contactpage(),
    const Messages(),
    const Profile(),
  ];

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
    await _checkAndRequestPermissions();
    if (_permissionsGranted && mounted) {
      _startMessageListeners();
      await _checkAndSetDefaultSmsApp();
    }
  }

  Future<void> _checkAndSetDefaultSmsApp() async {
    try {
      final bool? isDefault = await platform.invokeMethod<bool?>('checkDefaultSms');
      if (isDefault != null && !isDefault) {
        await platform.invokeMethod('setDefaultSms');
      }
    } catch (e) {
      print("Platform Exception during default SMS check: $e");
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    _permissionsGranted = await telephony.requestPhoneAndSmsPermissions ?? false;
    if (_permissionsGranted) {
      final isImported = await secureStorage.read(key: 'isMessagesImported') ?? 'false';
      if (isImported != 'true') {
        await _importSmsMessages();
        await secureStorage.write(key: 'isMessagesImported', value: 'true');
      }
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
      onBackgroundMessage: _backgroundMessageHandler,
    );
    _startPollingSentMessages();
  }

  static Future<void> _backgroundMessageHandler(SmsMessage message) async {
    await _storeSmsInFirestore(message, isIncoming: true);
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

  void _onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home")),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Customnavigationbar(
        selectedIndex: _selectedIndex,
        onTabChange: _onTabChange,
      ),
    );
  }
}

class HomePageContent extends StatelessWidget {
  const HomePageContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Welcome to Home Page"));
  }
}