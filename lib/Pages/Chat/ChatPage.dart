import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Chat/Widget/Chat.dart';
import 'package:smsecure/Pages/Chat/Widget/ChatBottomSheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:another_telephony/telephony.dart';
import 'package:smsecure/Pages/CustomNavigationBar.dart';

class Chatpage extends StatelessWidget {
  final String conversationID;

  const Chatpage({super.key, required this.conversationID});

  @override
  Widget build(BuildContext context) {
    String currentUserName = "Janice";

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: AppBar(
            leadingWidth: 30,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    "images/HomePage/defaultProfile.png",
                    height: 45,
                    width: 45,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    "Programmer",
                    style: TextStyle(color: Color(0xFF113953)),
                  ),
                ),
              ],
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 25),
                child: Icon(
                  Icons.call,
                  color: Color(0xFF113953),
                  size: 26,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 25),
                child: Icon(
                  Icons.video_call,
                  color: Color(0xFF113953),
                  size: 30,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.more_vert,
                  color: Color(0xFF113953),
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Chat(conversationID: conversationID),
          ),
          Chatbottomsheet(
            onSendMessage: (String messageContent) {
              _sendMessage(messageContent, conversationID, currentUserName);
            },
          ),
        ],
      ),
      bottomNavigationBar: const Customnavigationbar(),
    );
  }

  void _sendMessage(String messageContent, String conversationID, String currentUserName) async {
    final firestore = FirebaseFirestore.instance;

    // Example IDs, these should be dynamically generated or passed
    String senderID = "Janice";
    String receiverID = "Jeffer";
    String receiverPhoneNumber = "+6019-5753479";

    debugPrint("Sending message: $messageContent");

    // Check if conversation exists
    DocumentSnapshot conversationSnapshot =
        await firestore.collection('conversations').doc(conversationID).get();

    if (!conversationSnapshot.exists) {
      // Create a new conversation document
      await firestore.collection('conversations').doc(conversationID).set({
        'conversationID': conversationID,
        'senderID': senderID,
        'receiverID': receiverID,
        'createdAt': DateTime.now(),
        'lastMessageTimeStamp': DateTime.now(),
        'pin': '', // Add other fields as necessary
      });
      debugPrint("Created new conversation with ID $conversationID");
    }

    // Add the message to the sub-collection
    await firestore
        .collection('conversations')
        .doc(conversationID)
        .collection('messages')
        .add({
      'senderID': senderID,
      'receiverID': receiverID,
      'content': messageContent,
      'timestamp': DateTime.now(),
    });
    debugPrint("Message sent: $messageContent");

    // Update the lastMessageTimeStamp in the conversation document
    await firestore.collection('conversations').doc(conversationID).update({
      'lastMessageTimeStamp': DateTime.now(),
    });

    final Telephony telephony = Telephony.instance;

    await telephony.sendSms(
      to: receiverPhoneNumber,
      message: messageContent,
    );
  }
}
