import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Chat/ChatPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Recentchats extends StatefulWidget {
  final String currentUserID;
  final String searchText; // Accept search input

  const Recentchats(
      {super.key, required this.currentUserID, required this.searchText});

  @override
  _RecentchatsState createState() => _RecentchatsState();
}

class _RecentchatsState extends State<Recentchats> {
  final storage = const FlutterSecureStorage();
  String? currentUserSmsUserID;
  Map<String, Map<String, dynamic>> contactCache = {};
  bool isLoadingContacts = true;
  List<String> spamContacts = []; // List to store spam contacts
  String? currentUserPhone;

  // Stateful variable for FutureBuilder
  late Future<List<QueryDocumentSnapshot>> filteredConversationsFuture;

  @override
  void initState() {
    super.initState();
    filteredConversationsFuture = fetchFilteredConversations();
    loadCurrentUserSmsUserID();
    loadCurrentUserPhone();
  }

  // Call this to reload conversations
  void reloadConversations() {
    setState(() {
      filteredConversationsFuture = fetchFilteredConversations();
    });
  }

  Future<void> loadCurrentUserPhone() async {
    currentUserPhone = await storage.read(key: "userPhone");
    setState(() {}); // Trigger rebuild after loading
  }

  Future<void> loadCurrentUserSmsUserID() async {
    String? userPhone = await storage.read(key: "userPhone");

    if (userPhone != null) {
      final smsUserSnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .get();

      if (smsUserSnapshot.docs.isNotEmpty) {
        currentUserSmsUserID = smsUserSnapshot.docs.first.id;
      }
    }

    // Load spam contacts with `isRemoved: false` for the current user
    if (currentUserSmsUserID != null) {
      spamContacts =
          await fetchSpamContactsForCurrentUser(currentUserSmsUserID!);
    }

    // Once we have the current user's smsUserID, preload contacts
    if (currentUserSmsUserID != null) {
      await preloadContacts();
    }

    setState(() {
      isLoadingContacts =
          false; // Set loading to false after preloading is complete
    });
  }

  Future<List<String>> fetchSpamContactsForCurrentUser(String smsUserID) async {
    final spamSnapshot = await FirebaseFirestore.instance
        .collection('spamContact')
        .where('smsUserID', isEqualTo: smsUserID)
        .where('isRemoved', isEqualTo: false)
        .get();

    return spamSnapshot.docs.map((doc) => doc['phoneNo'] as String).toList();
  }

  Future<void> preloadContacts() async {
    final conversationsSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .orderBy('lastMessageTimeStamp', descending: true)
        .get();

    List<String> participantPhones = [];

    for (var conversation in conversationsSnapshot.docs) {
      if (conversation.data().containsKey('smsUserID') &&
          conversation['smsUserID'] == currentUserSmsUserID) {
        var participants =
            List<String>.from(conversation['participants'] ?? []);
        var otherUserPhone = participants.firstWhere(
            (id) => id != widget.currentUserID,
            orElse: () => 'Unknown');
        if (otherUserPhone != 'Unknown' &&
            !contactCache.containsKey(otherUserPhone)) {
          participantPhones.add(otherUserPhone);
        }
      }
    }

    for (var participantPhone in participantPhones) {
      final contactData = await fetchParticipantContact(participantPhone);
      contactCache[participantPhone] = contactData;
    }
  }

