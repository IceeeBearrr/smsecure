import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/Chat/ChatPage.dart';

class SearchMessageChatPage extends StatefulWidget {
  final String conversationID;

  const SearchMessageChatPage({super.key, required this.conversationID});

  @override
  _SearchMessageChatPageState createState() => _SearchMessageChatPageState();
}

class _SearchMessageChatPageState extends State<SearchMessageChatPage> {
  final TextEditingController searchController = TextEditingController();
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String? userPhone;
  String? userProfileImageBase64;
  String? participantPhoneNo;
  String? participantName;
  String? participantProfileImageBase64;
  List<Map<String, dynamic>> allMessages = [];
  String searchText = ""; // Store the current search text
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    try {
      // Fetch user details
      userPhone = await storage.read(key: "userPhone");
      if (userPhone == null) throw Exception("User phone not found");

      await fetchUserDetails();

      // Fetch conversation participants
      DocumentSnapshot conversationSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .get();

      if (!conversationSnapshot.exists) {
        throw Exception("Conversation not found");
      }

      List<String> participants =
          List<String>.from(conversationSnapshot['participants']);
      participantPhoneNo = participants.firstWhere(
        (phone) => phone != userPhone,
        orElse: () => 'Unknown',
      );

      if (participantPhoneNo != 'Unknown') {
        await fetchParticipantDetails();
      }

      // Fetch all messages
      await fetchAllMessages();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error initializing data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserDetails() async {
    try {
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        Map<String, dynamic> userData =
            userSnapshot.docs.first.data() as Map<String, dynamic>;
        userProfileImageBase64 = userData['profileImageUrl'];
      }
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
        Map<String, dynamic> contactData =
            contactSnapshot.docs.first.data() as Map<String, dynamic>;
        participantName = contactData['name'] ?? participantPhoneNo;
        participantProfileImageBase64 = contactData['profileImageUrl'];
      } else {
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

  Future<void> fetchAllMessages() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      setState(() {
        allMessages = querySnapshot.docs
            .map((doc) => {
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id,
                })
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  void searchMessages(String keyword) {
    setState(() {
      searchText = keyword.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredMessages = allMessages.where((message) {
      final content = (message['content'] ?? '').toString().toLowerCase();
      return content.contains(searchText);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Search Messages",
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
                                      controller: searchController,
                                      decoration: const InputDecoration(
                                        hintText: "Search messages",
                                        border: InputBorder.none,
                                      ),
                                      onChanged: searchMessages,
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

                  // Messages List
                  Expanded(
                    child: filteredMessages.isEmpty
                        ? const Center(child: Text("No messages found"))
                        : ListView.builder(
                            itemCount: filteredMessages.length,
                            itemBuilder: (context, index) {
                              var message = filteredMessages[index];
                              bool isSentByUser =
                                  message['senderID'] == userPhone;
                              String messageId = message['id'];
                              String content =
                                  message['content'] ?? 'No content';
                              Timestamp timestamp =
                                  message['timestamp'] as Timestamp;

                              return ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Chatpage(
                                        conversationID: widget.conversationID,
                                        initialMessageID: messageId,
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
                                subtitle: Text(content),
                                trailing: Text(
                                  timestamp
                                      .toDate()
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0], // Date only
                                ),
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
