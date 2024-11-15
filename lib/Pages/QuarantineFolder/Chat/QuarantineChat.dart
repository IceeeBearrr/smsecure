import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'package:intl/intl.dart';

// Function to format the detectedAt field
String formatDetectedAt(Timestamp detectedAt) {
  final dateTime = detectedAt.toDate(); // Convert Timestamp to DateTime
  final formatter = DateFormat('dd MMMM yyyy, HH:mm:ss'); // Define the format
  return formatter.format(dateTime); // Format the DateTime
}

String advancedSanitizeText(String text) {
  return text
      .replaceAll('\n', ' ')
      .replaceAll('\r', '')
      .replaceAll('’', "'") // Replace smart quotes with regular quotes
      .replaceAll(
          RegExp(r'\s+'), ' ') // Replace multiple spaces with a single space
      .trim();
}

String extractBaseTimestamp(String messageId) {
  return messageId
      .split('_')[0]; // Extracts the first part before the underscore
}

double sigmoid(double x) {
  return 1 / (1 + exp(-x));
}

String formatConfidenceLevel(String rawConfidence) {
  double rawScore = double.parse(rawConfidence);
  double normalizedScore = sigmoid(rawScore);
  double percentage = normalizedScore * 100;
  return "${percentage.toStringAsFixed(2)}%";
}

class QuarantineChat extends StatefulWidget {
  final String conversationID;

  const QuarantineChat({super.key, required this.conversationID});

  @override
  _QuarantineChatState createState() => _QuarantineChatState();
}

