import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Chat/ChatPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Recentchats extends StatefulWidget {
  final String currentUserID;
  final String searchText; // Accept search input

  const Recentchats({super.key, required this.currentUserID, required this.searchText});

  @override
  _RecentchatsState createState() => _RecentchatsState();
}

class _RecentchatsState extends State<Recentchats> {
  final storage = const FlutterSecureStorage();
  String? currentUserSmsUserID;
  Map<String, Map<String, dynamic>> contactCache = {};
  bool isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    loadCurrentUserSmsUserID();
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

    // Once we have the current user's smsUserID, preload contacts
    if (currentUserSmsUserID != null) {
      await preloadContacts();
    }

    setState(() {
      isLoadingContacts = false; // Set loading to false after preloading is complete
    });
  }

  Future<void> preloadContacts() async {
    final conversationsSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .orderBy('lastMessageTimeStamp', descending: true)
        .get();

    List<String> participantPhones = [];

    for (var conversation in conversationsSnapshot.docs) {
      if (conversation.data().containsKey('smsUserID') && conversation['smsUserID'] == currentUserSmsUserID) {
        var participants = List<String>.from(conversation['participants'] ?? []);
        var otherUserPhone = participants.firstWhere((id) => id != widget.currentUserID, orElse: () => 'Unknown');
        if (otherUserPhone != 'Unknown' && !contactCache.containsKey(otherUserPhone)) {
          participantPhones.add(otherUserPhone);
        }
      }
    }

    for (var participantPhone in participantPhones) {
      final contactData = await fetchParticipantContact(participantPhone);
      contactCache[participantPhone] = contactData;
    }
  }

  Future<Map<String, dynamic>> fetchParticipantContact(String participantPhone) async {
    if (currentUserSmsUserID == null) return {'name': participantPhone, 'profileImage': null};

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
      } else if (registeredSmsUserID != null && registeredSmsUserID.isNotEmpty) {
        final registeredSmsUserSnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(registeredSmsUserID)
            .get();

        if (registeredSmsUserSnapshot.exists && registeredSmsUserSnapshot.data()!['profileImageUrl'] != null) {
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

    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now)) {
      return DateFormat('HH:mm').format(date);
    } else if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('d MMM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingContacts) {
      return const Center(child: CircularProgressIndicator()); // Show loading indicator while preloading
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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .orderBy('lastMessageTimeStamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No conversations available"));
          }

          var conversations = snapshot.data!.docs;

          // Filter conversations based on search text
          conversations = conversations.where((conversation) {
            var participants = List<String>.from(conversation['participants'] ?? []);
            var otherUserPhone = participants.firstWhere((id) => id != widget.currentUserID, orElse: () => '');
            final contactDetails = contactCache[otherUserPhone] ?? {'name': otherUserPhone};

            final name = contactDetails['name']?.toString().toLowerCase() ?? '';
            final phoneNo = otherUserPhone.toLowerCase();

            return name.contains(widget.searchText) || phoneNo.contains(widget.searchText);
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
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      var conversation = conversations[index];
                      var participants = List<String>.from(conversation['participants'] ?? []);
                      var otherUserPhone = participants.firstWhere((id) => id != widget.currentUserID, orElse: () => 'Unknown');
                      var lastMessageTimeStamp = conversation['lastMessageTimeStamp'] as Timestamp?;
                      var formattedDate = lastMessageTimeStamp != null ? formatDate(lastMessageTimeStamp) : 'Unknown';

                      // Use preloaded contact data
                      final contactDetails = contactCache[otherUserPhone] ?? {'name': otherUserPhone, 'profileImage': null};
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                              .orderBy('timestamp', descending: true)
                                              .limit(1)
                                              .snapshots(),
                                          builder: (context, messageSnapshot) {
                                            if (!messageSnapshot.hasData || messageSnapshot.data!.docs.isEmpty) {
                                              return const Text(
                                                "No messages yet...",
                                                style: TextStyle(fontSize: 16, color: Colors.black54),
                                              );
                                            }
                                            var latestMessage = messageSnapshot.data!.docs.first;
                                            var messageContent = latestMessage.get('content') ?? '';
                                            return Text(
                                              messageContent,
                                              style: const TextStyle(fontSize: 16, color: Colors.black54),
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
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(fontSize: 15, color: Colors.black54),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 23,
                                        width: 23,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF113953),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        child: const Text(
                                          "1",
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
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
