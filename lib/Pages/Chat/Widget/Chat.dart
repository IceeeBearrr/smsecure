import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_clippers/custom_clippers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:smsecure/Pages/Chat/Widget/GoogleTranslation.dart';
import 'dart:async';
import 'package:intl/intl.dart';

final translationService = GoogleTranslationService();

Future<void> setupTranslationService() async {
  try {
      print("Initializing translation service...");
    await translationService
        .initialize('assets/credentials/smsecure-c19e8e1aa9d1.json');
    print("Translation service initialized successfully.");
    } on PlatformException catch (e) {
    print("PlatformException initializing translation service: ${e.message}");
  } on Exception catch (e) {
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
  final String? initialMessageID;

  const Chat({super.key, required this.conversationID, this.initialMessageID});

  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final storage = const FlutterSecureStorage();
  String? userPhone;
  bool isJumpingToMessage = false;
  Map<String, GlobalKey> messageKeys = {};
  String? highlightedMessageID;
  List<QueryDocumentSnapshot> allMessages = [];
  bool isLoading = true;
  String? userID;
  @override
  void initState() {
    super.initState();
    setupTranslationService().then((_) {
      if (mounted) setState(() {});
    });
    loadUserPhone();
    WidgetsBinding.instance.addObserver(this);
    fetchAllMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMessageID != null) {
        Future.delayed(const Duration(milliseconds: 200), () {
          jumpToMessageByIndex(widget.initialMessageID!);
        });
      }
    });
  }

  Future<void> fetchAllMessages() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      setState(() {
        allMessages = snapshot.docs;
        isLoading = false;

        // Assign GlobalKeys for all messages
        for (var message in allMessages) {
          final messageID = message.id;
          if (!messageKeys.containsKey(messageID)) {
            messageKeys[messageID] = GlobalKey();
            print("Assigned GlobalKey to messageID: $messageID");
          }
        }
      });
      if (widget.initialMessageID != null) {
        jumpToMessageByIndex(widget.initialMessageID!);
      } else {
        scrollToBottom();
      }
    } catch (e) {
      print("Error fetching messages: $e");
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Jump to a specific message based on the provided timestamp
void jumpToMessageByIndex(String messageID, {int maxRetries = 50, int delayMs = 100}) async {
  int retryCount = 0;

  while (retryCount < maxRetries) {
    final key = messageKeys[messageID];
    if (key != null && key.currentContext != null) {
      final context = key.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final offset = box.localToGlobal(Offset.zero).dy +
              _scrollController.offset -
              (MediaQuery.of(context).size.height / 2); // Center the message

          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );

          // Highlight the message
          setState(() {
            highlightedMessageID = messageID;
          });

          Future.delayed(const Duration(seconds: 2), () {
            setState(() {
              highlightedMessageID = null;
            });
          });

          print("Successfully jumped to message ID: $messageID");
          return; // Exit the loop once successful
        }
      }
    }

    retryCount++;
    print("Context not found for message ID: $messageID. Retrying... ($retryCount/$maxRetries)");
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  print("Failed to jump to message ID: $messageID after $maxRetries retries.");
}


  Widget buildMessage(QueryDocumentSnapshot message, bool isHighlighted) {
    final data = message.data() as Map<String, dynamic>;
    final isSentByUser = data['senderID'] == userPhone;
    final messageContent = data['content'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: isHighlighted ? Colors.yellow.shade300 : null,
      child: Row(
        mainAxisAlignment:
            isSentByUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isSentByUser ? Colors.blue : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                messageContent,
                style: TextStyle(
                  color: isSentByUser ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> pinOrUnpinMessage(
      String messageID, String conversationID, Timestamp timestamp) async {
    try {
      userPhone = await storage.read(key: "userPhone");
      if (userPhone != null) {
        QuerySnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .where('phoneNo', isEqualTo: userPhone)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          userID = userSnapshot.docs.first.id;
        }
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('messageID', isEqualTo: messageID)
          .where('conversationID', isEqualTo: conversationID)
          .where('smsUserID', isEqualTo: userID)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // If the message is already pinned, unpin it
        await querySnapshot.docs.first.reference.delete();

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("Message unpinned!")));
      } else {
        // Otherwise, pin the message
        await FirebaseFirestore.instance.collection('bookmarks').add({
          'messageID': messageID,
          'conversationID': conversationID,
          'timestamp': timestamp,
          'smsUserID': userID,
        });

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text("Message pinned!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text("Failed to update pin status.")));
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
    // Format the date
    String formatDate(Timestamp timestamp) {
      final DateTime dateTime = timestamp.toDate(); // Convert to DateTime
      final DateFormat formatter =
          DateFormat('dd MMM yyyy, hh:mm a'); // Define the format
      return formatter.format(dateTime); // Format the DateTime
    }

    showModalBottomSheet(
        context: context,
        builder: (BuildContext modalContext) {
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('bookmarks')
                .where('messageID', isEqualTo: messageID)
                .where('conversationID', isEqualTo: widget.conversationID)
                .get(),
            builder: (context, snapshot) {
              bool isPinned =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              return Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('View Message Info'),
                    onTap: () {
                      if (mounted) {
                        Navigator.pop(modalContext); // Ensure context is valid
                      }
                      showDialog(
                        context: modalContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Message Info'),
                          content: Text(
                            'Sent at: ${formatDate(messageData['timestamp'])}', // Use the formatted date
                          ),
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
                    leading: Icon(
                        isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                    title: Text(isPinned ? 'Unpin Message' : 'Pin Message'),
                    onTap: () async {
                      if (mounted) Navigator.pop(context);
                      await pinOrUnpinMessage(messageID, widget.conversationID,
                          messageData['timestamp']);
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

                        final existingTranslations =
                            await translatedMessageRef.get();

                        if (existingTranslations.docs.isNotEmpty) {
                          var existingDoc = existingTranslations.docs.first;
                          var existingData = existingDoc.data();
                          var existingLanguage =
                              existingData['translatedLanguage'];

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
                            final translatedText =
                                await translationService.translateText(
                                    originalMessage, selectedLanguage);

                            await existingDoc.reference.update({
                              'translatedContent': translatedText,
                              'translatedLanguage': selectedLanguage,
                              'timestamp': Timestamp.now(),
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Translation updated successfully!"),
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
                                content:
                                    Text("Translation saved successfully!"),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "This message is already translated into the selected language.")),
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: const Text('Copy Message'),
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: messageData['content']));
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
                      // Capture the parent context for dialog use
                      final parentContext = Navigator.of(context).context;

                      // Close the bottom sheet
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      // Show a confirmation dialog using the parentContext
                      bool? confirmed = await showDialog<bool>(
                        context: parentContext,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text('Confirm Deletion'),
                            content: const Text(
                                'Are you sure you want to delete this message? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(false);
                                },
                              ),
                              TextButton(
                                child: const Text('Delete'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed == true) {
                        try {
                          // Reference to the message document
                          DocumentReference messageRef = FirebaseFirestore
                              .instance
                              .collection('conversations')
                              .doc(widget.conversationID)
                              .collection('messages')
                              .doc(messageID);

                          // Delete the translatedMessage sub-collection
                          QuerySnapshot translatedMessagesSnapshot =
                              await messageRef
                                  .collection('translatedMessage')
                                  .get();

                          for (var doc in translatedMessagesSnapshot.docs) {
                            await doc.reference.delete();
                          }

                          // Delete the message itself
                          await messageRef.delete();

                          // Check if the message exists in the bookmarks collection
                          QuerySnapshot bookmarkSnapshot =
                              await FirebaseFirestore.instance
                                  .collection('bookmarks')
                                  .where('messageID', isEqualTo: messageID)
                                  .where('conversationID',
                                      isEqualTo: widget.conversationID)
                                  .get();

                          // If the bookmark exists, delete it
                          for (var doc in bookmarkSnapshot.docs) {
                            await doc.reference.delete();
                          }

                          // Show success dialog using the parentContext
                          if (mounted) {
                            showDialog(
                              context: parentContext,
                              builder: (BuildContext successContext) {
                                return AlertDialog(
                                  title: const Text('Success'),
                                  content: const Text(
                                      'Message deleted successfully.'),
                                  actions: [
                                    TextButton(
                                      child: const Text('OK'),
                                      onPressed: () {
                                        Navigator.of(successContext).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        } catch (e) {
                          // Show error dialog using the parentContext
                          if (mounted) {
                            showDialog(
                              context: parentContext,
                              builder: (BuildContext errorContext) {
                                return AlertDialog(
                                  title: const Text('Error'),
                                  content: const Text(
                                      'Failed to delete the message, translations, or bookmark.'),
                                  actions: [
                                    TextButton(
                                      child: const Text('OK'),
                                      onPressed: () {
                                        Navigator.of(errorContext).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              );
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .collection('messages')
          .where('isBlacklisted',
              isEqualTo: false) // Exclude blacklisted messages

          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var messages = snapshot.data!.docs;

        if (widget.initialMessageID == null && messages.isNotEmpty) {
          // Scroll to the bottom only if no initialMessageID is provided
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToBottom();
          });
        }

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

            // Assign a unique key for each message
            if (!messageKeys.containsKey(messageID)) {
              messageKeys[messageID] = GlobalKey();
              print("Assigned GlobalKey to messageID: $messageID");
            }

            return GestureDetector(
              key: messageKeys[messageID],
              onLongPress: () => showMessageOptions(
                  context, data, messageID), // Pass the messageID
              child: Padding(
                padding: isSentByUser
                    ? const EdgeInsets.only(left: 20, top: 10)
                    : const EdgeInsets.only(right: 20, top: 10),
                child: Align(
                  alignment: isSentByUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Column(
                      crossAxisAlignment: isSentByUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          child: ClipPath(
                            clipper: isSentByUser
                                ? LowerNipMessageClipper(MessageType.send)
                                : UpperNipMessageClipper(MessageType.receive),
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('bookmarks')
                                  .where('messageID', isEqualTo: messageID)
                                  .where('conversationID',
                                      isEqualTo: widget.conversationID)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                bool isPinned = snapshot.hasData &&
                                    snapshot.data!.docs.isNotEmpty;

                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isSentByUser
                                        ? const Color(0xFF113953)
                                        : const Color(0xFFE1E1E2),
                                    border: messageID == highlightedMessageID
                                        ? Border.all(
                                            color: Colors.orange,
                                            width: 2,
                                          )
                                        : null, // Highlight the message
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          messageContent,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isSentByUser
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (isPinned)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: Icon(
                                            Icons.push_pin,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
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
              ),
            );
          },
        );
      },
    );
  }
}