class _QuarantineChatState extends State<QuarantineChat>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final storage = const FlutterSecureStorage();
  String? userPhone;
  String? senderPhoneNumber;
  String? smsUserID;
  bool isLoadingSpamMessages = true;
  Map<String, String> spamMessagesWithKeywords =
      {}; // Map to store messageID -> keyword
  int previousMessageCount = 0;

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

  String normalizeID(String id) {
    return id.split('_').first; // Normalize IDs by taking the first part
  }

  void _showSpamMessageDetails(Map<String, dynamic> spamDetails) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Spam Message Details",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Ensures vertical alignment
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: "Confidence Level: ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: formatConfidenceLevel(
                                  spamDetails['confidenceLevel']),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left:
                              4.0), // Adds small spacing between text and icon
                      child: GestureDetector(
                        onTap:
                            _showConfidenceInfoDialog, // Opens the info dialog
                        child: const Icon(
                          Icons.info_outline,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Detected At: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: formatDetectedAt(spamDetails['detectedAt']),
                      ),
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

  void _showConfidenceInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Confidence Level Explanation",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "The confidence level indicates how certain the model is about its spam prediction.",
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10),
                Text(
                  "Details:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "- A higher value means the message is far from the decision boundary and is more confidently classified as spam.",
                  textAlign: TextAlign.justify,
                ),
                Text(
                  "- A lower value closer to zero indicates the model is less certain and the message is near the decision boundary.",
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 10),
                Text(
                  "Calculation:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "The value is derived from the SVM decision function and converted into a percentage using the sigmoid function.",
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
          .where('isRemoved', isEqualTo: false)
          .get();

      Map<String, String> tempSpamMessagesWithKeywords = {};

      print("Fetching spam messages...");
      for (var spamContactDoc in spamContactSnapshot.docs) {
        // Fetch spam messages for each spamContact
        final spamMessagesSnapshot = await FirebaseFirestore.instance
            .collection('spamContact')
            .doc(spamContactDoc.id)
            .collection('spamMessages')
            .where('isRemoved', isEqualTo: false)
            .get();

        for (var spamMessageDoc in spamMessagesSnapshot.docs) {
          String normalizedId = normalizeID(spamMessageDoc.id);
          print(
              "Spam Message ID: ${spamMessageDoc.id}, Normalized ID: $normalizedId, Keyword: ${spamMessageDoc.get('keyword')}");
          tempSpamMessagesWithKeywords[normalizedId] =
              spamMessageDoc.get('keyword') ?? '';
        }
      }

      setState(() {
        spamMessagesWithKeywords = tempSpamMessagesWithKeywords;
        isLoadingSpamMessages = false;
      });
    }
  }

  // Function to highlight multiple keywords
  List<TextSpan> _getHighlightedText(String messageContent, String keywords) {
    List<TextSpan> spans = [];
    List<String> keywordList =
        keywords.split(',').map((k) => k.trim()).toList();
    int start = 0;

    while (start < messageContent.length) {
      int nextKeywordIndex = messageContent.length;
      String? currentKeyword;

      // Find the next keyword in the message
      for (String keyword in keywordList) {
        int index =
            messageContent.toLowerCase().indexOf(keyword.toLowerCase(), start);
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
        spans.add(
            TextSpan(text: messageContent.substring(start, nextKeywordIndex)));
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
    if (isLoadingSpamMessages) {
      return const Center(child: CircularProgressIndicator());
    }
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

        // Trigger scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (messages.length != previousMessageCount) {
            previousMessageCount = messages.length;
            _scrollToBottom();
          }
        });

        return ListView.builder(
            controller: _scrollController,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              var message = messages[index];
              var messageContent = message['content'];
              var senderID = message['senderID'];
              String normalizedMessageId = normalizeID(message.id);
              bool isSpam =
                  spamMessagesWithKeywords.containsKey(normalizedMessageId);
              String? keyword = spamMessagesWithKeywords[normalizedMessageId];

              // Debugging Logs
              print(
                  "Message ID: ${message.id}, Normalized ID: $normalizedMessageId, isSpam: $isSpam, Keyword: $keyword");

              // Highlight keywords within the message
              List<TextSpan> highlightedText =
                  isSpam && keyword != null && keyword.isNotEmpty
                      ? _getHighlightedText(messageContent, keyword)
                      : [TextSpan(text: messageContent)];

              return GestureDetector(
                onLongPress: () async {
                  if (isSpam) {
                    final baseMessageTimestamp =
                        extractBaseTimestamp(message.id);
                    print(
                        "Base timestamp of pressed message: $baseMessageTimestamp");

                    try {
                      final spamContactSnapshot = await FirebaseFirestore
                          .instance
                          .collection('spamContact')
                          .where('smsUserID', isEqualTo: smsUserID)
                          .where('phoneNo', isEqualTo: senderPhoneNumber)
                          .limit(1)
                          .get();

                      if (spamContactSnapshot.docs.isNotEmpty) {
                        final spamContactID = spamContactSnapshot.docs.first.id;

                        // Fetch all spam messages and compare timestamps
                        final spamMessagesSnapshot = await FirebaseFirestore
                            .instance
                            .collection('spamContact')
                            .doc(spamContactID)
                            .collection('spamMessages')
                            .get();

                        for (var spamDoc in spamMessagesSnapshot.docs) {
                          final spamBaseTimestamp =
                              extractBaseTimestamp(spamDoc.id);

                          if (spamBaseTimestamp == baseMessageTimestamp) {
                            print(
                                "Matched spam message with ID: ${spamDoc.id}");
                            _showSpamMessageDetails(spamDoc.data());
                            return; // Exit once found
                          }
                        }
                        print(
                            "No matching spam message found for base timestamp: $baseMessageTimestamp");
                      } else {
                        print(
                            "No spam contact found for phone number: $senderPhoneNumber");
                      }
                    } catch (e) {
                      print("Error while fetching spam message details: $e");
                    }
                  }
                },
                child: Padding(
                  padding: senderID == userPhone
                      ? const EdgeInsets.only(left: 80, top: 10)
                      : const EdgeInsets.only(right: 80, top: 10),
                  child: Align(
                    alignment: senderID == userPhone
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ClipPath(
                      clipper: senderID == userPhone
                          ? LowerNipMessageClipper(MessageType.send)
                          : UpperNipMessageClipper(MessageType.receive),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSpam
                              ? Colors.red
                              : (senderID == userPhone
                                  ? const Color(0xFF113953)
                                  : const Color(0xFFE1E1E2)),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 16,
                              color: isSpam || senderID == userPhone
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            children: highlightedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            });
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }
}
