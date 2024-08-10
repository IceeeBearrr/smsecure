import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';

class Chat extends StatelessWidget {
  final String conversationID;

  const Chat({super.key, required this.conversationID});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationID)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(), // Changed to ascending order
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var messages = snapshot.data!.docs;

        return ListView.builder(
          reverse: false, // Changed to show the latest messages at the bottom
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var message = messages[index];
            var messageContent = message['content'];
            var senderID = message['senderID'];

            bool isSentByUser = senderID == "Janice"; // Replace with actual user ID check

            return Padding(
              padding: isSentByUser
                  ? const EdgeInsets.only(left: 80, top: 10)
                  : const EdgeInsets.only(right: 80, top: 10),
              child: Align(
                alignment:
                    isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
                child: ClipPath(
                  clipper: isSentByUser
                      ? LowerNipMessageClipper(MessageType.send)
                      : UpperNipMessageClipper(MessageType.receive),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSentByUser
                          ? const Color(0xFF113953)
                          : const Color(0xFFE1E1E2),
                    ),
                    child: Text(
                      messageContent,
                      style: TextStyle(
                        fontSize: 16,
                        color: isSentByUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
