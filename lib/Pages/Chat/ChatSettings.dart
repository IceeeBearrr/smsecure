import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/Chat/SearchChat/SearchMessgaeChatPage.dart';

class ChatSettingsPage extends StatefulWidget {
  final String conversationID;

  const ChatSettingsPage({Key? key, required this.conversationID})
      : super(key: key);

  @override
  _ChatSettingsPageState createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  final storage = const FlutterSecureStorage();
  String? participantPhoneNo;
  String? participantName;
  String? profileImageBase64;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchParticipantDetails();
  }

  Future<void> fetchParticipantDetails() async {
    try {
      // Step 1: Retrieve the current user's phone number from SecureStorage
      String? currentUserPhone = await storage.read(key: "userPhone");
      if (currentUserPhone == null) throw Exception("User phone not found");

      // Step 2: Retrieve the conversation from Firestore
      DocumentSnapshot conversationSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .get();

      if (!conversationSnapshot.exists)
        throw Exception("Conversation not found");

      // Step 3: Get the participant's phone number
      var participants =
          List<String>.from(conversationSnapshot['participants']);
      participantPhoneNo = participants.firstWhere(
        (phone) => phone != currentUserPhone,
        orElse: () => 'Unknown',
      );

      if (participantPhoneNo == 'Unknown')
        throw Exception("Participant not found");

      // Step 4: Retrieve participant details from the 'contact' collection
      QuerySnapshot contactSnapshot = await FirebaseFirestore.instance
          .collection('contact')
          .where('phoneNo', isEqualTo: participantPhoneNo)
          .get();

      if (contactSnapshot.docs.isNotEmpty) {
        // If contact exists
        Map<String, dynamic> contactData =
            contactSnapshot.docs.first.data() as Map<String, dynamic>;
        participantName = contactData['name'] ?? participantPhoneNo;
        String? contactProfileImage = contactData['profileImageUrl'];

        if (contactProfileImage != null && contactProfileImage.isNotEmpty) {
          profileImageBase64 = contactProfileImage;
        } else {
          // Check smsUser collection for profileImageUrl
          await fetchSmsUserDetails();
        }
      } else {
        // If contact does not exist, check smsUser collection for participantPhoneNo
        await fetchSmsUserDetails();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching participant details: $e");
      setState(() {
        isLoading = false;
        participantName = "Unknown";
        profileImageBase64 = null;
      });
    }
  }

  Future<void> fetchSmsUserDetails() async {
    try {
      DocumentSnapshot smsUserSnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .doc(participantPhoneNo)
          .get();

      if (smsUserSnapshot.exists) {
        Map<String, dynamic> smsUserData =
            smsUserSnapshot.data() as Map<String, dynamic>;
        participantName = smsUserData['name'] ?? participantPhoneNo;
        String? smsUserProfileImage = smsUserData['profileImageUrl'];

        if (smsUserProfileImage != null && smsUserProfileImage.isNotEmpty) {
          profileImageBase64 = smsUserProfileImage;
        }
      }
    } catch (e) {
      debugPrint("Error fetching smsUser details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Settings'),
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
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Profile Picture and Info
                          Column(
                            children: [
                              profileImageBase64 != null
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundImage: MemoryImage(
                                        base64Decode(profileImageBase64!),
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                              const SizedBox(height: 10),
                              Text(
                                participantName ?? "Unknown",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                participantPhoneNo ?? "Unknown",
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Menu Options
                          ListTile(
                            title: const Text('Search Messages'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SearchMessageChatPage(
                                    conversationID: widget.conversationID,
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            title: const Text('Pinned Messages'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              // Navigate to Pinned Messages Page
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions Section at the Bottom
                  Column(
                    children: [
                      SettingsTile(
                        title: 'Blacklist',
                        onTap: () {
                          // Blacklist User Logic
                        },
                        textColor: Colors.red,
                      ),
                      const SizedBox(height: 2),
                      SettingsTile(
                        title: 'Delete Conversations',
                        onTap: () {
                          // Delete Conversations Logic
                        },
                        textColor: Colors.red,
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const SettingsTile({
    required this.title,
    required this.onTap,
    this.textColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
