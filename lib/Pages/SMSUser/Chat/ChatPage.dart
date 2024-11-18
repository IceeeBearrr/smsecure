import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Chat/Widget/Chat.dart';
import 'package:smsecure/Pages/Chat/Widget/ChatBottomSheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/SMSUser/Chat/ChatSettings.dart';

class Chatpage extends StatefulWidget {
  final String conversationID;
  final String? initialMessageID;

  const Chatpage({
    super.key,
    required this.conversationID,
    this.initialMessageID,
  });

  @override
  _ChatpageState createState() => _ChatpageState();
}

class _ChatpageState extends State<Chatpage> {
  final storage = const FlutterSecureStorage();
  String? participantName;
  String? profileImageBase64;
  bool isLoading = true;
  String? userPhone; // Stores the current user's phone number
  String currentUserName = "Unknown";

  @override
  void initState() {
    super.initState();
    initializeUserDetails();
  }

  Future<void> loadParticipantDetails() async {
    // Retrieve current user's phone number from secure storage
    userPhone = await storage.read(key: "userPhone");
    if (userPhone == null) return;

    // Fetch conversation details
    DocumentSnapshot conversationSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationID)
        .get();

    if (!conversationSnapshot.exists) return;

    // Get participant's phone number from the conversation
    var participants = List<String>.from(conversationSnapshot['participants']);
    String otherUserPhone = participants
        .firstWhere((phone) => phone != userPhone, orElse: () => 'Unknown');

    // Fetch participant's details from Firestore
    final contactSnapshot = await FirebaseFirestore.instance
        .collection('contact')
        .where('phoneNo', isEqualTo: otherUserPhone)
        .get();

    if (contactSnapshot.docs.isNotEmpty) {
      var contactData = contactSnapshot.docs.first.data();
      String? name = contactData['name'];
      String? profileImageUrl = contactData['profileImageUrl'];
      String? registeredSmsUserID = contactData['registeredSmsUserID'];

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        setState(() {
          participantName = name;
          profileImageBase64 = profileImageUrl;
          isLoading = false;
        });
      } else if (registeredSmsUserID != null &&
          registeredSmsUserID.isNotEmpty) {
        final registeredSmsUserSnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(registeredSmsUserID)
            .get();

        if (registeredSmsUserSnapshot.exists &&
            registeredSmsUserSnapshot.data()!['profileImageUrl'] != null) {
          setState(() {
            participantName = name;
            profileImageBase64 =
                registeredSmsUserSnapshot.data()!['profileImageUrl'];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          participantName = name;
          profileImageBase64 = null;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        participantName =
            otherUserPhone; // Default to phone number if name is unavailable
        profileImageBase64 = null;
        isLoading = false;
      });
    }
  }

  Future<void> initializeUserDetails() async {
    // Retrieve current user's phone number from secure storage
    userPhone = await storage.read(key: "userPhone");
    if (userPhone == null) return;

    // Fetch the current user's name from the 'smsUser' collection
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('smsUser')
        .doc(userPhone)
        .get();

    if (userSnapshot.exists) {
      setState(() {
        currentUserName =
            (userSnapshot.data() as Map<String, dynamic>)['name'] ?? "Unknown";
      });
    }
    // Reset unread count for the current user
    await resetUnreadCount();
    // Load participant details
    await loadParticipantDetails();
  }

  Future<void> resetUnreadCount() async {
    userPhone = await storage.read(key: "userPhone");

    if (userPhone == null || widget.conversationID.isEmpty) {
      debugPrint("User phone number or conversation ID is missing.");
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .update({
        'participantData.$userPhone.unreadCount': 0,
      });
      debugPrint("Unread count for $userPhone reset to 0.");
    } catch (e) {
      debugPrint("Error resetting unread count: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: AppBar(
            leadingWidth: 30,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF113953)),
              onPressed: () {
                // Navigate back to the first route
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : profileImageBase64 != null
                          ? Image.memory(
                              base64Decode(profileImageBase64!),
                              height: 45,
                              width: 45,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              "images/HomePage/defaultProfile.png",
                              height: 45,
                              width: 45,
                            ),
                ),
                const SizedBox(width: 10),
                Text(
                  isLoading ? "Loading..." : participantName ?? "Unknown",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF113953),
                  ),
                ),
              ],
            ),
            actions: [
              const Padding(
                padding: EdgeInsets.only(right: 25),
                child: Icon(
                  Icons.call,
                  color: Color(0xFF113953),
                  size: 26,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Color(0xFF113953),
                    size: 30,
                  ),
                  onPressed: () {
                    // Navigate to ChatSettings
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatSettingsPage(
                            conversationID: widget.conversationID),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Chat(
                    conversationID: widget.conversationID,
                    initialMessageID: widget.initialMessageID,
                  ),
                ),
                const SizedBox(
                    height:
                        30.0), // Adds space at the bottom of the Chat widget
              ],
            ),
          ),
          Chatbottomsheet(
            onSendMessage: (String messageContent) {
              _sendMessage(
                  messageContent, widget.conversationID, currentUserName);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String messageContent, String conversationID,
      String currentUserName) async {
    final firestore = FirebaseFirestore.instance;

    // Retrieve current user's phone number from secure storage if not already loaded
    userPhone ??= await storage.read(key: "userPhone");

    if (userPhone == null) {
      debugPrint("User phone number not found in secure storage.");
      return;
    }

    // Fetch conversation details to determine senderID and receiverPhoneNumber
    DocumentSnapshot conversationSnapshot =
        await firestore.collection('conversations').doc(conversationID).get();

    if (!conversationSnapshot.exists) {
      debugPrint("Conversation does not exist.");
      return;
    }

    var participants = List<String>.from(conversationSnapshot['participants']);
    String senderID = participants.firstWhere((phone) => phone == userPhone,
        orElse: () => "Unknown");
    String receiverPhoneNumber = participants
        .firstWhere((phone) => phone != userPhone, orElse: () => "Unknown");

    debugPrint(
        "Sending message from $senderID to $receiverPhoneNumber: $messageContent");
    final messageID =
        '${DateTime.now().millisecondsSinceEpoch}_$receiverPhoneNumber';
    final timestamp = Timestamp.now();

    // Add the message to the sub-collection
    await firestore
        .collection('conversations')
        .doc(conversationID)
        .collection('messages')
        .doc(messageID)
        .set({
      'content': messageContent,
      'isBlacklisted': false,
      'isIncoming': false, // Outgoing message
      'messageID': messageID,
      'receiverID': receiverPhoneNumber,
      'senderID': senderID,
      'timestamp': timestamp,
    });

    // Update the conversation's lastMessageTimeStamp and increment unreadCount for the receiver
    await firestore.collection('conversations').doc(conversationID).update({
      'lastMessageTimeStamp': timestamp,
      'participantData.$receiverPhoneNumber.unreadCount':
          FieldValue.increment(1), // Increment unread count for the receiver
    });

    // Send the SMS to the receiver's phone number
    final Telephony telephony = Telephony.instance;
    await telephony.sendSms(
      to: receiverPhoneNumber,
      message: messageContent,
    );
  }
}
