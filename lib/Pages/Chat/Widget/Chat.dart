import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Chat extends StatefulWidget {
  final String conversationID;
  final DateTime? initialTimestamp;

  const Chat({super.key, required this.conversationID, this.initialTimestamp});

  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final storage = const FlutterSecureStorage();
  String? userPhone;
  bool isJumpingToMessage = false;

  @override
  void initState() {
    super.initState();
    loadUserPhone();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadUserPhone() async {
    userPhone = await storage.read(key: "userPhone");
    setState(() {});
  }

  /// Scroll to the last message
  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Jump to a specific message based on the provided timestamp
  Future<void> jumpToMessage(DateTime timestamp) async {
    QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationID)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    List<QueryDocumentSnapshot> messages = messagesSnapshot.docs;
    int targetIndex = messages.indexWhere((msg) {
      var data = msg.data() as Map<String, dynamic>;
      return (data['timestamp'] as Timestamp).toDate().isAtSameMomentAs(timestamp);
    });

    if (targetIndex != -1) {
      isJumpingToMessage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          targetIndex * 70.0, // Estimate message height
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        isJumpingToMessage = false;
      });
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

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.initialTimestamp != null && !isJumpingToMessage) {
            jumpToMessage(widget.initialTimestamp!);
          } else if (!isJumpingToMessage) {
            scrollToBottom();
          }
        });

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var message = messages[index];
            var data = message.data() as Map<String, dynamic>;
            var messageContent = data['content'] ?? '';
            var senderID = data['senderID'] ?? '';
            var timestamp = data['timestamp'] as Timestamp;

            bool isSentByUser = senderID == userPhone;

            bool isHighlighted = widget.initialTimestamp != null &&
                timestamp.toDate().isAtSameMomentAs(widget.initialTimestamp!);

            return Padding(
              padding: isSentByUser
                  ? const EdgeInsets.only(left: 80, top: 10)
                  : const EdgeInsets.only(right: 80, top: 10),
              child: Align(
                alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
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
                      border: isHighlighted
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
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