  Future<Map<String, dynamic>> fetchParticipantContact(
      String participantPhone) async {
    if (currentUserSmsUserID == null) {
      return {'name': participantPhone, 'profileImage': null};
    }

    final contactSnapshot = await FirebaseFirestore.instance
        .collection('contact')
        .where('smsUserID', isEqualTo: currentUserSmsUserID)
        .where('phoneNo', isEqualTo: participantPhone)
        .get();

    if (contactSnapshot.docs.isNotEmpty) {
      var contactData = contactSnapshot.docs.first.data();
      String? name = contactData['name'];
      String? profileImageUrl = contactData['profileImageUrl'];
      String? registeredSmsUserID = contactData['registeredSmsUserID'];

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        return {'name': name, 'profileImage': profileImageUrl};
      } else if (registeredSmsUserID != null &&
          registeredSmsUserID.isNotEmpty) {
        final registeredSmsUserSnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(registeredSmsUserID)
            .get();

        if (registeredSmsUserSnapshot.exists &&
            registeredSmsUserSnapshot.data()!['profileImageUrl'] != null) {
          return {
            'name': name,
            'profileImage': registeredSmsUserSnapshot.data()!['profileImageUrl']
          };
        }
      }
      return {'name': name, 'profileImage': null};
    }
    return {'name': participantPhone, 'profileImage': null};
  }

  String formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    DateTime yesterday = now.subtract(const Duration(days: 1));

    if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(now)) {
      return DateFormat('HH:mm').format(date);
    } else if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('d MMM').format(date);
    }
  }

  void _showOptions(BuildContext context, String conversationID, String phoneNo,
      String name) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                title: const Text('View Conversation'),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          Chatpage(conversationID: conversationID),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text(
                  'Blacklist',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  _confirmBlacklist(context, phoneNo, name, conversationID);
                },
              ),
              ListTile(
                title: const Text(
                  'Delete Conversation',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  _confirmDelete(context, conversationID);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmBlacklist(BuildContext context, String phoneNo, String name,
      String conversationID) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Blacklist'),
          content: Text('Are you sure you want to blacklist $name ($phoneNo)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
                _blacklistConversation(
                    name, phoneNo, conversationID); // Perform blacklist action
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _blacklistConversation(
      String name, String phoneNo, String conversationID) async {
    try {
      String? currentUserPhone = await storage.read(key: "userPhone");
      if (currentUserPhone == null) throw Exception("User phone not found");

      QuerySnapshot smsUserQuery = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: currentUserPhone)
          .limit(1)
          .get();

      if (smsUserQuery.docs.isEmpty) {
        throw Exception("SMS user not found");
      }

      String smsUserID = smsUserQuery.docs.first.id;

      // Add to blacklist collection
      await FirebaseFirestore.instance.collection('blacklist').add({
        'blacklistedDateTime': Timestamp.now(),
        'blacklistedFrom': 'Chat',
        'name': name,
        'phoneNo': phoneNo,
        'smsUserID': smsUserID,
      });

      // Update contact collection
      QuerySnapshot contactQuery = await FirebaseFirestore.instance
          .collection('contact')
          .where('phoneNo', isEqualTo: phoneNo)
          .where('smsUserID', isEqualTo: smsUserID)
          .get();

      for (var doc in contactQuery.docs) {
        await doc.reference.update({'isBlacklisted': true});
      }

      // Update conversations collection
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationID)
          .update({'isBlacklisted': true});

      // Show success message
      _showSuccessDialog(
        context,
        "Blacklist Success",
        "The participant has been successfully blacklisted.",
      );
      reloadConversations();
    } catch (e) {
      debugPrint("Error blacklisting participant: $e");
      _showErrorDialog(
        context,
        "Blacklist Error",
        "Failed to blacklist participant. Please try again.",
      );
    }
  }

  void _confirmDelete(BuildContext context, String conversationID) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text(
              'Are you sure you want to delete this conversation? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
                _deleteConversation(conversationID); // Perform delete action
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteConversation(String conversationID) async {
    try {
      // Delete messages sub-collection
      QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationID)
          .collection('messages')
          .get();

      for (var messageDoc in messagesSnapshot.docs) {
        QuerySnapshot translatedMessagesSnapshot =
            await messageDoc.reference.collection('translatedMessage').get();

        // Delete translatedMessages sub-collection
        for (var translatedMessageDoc in translatedMessagesSnapshot.docs) {
          await translatedMessageDoc.reference.delete();
        }

        // Delete message document
        await messageDoc.reference.delete();
      }

      // Delete conversation document
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationID)
          .delete();

      // Delete bookmarks where conversationID and smsUserID match
      QuerySnapshot bookmarksSnapshot = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('conversationID', isEqualTo: conversationID)
          .where('smsUserID', isEqualTo: currentUserSmsUserID)
          .get();

      for (var bookmarkDoc in bookmarksSnapshot.docs) {
        await bookmarkDoc.reference.delete();
      }

      // Show success message
      _showSuccessDialog(
        context,
        "Delete Success",
        "The conversation has been successfully deleted.",
      );
      reloadConversations();
    } catch (e) {
      debugPrint("Error deleting conversation: $e");
      _showErrorDialog(
        context,
        "Delete Error",
        "Failed to delete conversation. Please try again.",
      );
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<List<QueryDocumentSnapshot>> fetchFilteredConversations() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .orderBy('lastMessageTimeStamp', descending: true)
        .get();

    List<QueryDocumentSnapshot> filteredConversations = [];

    for (var conversation in snapshot.docs) {
      var messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversation.id)
          .collection('messages')
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        filteredConversations.add(conversation);
      }
    }

    // Further filtering logic (spam, blacklist, search) can go here
    filteredConversations = filteredConversations.where((conversation) {
      bool isBlacklisted = conversation.get('isBlacklisted') ?? false;
      bool isSpam = conversation.get('isSpam') ?? false;
      return !isBlacklisted && !isSpam;
    }).toList();

    return filteredConversations;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingContacts) {
      return const Center(
          child:
              CircularProgressIndicator()); // Show loading indicator while preloading
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: fetchFilteredConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No conversations available"));
          }

          var filteredConversations = snapshot.data!;

          // Filter out conversations involving spam contacts with `isRemoved: false`
          filteredConversations = filteredConversations.where((conversation) {
            var participants =
                List<String>.from(conversation['participants'] ?? []);
            var otherUserPhone = participants.firstWhere(
                (id) => id != widget.currentUserID,
                orElse: () => '');
            return !spamContacts
                .contains(otherUserPhone); // Only exclude active spam contacts
          }).toList();

          // Filter out blacklisted or spam conversations
          filteredConversations = filteredConversations.where((conversation) {
            bool isBlacklisted = conversation.get('isBlacklisted') ?? false;
            bool isSpam = conversation.get('isSpam') ?? false;
            return !isBlacklisted && !isSpam;
          }).toList();

          // Filter conversations based on search text
          filteredConversations = filteredConversations.where((conversation) {
            var participants =
                List<String>.from(conversation['participants'] ?? []);
            var otherUserPhone = participants.firstWhere(
                (id) => id != widget.currentUserID,
                orElse: () => '');
            final contactDetails =
                contactCache[otherUserPhone] ?? {'name': otherUserPhone};

            final name = contactDetails['name']?.toString().toLowerCase() ?? '';
            final phoneNo = otherUserPhone.toLowerCase();

            return name.contains(widget.searchText) ||
                phoneNo.contains(widget.searchText);
          }).toList();

          return Column(
            children: [
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 8.0,
                  radius: const Radius.circular(8),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      var conversation = filteredConversations[index];
                      var participants =
                          List<String>.from(conversation['participants'] ?? []);
                      var otherUserPhone = participants.firstWhere(
                          (id) => id != widget.currentUserID,
                          orElse: () => 'Unknown');
                      var lastMessageTimeStamp =
                          conversation['lastMessageTimeStamp'] as Timestamp?;
                      var formattedDate = lastMessageTimeStamp != null
                          ? formatDate(lastMessageTimeStamp)
                          : 'Unknown';

                      // Use preloaded contact data
                      final contactDetails = contactCache[otherUserPhone] ??
                          {'name': otherUserPhone, 'profileImage': null};
                      final name = contactDetails['name'];
                      final profileImageBase64 = contactDetails['profileImage'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Chatpage(
                                  conversationID: conversation.id,
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            // Show options when long-pressed
                            _showOptions(
                                context, conversation.id, otherUserPhone, name);
                          },
                          child: SizedBox(
                            height: 65,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(33),
                                  child: profileImageBase64 != null
                                      ? Image.memory(
                                          base64Decode(profileImageBase64),
                                          height: 65,
                                          width: 65,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          "images/HomePage/defaultProfile.png",
                                          height: 65,
                                          width: 65,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Color(0xFF113953),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('conversations')
                                              .doc(conversation.id)
                                              .collection('messages')
                                              .orderBy('timestamp',
                                                  descending: true)
                                              .limit(1)
                                              .snapshots(),
                                          builder: (context, messageSnapshot) {
                                            if (!messageSnapshot.hasData ||
                                                messageSnapshot
                                                    .data!.docs.isEmpty) {
                                              return const Text(
                                                "No messages yet...",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black54),
                                              );
                                            }
                                            var latestMessage = messageSnapshot
                                                .data!.docs.first;
                                            var messageContent =
                                                latestMessage.get('content') ??
                                                    '';
                                            return Text(
                                              messageContent,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black54),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.black54),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      // Ensure currentUserPhone is loaded before proceeding
                                      currentUserPhone == null
                                          ? Container() // Show nothing while loading
                                          : StreamBuilder<DocumentSnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('conversations')
                                                  .doc(conversation.id)
                                                  .snapshots(),
                                              builder: (context, snapshot) {
                                                if (!snapshot.hasData ||
                                                    snapshot.data == null ||
                                                    !snapshot.data!.exists) {
                                                  return Container(); // Return an empty container if no data
                                                }

                                                var conversationData =
                                                    snapshot.data!.data()
                                                        as Map<String, dynamic>;

                                                if (conversationData == null) {
                                                  return Container(); // Handle case where data is null
                                                }
                                                var participantData =
                                                    conversationData[
                                                            'participantData'] ??
                                                        {};

                                                int unreadCount = 0;

                                                if (participantData[
                                                        currentUserPhone] !=
                                                    null) {
                                                  unreadCount = participantData[
                                                              currentUserPhone]
                                                          ['unreadCount'] ??
                                                      0;
                                                }

                                                return unreadCount > 0
                                                    ? Container(
                                                        height: 23,
                                                        width: 23,
                                                        alignment:
                                                            Alignment.center,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFF113953),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(25),
                                                        ),
                                                        child: Text(
                                                          unreadCount
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      )
                                                    : Container(); // Return an empty container if no unread count
                                              },
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
