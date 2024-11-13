import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:smsecure/Pages/Chat/Widget/GoogleTranslation.dart';
import 'dart:async';

final translationService = GoogleTranslationService();

Future<void> setupTranslationService() async {
  try {
    await translationService
        .initialize('assets/credentials/smsecure-c5f3c87a3965.json');
    print("Translation service initialized successfully.");
  } catch (e) {
    print("Error initializing translation service: $e");
  }
}

Future<String?> showLanguageSelectionDialog(BuildContext context) async {
  List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'ms', 'name': 'Malay'},
  ];

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Choose Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((language) {
            return ListTile(
              title: Text(language['name']!),
              onTap: () {
                Navigator.pop(context, language['code']);
              },
            );
          }).toList(),
        ),
      );
    },
  );
}

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
    setupTranslationService().then((_) {
      if (mounted) setState(() {}); // Ensure the widget is still mounted
    });
    loadUserPhone();
    WidgetsBinding.instance.addObserver(this);

    // Ensure default scroll to bottom after widget build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToBottom();
    });
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


  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      // Keyboard is visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom(); // Scroll to the bottom
      });
    }
  }


  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100)); // Add a small delay
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
      return (data['timestamp'] as Timestamp)
          .toDate()
          .isAtSameMomentAs(timestamp);
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

  Future<void> pinMessage(
      String messageID, String conversationID, Timestamp timestamp) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('messageID', isEqualTo: messageID)
          .where('conversationID', isEqualTo: conversationID)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
              const SnackBar(content: Text("Message is already pinned!")));
      } else {
        await FirebaseFirestore.instance.collection('bookmarks').add({
          'messageID': messageID,
          'conversationID': conversationID,
          'timestamp': timestamp,
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("Message pinned!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text("Failed to pin message.")));
    }
  }

  Future<void> saveTranslatedMessage(
      String conversationID,
      String messageID,
      String translatedContent,
      String translatedLanguage,
      Timestamp timestamp) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationID)
        .collection('messages')
        .doc(messageID)
        .collection('translatedMessage')
        .add({
      'translatedMessageID': messageID, // Reference the original message ID
      'translatedContent': translatedContent,
      'translatedLanguage': translatedLanguage,
      'timestamp': timestamp,
    });
  }

  void showMessageOptions(BuildContext context,
      Map<String, dynamic> messageData, String messageID) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext modalContext) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('View Message Info'),
              onTap: () {
                if (mounted)
                  Navigator.pop(modalContext); // Ensure context is valid
                showDialog(
                  context: modalContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Message Info'),
                    content:
                        Text('Sent at: ${messageData['timestamp'].toDate()}'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: const Text('Pin Message'),
              onTap: () async {
                if (mounted) Navigator.pop(context); // Ensure context is valid
                await pinMessage(
                    messageID, widget.conversationID, messageData['timestamp']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translate Message'),
              onTap: () async {
                if (mounted) Navigator.pop(modalContext);

                final originalMessage = messageData['content'] ?? '';
                final selectedLanguage =
                    await showLanguageSelectionDialog(modalContext);
                if (selectedLanguage == null) {
                  return;
                }

                try {
                  final translatedMessageRef = FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(widget.conversationID)
                      .collection('messages')
                      .doc(messageID)
                      .collection('translatedMessage');

                  final existingTranslations = await translatedMessageRef.get();

                  if (existingTranslations.docs.isNotEmpty) {
                    var existingDoc = existingTranslations.docs.first;
                    var existingData = existingDoc.data();
                    var existingLanguage = existingData['translatedLanguage'];

                    if (existingLanguage == selectedLanguage) {
                      // Show a dialog if the same language was already translated
                      if (mounted) {
                        showDialog(
                          context: modalContext,
                          builder: (context) => AlertDialog(
                            title: const Text('Already Translated'),
                            content: const Text(
                                'This message is already translated into the selected language.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                      return;
                    } else {
                      // Update the existing translation with the new language
                      final translatedText = await translationService
                          .translateText(originalMessage, selectedLanguage);

                      await existingDoc.reference.update({
                        'translatedContent': translatedText,
                        'translatedLanguage': selectedLanguage,
                        'timestamp': Timestamp.now(),
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Translation updated successfully!"),
                          ),
                        );
                      }
                    }
                  } else {
                    // Create a new translation document
                    final translatedText = await translationService
                        .translateText(originalMessage, selectedLanguage);

                    await translatedMessageRef.add({
                      'translatedMessageID': messageID,
                      'translatedContent': translatedText,
                      'translatedLanguage': selectedLanguage,
                      'timestamp': Timestamp.now(),
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Translation saved successfully!"),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("This message is already translated into the selected language.")),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: messageData['content']));
                if (mounted) {
                  Navigator.pop(context); // Ensure context is valid
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Message copied to clipboard!")),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Message'),
              onTap: () async {
                if (mounted) Navigator.pop(context); // Ensure context is valid
                await FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(widget.conversationID)
                    .collection('messages')
                    .doc(messageID)
                    .delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Message deleted!")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
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
            var messageID =
                message.id; // Get the Firestore document ID as messageID

            bool isSentByUser = senderID == userPhone;

            bool isHighlighted = widget.initialTimestamp != null &&
                timestamp.toDate().isAtSameMomentAs(widget.initialTimestamp!);

            return GestureDetector(
              onLongPress: () => showMessageOptions(
                  context, data, messageID), // Pass the messageID
              child: Padding(
                padding: isSentByUser
                    ? const EdgeInsets.only(left: 80, top: 10)
                    : const EdgeInsets.only(right: 80, top: 10),
                child: Align(
                  alignment: isSentByUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isSentByUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      ClipPath(
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
                      // Translated message displayed right below the original message
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('conversations')
                            .doc(widget.conversationID)
                            .collection('messages')
                            .doc(messageID)
                            .collection('translatedMessage')
                            .snapshots(),
                        builder: (context, translatedSnapshot) {
                          if (!translatedSnapshot.hasData ||
                              translatedSnapshot.data!.docs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          var translatedData =
                              translatedSnapshot.data!.docs.first.data()
                                  as Map<String, dynamic>;
                          var translatedContent =
                              translatedData['translatedContent'];

                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSentByUser
                                    ? const Color(0xFF0D5683)
                                    : Colors.lightBlue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                translatedContent,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: isSentByUser
                                      ? Colors.white
                                      : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
