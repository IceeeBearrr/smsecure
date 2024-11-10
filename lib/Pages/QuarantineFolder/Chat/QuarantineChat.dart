import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class QuarantineChat extends StatefulWidget {
  final String conversationID;

  const QuarantineChat({super.key, required this.conversationID});

  @override
  _QuarantineChatState createState() => _QuarantineChatState();
}

class _QuarantineChatState extends State<QuarantineChat> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final storage = const FlutterSecureStorage();
  String? userPhone;
  String? senderPhoneNumber;
  String? smsUserID;
  Map<String, String> spamMessagesWithKeywords = {}; // Map to store messageID -> keyword

  @override
  void initState() {
    super.initState();
    initializeData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }


  void _showSpamMessageDetails(Map<String, dynamic> spamDetails) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Spam Message Details",
            textAlign: TextAlign.center, // Justify alignment
            style: TextStyle(fontWeight: FontWeight.bold)
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Keyword: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: spamDetails['keyword']),
                    ],
                  ),
                  textAlign: TextAlign.justify,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Confidence Level: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: spamDetails['confidenceLevel']),
                    ],
                  ),
                  textAlign: TextAlign.justify,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Detected At: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: spamDetails['detectedAt'].toDate().toString()),
                    ],
                  ),
                  textAlign: TextAlign.justify,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Processing Time: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: "${spamDetails['processingTime']}ms"),
                    ],
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Close"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }



  Future<void> initializeData() async {
    userPhone = await storage.read(key: "userPhone");
    if (userPhone == null) return;

    // Determine the sender phone number
    final participants = widget.conversationID.split('_');
    senderPhoneNumber = participants.firstWhere((phone) => phone != userPhone);

    // Fetch smsUserID for the current user
    final smsUserSnapshot = await FirebaseFirestore.instance
        .collection('smsUser')
        .where('phoneNo', isEqualTo: userPhone)
        .limit(1)
        .get();

    if (smsUserSnapshot.docs.isNotEmpty) {
      smsUserID = smsUserSnapshot.docs.first.id;

      // Fetch all spam contacts for the current smsUserID
      final spamContactSnapshot = await FirebaseFirestore.instance
          .collection('spamContact')
          .where('smsUserID', isEqualTo: smsUserID)
          .get();

      Map<String, String> tempSpamMessagesWithKeywords = {};

      for (var spamContactDoc in spamContactSnapshot.docs) {
        // Fetch spam messages for each spamContact
        final spamMessagesSnapshot = await FirebaseFirestore.instance
            .collection('spamContact')
            .doc(spamContactDoc.id)
            .collection('spamMessages')
            .get();

        // Add spam message IDs and keywords to the map
        for (var spamMessageDoc in spamMessagesSnapshot.docs) {
          tempSpamMessagesWithKeywords[spamMessageDoc.id] =
              spamMessageDoc.get('keyword') ?? '';
        }
      }

      setState(() {
        spamMessagesWithKeywords = tempSpamMessagesWithKeywords;
      });
    }
  }

  // Function to highlight multiple keywords
  List<TextSpan> _getHighlightedText(String messageContent, String keywords) {
    List<TextSpan> spans = [];
    List<String> keywordList = keywords.split(',').map((k) => k.trim()).toList();
    int start = 0;

    while (start < messageContent.length) {
      int nextKeywordIndex = messageContent.length;
      String? currentKeyword;

      // Find the next keyword in the message
      for (String keyword in keywordList) {
        int index = messageContent.toLowerCase().indexOf(keyword.toLowerCase(), start);
        if (index != -1 && index < nextKeywordIndex) {
          nextKeywordIndex = index;
          currentKeyword = keyword;
        }
      }

      if (currentKeyword == null || nextKeywordIndex >= messageContent.length) {
        // No more keywords, add the remaining text as a normal span
        spans.add(TextSpan(text: messageContent.substring(start)));
        break;
      }

      // Add the text before the keyword as a normal span
      if (nextKeywordIndex > start) {
        spans.add(TextSpan(text: messageContent.substring(start, nextKeywordIndex)));
      }

      // Add the keyword as a highlighted span
      spans.add(
        TextSpan(
          text: currentKeyword,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.yellow,
          ),
        ),
      );

      // Move the start position after the current keyword
      start = nextKeywordIndex + currentKeyword.length;
    }

    return spans;
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
            bool isSpam = spamMessagesWithKeywords.containsKey(message.id);
            String? keyword = spamMessagesWithKeywords[message.id];

            // Highlight keywords within the message
            List<TextSpan> highlightedText = isSpam && keyword != null && keyword.isNotEmpty
                ? _getHighlightedText(messageContent, keyword)
                : [TextSpan(text: messageContent)];

            return GestureDetector(
              onLongPress: () async {
                if (isSpam) {
                  // Fetch spam message details
                  final spamContactSnapshot = await FirebaseFirestore.instance
                      .collection('spamContact')
                      .where('smsUserID', isEqualTo: smsUserID)
                      .where('phoneNo', isEqualTo: senderPhoneNumber)
                      .limit(1)
                      .get();

                  if (spamContactSnapshot.docs.isNotEmpty) {
                    final spamContactID = spamContactSnapshot.docs.first.id;
                    final spamMessageSnapshot = await FirebaseFirestore.instance
                        .collection('spamContact')
                        .doc(spamContactID)
                        .collection('spamMessages')
                        .doc(message.id)
                        .get();

                    if (spamMessageSnapshot.exists) {
                      _showSpamMessageDetails(spamMessageSnapshot.data()!);
                    }
                  }
                }
              },
              child: Padding(
                padding: senderID == userPhone
                    ? const EdgeInsets.only(left: 80, top: 10)
                    : const EdgeInsets.only(right: 80, top: 10),
                child: Align(
                  alignment: senderID == userPhone ? Alignment.centerRight : Alignment.centerLeft,
                  child: ClipPath(
                    clipper: senderID == userPhone
                        ? LowerNipMessageClipper(MessageType.send)
                        : UpperNipMessageClipper(MessageType.receive),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSpam
                            ? Colors.red
                            : (senderID == userPhone ? const Color(0xFF113953) : const Color(0xFFE1E1E2)),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: isSpam || senderID == userPhone ? Colors.white : Colors.black,
                          ),
                          children: isSpam && keyword != null
                              ? _getHighlightedText(messageContent, keyword)
                              : [TextSpan(text: messageContent)],
                        ),
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}
