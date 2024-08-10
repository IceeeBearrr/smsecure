import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Home/Widget/RecentChats.dart';
import 'package:telephony/telephony.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Telephony telephony = Telephony.instance;
  DateTime? lastIncomingMessageTimestamp; // Tracks the last incoming message timestamp.
  DateTime? lastOutgoingMessageTimestamp; // Tracks the last outgoing message timestamp.
  final DateTime filterDate = DateTime(2024, 1, 1); // Fetches messages from this date onward.

  @override
  void initState() {
    super.initState();
    checkAndRequestPermissions();
    setAsDefaultSmsApp();
  }

  // Sets the app as the default SMS application.
  void setAsDefaultSmsApp() async {
    const platform = MethodChannel('com.tarumt.smsecure/sms');

    try {
      await platform.invokeMethod('setAsDefaultSmsApp');
    } on PlatformException catch (e) {
      print("Failed to set as default SMS app: '${e.message}'.");
    }
  }

  // Checks and requests necessary permissions.
  Future<void> checkAndRequestPermissions() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted ?? false) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isImported = prefs.getBool('isMessagesImported') ?? false;

      if (!isImported) {
        print("Importing SMS messages for the first time...");
        await importSmsMessages();
        await prefs.setBool('isMessagesImported', true);
        print("SMS messages imported and flag set.");
      } else {
        print("SMS messages have already been imported, skipping import.");
      }

      startMessageListeners(); // Starts listening for new messages.
    } else {
      print("Permissions not granted.");
    }
  }

  // Imports both incoming and outgoing messages.
  Future<void> importSmsMessages() async {
    try {
      // Fetches incoming messages from the specified filter date.
      List<SmsMessage> incomingMessages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(filterDate.millisecondsSinceEpoch.toString()),
      );

      print("Total incoming messages fetched: ${incomingMessages.length}");

      for (var message in incomingMessages) {
        print("Processing incoming message from ${message.address} at ${message.dateSent ?? message.date} with body: ${message.body}");
        await storeSmsInFirestore(message, isIncoming: true);
      }
      print("Imported ${incomingMessages.length} incoming messages.");

      // Fetches outgoing messages from the specified filter date.
      List<SmsMessage> outgoingMessages = await telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(filterDate.millisecondsSinceEpoch.toString()),
      );

      print("Total outgoing messages fetched: ${outgoingMessages.length}");

      for (var message in outgoingMessages) {
        print("Processing outgoing message to ${message.address} at ${message.dateSent ?? message.date} with body: ${message.body}");
        await storeSmsInFirestore(message, isIncoming: false);
      }
      print("Imported ${outgoingMessages.length} outgoing messages.");

    } catch (e, stackTrace) {
      print('Error occurred while importing SMS messages: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Starts listeners for incoming and outgoing messages.
  void startMessageListeners() {
    // Listens for new incoming messages.
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        print("New incoming message from ${message.address} at ${message.dateSent ?? message.date} with body: ${message.body}");
        await storeSmsInFirestore(message, isIncoming: true);
      },
      onBackgroundMessage: backgroundMessageHandler,
    );

    // Starts polling for outgoing messages.
    pollSentMessages();
  }

  // Handles background messages.
  static Future<void> backgroundMessageHandler(SmsMessage message) async {
    print("Background: New incoming message from ${message.address} at ${message.dateSent ?? message.date} with body: ${message.body}");
    // Note: Storing to Firestore in the background might require additional setup.
  }

  // Polls for new outgoing messages periodically.
  Future<void> pollSentMessages() async {
    while (true) {
      try {
        DateTime lastPollTime = lastOutgoingMessageTimestamp ?? filterDate;

        // Fetches outgoing messages since the last polled timestamp.
        List<SmsMessage> sentMessages = await telephony.getSentSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE_SENT, SmsColumn.DATE],
          filter: SmsFilter.where(SmsColumn.DATE).greaterThan(lastPollTime.millisecondsSinceEpoch.toString()),
        );

        print("Polling: Found ${sentMessages.length} new outgoing messages since ${lastPollTime.toIso8601String()}");

        for (var message in sentMessages) {
          print("Processing outgoing message to ${message.address} at ${message.dateSent ?? message.date} with body: ${message.body}");
          await storeSmsInFirestore(message, isIncoming: false);

          // Updates the last outgoing message timestamp.
          int messageTimestamp = message.dateSent ?? message.date ?? DateTime.now().millisecondsSinceEpoch;
          DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(messageTimestamp);
          if (lastOutgoingMessageTimestamp == null || messageTime.isAfter(lastOutgoingMessageTimestamp!)) {
            lastOutgoingMessageTimestamp = messageTime;
          }
        }

        // Waits for 1 minute before polling again.
        await Future.delayed(Duration(minutes: 1));
      } catch (e, stackTrace) {
        print('Error occurred during sent messages polling: $e');
        print('Stack trace: $stackTrace');
        // Waits for 1 minute before retrying in case of an error.
        await Future.delayed(Duration(minutes: 1));
      }
    }
  }

  // Stores an SMS message in Firestore.
  Future<void> storeSmsInFirestore(SmsMessage message, {required bool isIncoming}) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Generate unique IDs for the conversation and message.
    String conversationID = generateConversationID(message.address);
    String messageID = generateMessageID(message);
    String yourPhoneNumber = "+6011-55050925";

    // Get the current message's timestamp.
    int messageTimestamp = message.dateSent ?? message.date ?? DateTime.now().millisecondsSinceEpoch;
    DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(messageTimestamp);

    // Check if the message already exists to prevent duplicates.
    DocumentSnapshot messageSnapshot = await firestore
        .collection('conversations')
        .doc(conversationID)
        .collection('messages')
        .doc(messageID)
        .get();

    if (messageSnapshot.exists) {
      print("Message with ID $messageID already exists in conversation $conversationID. Skipping storage.");
      return;
    }

    // Store the message in the messages sub-collection.
    await firestore
        .collection('conversations')
        .doc(conversationID)
        .collection('messages')
        .doc(messageID)
        .set({
      'messageID': messageID,
      'senderID': isIncoming ? message.address : yourPhoneNumber,
      'receiverID': isIncoming ? yourPhoneNumber : message.address,
      'content': message.body ?? "",
      'timestamp': messageTime,
      'isIncoming': isIncoming,
    });

    print("Stored message with ID $messageID in conversation $conversationID");

    // Update the conversation's lastMessageTimeStamp if this message is more recent.
    DocumentReference conversationRef = firestore.collection('conversations').doc(conversationID);
    DocumentSnapshot conversationSnapshot = await conversationRef.get();

    if (conversationSnapshot.exists) {
      // Safely access fields with null checks and cast data() to a Map
      Map<String, dynamic>? conversationData = conversationSnapshot.data() as Map<String, dynamic>?;
      
      // Access the 'receiverID' safely
      String? existingReceiverID = conversationData?['receiverID'] as String?;

      // Handling the case where 'receiverID' may be missing
      if (existingReceiverID == null) {
        print("Warning: receiverID is missing in conversation $conversationID.");
      }

      DateTime? lastMessageTimeStamp = conversationData?['lastMessageTimeStamp']?.toDate();

      if (lastMessageTimeStamp == null || messageTime.isAfter(lastMessageTimeStamp)) {
        await conversationRef.update({
          'lastMessageTimeStamp': messageTime,
        });
        print("Updated lastMessageTimeStamp for conversation $conversationID to $messageTime");
      }
    } else {
      // If the conversation doesn't exist, create it with the current message's timestamp.
      await conversationRef.set({
        'conversationID': conversationID,
        'participants': [message.address, yourPhoneNumber],
        'createdAt': DateTime.now(),
        'pin': null, // Add pin logic if required.
        'lastMessageTimeStamp': messageTime,
        'receiverID': isIncoming ? yourPhoneNumber : message.address, // Ensure receiverID is set.
      });
      print("Created new conversation with ID $conversationID and set lastMessageTimeStamp to $messageTime");
    }
  }


  // Generates a unique conversation ID based on the address.
  String generateConversationID(String? address) {
    if (address == null || address.isEmpty) return "unknown";
    // Cleans the address by removing spaces and special characters.
    String cleanAddress = address.replaceAll(RegExp(r'[^\w]+'), '');
    return cleanAddress;
  }

  // Generates a unique message ID based on timestamp, address, and message body.
  String generateMessageID(SmsMessage message) {
    // Uses a combination of dateSent/date, address, and body hash.
    int timestamp = message.dateSent ?? message.date ?? DateTime.now().millisecondsSinceEpoch;
    String address = message.address ?? "unknown";
    String body = message.body ?? "";

    // Hashes the message body.
    List<int> bytes = utf8.encode(body);
    String bodyHash = base64UrlEncode(bytes);

    // Combines elements to create a unique message ID.
    String messageID = '${timestamp}_$address\_$bodyHash';

    // Removes any slashes or problematic characters.
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
          const Recentchats(), // Displays recent chats.
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF113953),
        child: const Icon(
          Icons.message,
          color: Colors.white,
        ),
      ),
    );
  }
}
