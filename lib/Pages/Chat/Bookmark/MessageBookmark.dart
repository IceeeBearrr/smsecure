import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/Chat/ChatPage.dart';

class MessageBookmark extends StatefulWidget {
  final String conversationId;

  const MessageBookmark({super.key, required this.conversationId});

  @override
  _MessageBookmarkState createState() => _MessageBookmarkState();
}

class _MessageBookmarkState extends State<MessageBookmark> {
  final storage = const FlutterSecureStorage();
  String? userPhone;
  String? userProfileImageBase64;
  String? participantPhoneNo;
  String? participantName;
  String? participantProfileImageBase64;
  bool isLoading = true;
  String searchText = ""; // Store the current search text

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    try {
      // Step 1: Get the current user's phone number and profile image
      userPhone = await storage.read(key: "userPhone");
      if (userPhone == null) throw Exception("User phone not found");

      await fetchUserDetails();

      // Step 2: Fetch the conversation details
      DocumentSnapshot conversationSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (!conversationSnapshot.exists) {
        throw Exception("Conversation not found");
      }

      // Step 3: Identify the participant's phone number
      List<String> participants =
          List<String>.from(conversationSnapshot['participants']);
      participantPhoneNo = participants.firstWhere(
        (phone) => phone != userPhone,
        orElse: () => 'Unknown',
      );

      if (participantPhoneNo == 'Unknown') {
        throw Exception("Participant not found");
      }

      // Step 4: Fetch participant details
      await fetchParticipantDetails();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching details: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserDetails() async {
    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .get()
          .then((snapshot) => snapshot.docs.isNotEmpty
              ? snapshot.docs.first
              : throw Exception("User not found"));

      Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;
      userProfileImageBase64 = userData['profileImageUrl'];
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
  }

  Future<void> fetchParticipantDetails() async {
    try {
      QuerySnapshot contactSnapshot = await FirebaseFirestore.instance
          .collection('contact')
          .where('phoneNo', isEqualTo: participantPhoneNo)
          .get();

      if (contactSnapshot.docs.isNotEmpty) {
        // If contact exists
        Map<String, dynamic> contactData =
            contactSnapshot.docs.first.data() as Map<String, dynamic>;
        participantName = contactData['name'] ?? participantPhoneNo;
        participantProfileImageBase64 = contactData['profileImageUrl'];
      } else {
        // Fallback to 'smsUser' collection
        DocumentSnapshot smsUserSnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(participantPhoneNo)
            .get();

        if (smsUserSnapshot.exists) {
          Map<String, dynamic> smsUserData =
              smsUserSnapshot.data() as Map<String, dynamic>;
          participantName = smsUserData['name'] ?? participantPhoneNo;
          participantProfileImageBase64 = smsUserData['profileImageUrl'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching participant details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pinned Messages",
          style: TextStyle(
            color: Color(0xFF113953),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  color: Color(0xFF113953),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 15),
                                    child: TextFormField(
                                      decoration: const InputDecoration(
                                        hintText: "Search pinned messages",
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          searchText = value.trim().toLowerCase();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // List of Pinned Messages
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('bookmarks')
                          .where('conversationID',
                              isEqualTo: widget.conversationId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No pinned messages found.'),
                          );
                        }

                        // Retrieve and filter messages based on searchText
                        var filteredDocs = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            var bookmark = filteredDocs[index].data()
                                as Map<String, dynamic>;
                            String messageId = bookmark['messageID'];

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('conversations')
                                  .doc(widget.conversationId)
                                  .collection('messages')
                                  .doc(messageId)
                                  .get(),
                              builder: (context, messageSnapshot) {
                                if (!messageSnapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                if (!messageSnapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }

                                var messageData = messageSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                String content =
                                    messageData['content']?.toLowerCase() ?? "";
                                    Timestamp timestamp = messageData['timestamp'] as Timestamp;


                                if (!content.contains(searchText)) {
                                  return const SizedBox.shrink();
                                }

                                bool isSentByUser =
                                    messageData['senderID'] == userPhone;

                                return ListTile(
                                  onTap: () {
                                    // Navigate to Chat with initialTimestamp
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Chatpage(
                                          conversationID: widget.conversationId,
                                          initialTimestamp:
                                              timestamp.toDate(),
                                        ),
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    backgroundImage: isSentByUser
                                        ? (userProfileImageBase64 != null
                                            ? MemoryImage(base64Decode(
                                                userProfileImageBase64!))
                                            : null)
                                        : (participantProfileImageBase64 != null
                                            ? MemoryImage(base64Decode(
                                                participantProfileImageBase64!))
                                            : null),
                                    backgroundColor: Colors.grey.shade200,
                                    child: (isSentByUser
                                            ? userProfileImageBase64
                                            : participantProfileImageBase64) ==
                                        null
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    isSentByUser ? "You" : participantName ?? "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    messageData['content'] ?? 'No content',
                                  ),
                                  trailing: Text(
                                    (messageData['timestamp'] as Timestamp)
                                        .toDate()
                                        .toLocal()
                                        .toString()
                                        .split(' ')[0], // Display date only
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}