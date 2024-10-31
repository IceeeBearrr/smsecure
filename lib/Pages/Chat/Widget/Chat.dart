import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';

class Chat extends StatefulWidget {
  final String conversationID;

  const Chat({super.key, required this.conversationID});

  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  // Scroll to bottom function
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var messages = snapshot.data!.docs;

        // Scroll to bottom whenever new data is loaded
        Future.delayed(Duration.zero, () => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
