import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/SMSUser/Chat/SearchChat/SearchMessgaeChatPage.dart';
import 'package:smsecure/Pages/SMSUser/Chat/Bookmark/MessageBookmark.dart';

class ChatSettingsPage extends StatefulWidget {
  final String conversationID;

  const ChatSettingsPage({super.key, required this.conversationID});

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

      if (!conversationSnapshot.exists) {
        throw Exception("Conversation not found");
      }

      // Step 3: Get the participant's phone number
      var participants =
          List<String>.from(conversationSnapshot['participants']);
      participantPhoneNo = participants.firstWhere(
        (phone) => phone != currentUserPhone,
        orElse: () => 'Unknown',
      );

      if (participantPhoneNo == 'Unknown') {
        throw Exception("Participant not found");
      }

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

  Future<void> confirmBlacklist(BuildContext context) async {
    final bool? confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Are you sure you want to blacklist this participant?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Cancel action
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Confirm action
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      blacklistParticipant(); // Execute blacklist logic if confirmed
    }
  }

  Future<void> blacklistParticipant() async {
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
        'name': participantName,
        'phoneNo': participantPhoneNo,
        'smsUserID': smsUserID,
      });

      // Update contact collection
      QuerySnapshot contactQuery = await FirebaseFirestore.instance
          .collection('contact')
          .where('phoneNo', isEqualTo: participantPhoneNo)
          .where('smsUserID', isEqualTo: smsUserID)
          .get();

      for (var doc in contactQuery.docs) {
        await doc.reference.update({'isBlacklisted': true});
      }

      // Update conversations collection
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .update({'isBlacklisted': true});

      // Show success message
      _showSuccessDialog(
        context,
        "Blacklist Success",
        "The participant has been successfully blacklisted.",
      );
    } catch (e) {
      debugPrint("Error blacklisting participant: $e");
      _showErrorDialog(
        context,
        "Blacklist Error",
        "Failed to blacklist participant. Please try again.",
      );
    }
  }

  Future<void> confirmDeleteConversation(BuildContext context) async {
    final bool? confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Cancel action
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Confirm action
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      deleteConversation(); // Execute delete logic if confirmed
    }
  }

  Future<void> deleteConversation() async {
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

      // Delete messages sub-collection
      QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationID)
          .collection('messages')
          .get();

      for (var messageDoc in messagesSnapshot.docs) {
        QuerySnapshot translatedMessagesSnapshot = await messageDoc.reference
            .collection('translatedMessage')
            .get();

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
          .doc(widget.conversationID)
          .delete();

      // Delete bookmarks where conversationID and smsUserID match
      QuerySnapshot bookmarksSnapshot = await FirebaseFirestore.instance
          .collection('bookmarks')
          .where('conversationID', isEqualTo: widget.conversationID)
          .where('smsUserID', isEqualTo: smsUserID)
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


  void _showSuccessDialog(
      BuildContext context, String title, String message) {
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
              Navigator.of(context).popUntil((route) => route.isFirst); // Pop back to Messages
            },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Chat Settings",
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MessageBookmark(
                                    conversationId: widget.conversationID,
                                  ),
                                ),
                              );
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
                        onTap: () => confirmBlacklist(context),
                        textColor: Colors.red,
                      ),
                      const SizedBox(height: 2),
                      SettingsTile(
                        title: 'Delete Conversations',
                        onTap: () => confirmDeleteConversation(context),
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
    super.key,
  });

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
