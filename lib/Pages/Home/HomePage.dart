import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Home/Widget/RecentChats.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final Telephony telephony = Telephony.instance;
  DateTime? lastIncomingMessageTimestamp;
  DateTime? lastOutgoingMessageTimestamp;
  final DateTime filterDate = DateTime(2024, 1, 1);
  bool _shouldShowDialog = false;

  static const platform = MethodChannel("com.tarumt.smsecure/sms");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkAndRequestPermissions(); // First check and request permissions
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldShowDialog) {
      _shouldShowDialog = false;
      _showGoToSettingsDialog(); // Show dialog when the app resumes and condition is met
    }
  }

  Future<void> checkAndSetDefaultSmsApp() async {
    try {
      final bool isDefault = await platform.invokeMethod('checkDefaultSms');
      if (!isDefault) {
        await platform.invokeMethod('setDefaultSms');
        _shouldShowDialog = true; // Show dialog after setting default SMS app
      }
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
    }
  }

  Future<void> openAppSettings() async {
    try {
      await platform.invokeMethod('openAppSettings');
    } on PlatformException catch (e) {
      print("Error opening app settings: ${e.message}");
    }
  }

  Future<void> checkAndRequestPermissions() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted ?? false) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isImported = prefs.getBool('isMessagesImported') ?? false;

      if (!isImported) {
        await importSmsMessages();
        await prefs.setBool('isMessagesImported', true);
      }
      startMessageListeners();

      // After importing messages, check if the app is the default SMS handler
      checkAndSetDefaultSmsApp();
    } else {
      _shouldShowDialog = true;
      _showGoToSettingsDialog(); // Show permission dialog immediately if permissions are not granted
    }
  }

  void _showGoToSettingsDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
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
          );
        },
      );
    }
  }

  Future<void> importSmsMessages() async {
    try {
      List<SmsMessage> incomingMessages = await telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE_SENT,
          SmsColumn.DATE
        ],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThan(filterDate.millisecondsSinceEpoch.toString()),
      );

      for (var message in incomingMessages) {
        await storeSmsInFirestore(message, isIncoming: true);
      }

      List<SmsMessage> outgoingMessages = await telephony.getSentSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE_SENT,
          SmsColumn.DATE
        ],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThan(filterDate.millisecondsSinceEpoch.toString()),
      );

      for (var message in outgoingMessages) {
        await storeSmsInFirestore(message, isIncoming: false);
      }
    } catch (e, stackTrace) {
      print('Error importing SMS messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void startMessageListeners() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await storeSmsInFirestore(message, isIncoming: true);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );

    pollSentMessages();
  }

  static Future<void> backgroundMessageHandler(SmsMessage message) async {
    try {
      print('Received SMS in background: ${message.body} from ${message.address}');
      await Firebase.initializeApp();  // Initialize Firebase in background
      await storeSmsInFirestore(message, isIncoming: true);
    } catch (e, stackTrace) {
      print('Error in backgroundMessageHandler: $e');
      print('Stack trace: $stackTrace');
    }
  }


  Future<void> pollSentMessages() async {
    while (true) {
      try {
        DateTime lastPollTime = lastOutgoingMessageTimestamp ?? filterDate;

        List<SmsMessage> sentMessages = await telephony.getSentSms(
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
          await storeSmsInFirestore(message, isIncoming: false);

          int messageTimestamp = message.dateSent ??
              message.date ??
              DateTime.now().millisecondsSinceEpoch;
          DateTime messageTime =
              DateTime.fromMillisecondsSinceEpoch(messageTimestamp);
          if (lastOutgoingMessageTimestamp == null ||
              messageTime.isAfter(lastOutgoingMessageTimestamp!)) {
            lastOutgoingMessageTimestamp = messageTime;
          }
        }

        await Future.delayed(Duration(minutes: 1));
      } catch (e, stackTrace) {
        print('Error polling sent messages: $e');
        print('Stack trace: $stackTrace');
        await Future.delayed(Duration(minutes: 1));
      }
    }
  }

  static Future<void> storeSmsInFirestore(SmsMessage message, {required bool isIncoming}) async {
    print('Attempting to store SMS in Firestore');
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      String? address = message.address;
      if (address == null || address.isEmpty) {
        print("Error: Message address is null or empty");
        return;
      }

      String conversationID = generateConversationID(address);
      String messageID = generateMessageID(message);
      String yourPhoneNumber = "+6011-55050925";
      int messageTimestamp = message.dateSent ??
          message.date ??
          DateTime.now().millisecondsSinceEpoch;
      DateTime messageTime =
          DateTime.fromMillisecondsSinceEpoch(messageTimestamp);

      print('Storing message with ID: $messageID for conversation: $conversationID');

      DocumentSnapshot messageSnapshot = await firestore
          .collection('conversations')
          .doc(conversationID)
          .collection('messages')
          .doc(messageID)
          .get();

      if (messageSnapshot.exists) {
        print("Message already exists in Firestore: $messageID");
        return;
      }

      await firestore
          .collection('conversations')
          .doc(conversationID)
          .collection('messages')
          .doc(messageID)
          .set({
        'messageID': messageID,
        'senderID': isIncoming ? address : yourPhoneNumber,
        'receiverID': isIncoming ? yourPhoneNumber : address,
        'content': message.body ?? "",
        'timestamp': messageTime,
        'isIncoming': isIncoming,
      });

      print('Message stored successfully: $messageID');

      DocumentReference conversationRef =
          firestore.collection('conversations').doc(conversationID);
      DocumentSnapshot conversationSnapshot = await conversationRef.get();

      if (conversationSnapshot.exists) {
        Map<String, dynamic>? conversationData =
            conversationSnapshot.data() as Map<String, dynamic>?;

        if (conversationData != null) {
          DateTime? lastMessageTimeStamp =
              (conversationData['lastMessageTimeStamp'] as Timestamp?)?.toDate();

          if (lastMessageTimeStamp == null ||
              messageTime.isAfter(lastMessageTimeStamp)) {
            await conversationRef.update({
              'lastMessageTimeStamp': messageTime,
            });
          }
        }
      } else {
        await conversationRef.set({
          'conversationID': conversationID,
          'participants': [address, yourPhoneNumber],
          'createdAt': DateTime.now(),
          'pin': null,
          'lastMessageTimeStamp': messageTime,
          'receiverID': isIncoming ? yourPhoneNumber : address,
        });
      }

      print('Conversation updated successfully: $conversationID');
    } catch (e, stackTrace) {
      print('Error storing SMS in Firestore: $e');
      print('Stack trace: $stackTrace');
    }
  }



  static String generateConversationID(String? address) {
    if (address == null || address.isEmpty) return "unknown";
    String cleanAddress = address.replaceAll(RegExp(r'[^\w]+'), '');
    return cleanAddress;
  }

  static String generateMessageID(SmsMessage message) {
    int timestamp = message.dateSent ??
        message.date ??
        DateTime.now().millisecondsSinceEpoch;
    String address = message.address ?? "unknown";
    String body = message.body ?? "";

    List<int> bytes = utf8.encode(body);
    String bodyHash = base64UrlEncode(bytes);

    String messageID = '${timestamp}_$address\_$bodyHash';
    messageID = messageID.replaceAll('/', '_');

    return messageID;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Drawer(),
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Icon(Icons.notifications),
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            child: Text(
              "Messages",
              style: TextStyle(
                color: Color(0xFF113953),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 300,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          hintText: "Search",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.search,
                    color: Color(0xFF113953),
                  ),
                ],
              ),
            ),
          ),
          const Recentchats(),
        ],
      ),
    );
  }
}
