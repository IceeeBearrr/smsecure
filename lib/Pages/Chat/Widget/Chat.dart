import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Chat extends StatefulWidget {
  final String conversationID;

  const Chat({super.key, required this.conversationID});

  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final storage = FlutterSecureStorage();
  String? userPhone;

  @override
  void initState() {
    super.initState();
    loadUserPhone();
    WidgetsBinding.instance.addObserver(this); // Add observer for keyboard changes
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // This is called when the view insets change (keyboard shows/hides)
    _scrollToBottom();
  }

  Future<void> loadUserPhone() async {
    // Retrieve the current user's phone number from secure storage
    userPhone = await storage.read(key: "userPhone");
    setState(() {}); // Update the UI after retrieving the phone number
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var message = messages[index];
            var messageContent = message['content'];
            var senderID = message['senderID'];

            // Check if the message was sent by the current user
            bool isSentByUser = senderID == userPhone;

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
