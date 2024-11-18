import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/SMSUser/QuarantineFolder/Chat/QuarantineChat.dart';

class QuarantineChatPage extends StatefulWidget {
  final String quarantineId;

  const QuarantineChatPage({super.key, required this.quarantineId});

  @override
  _QuarantineChatPageState createState() => _QuarantineChatPageState();
}

class _QuarantineChatPageState extends State<QuarantineChatPage> {
  final storage = const FlutterSecureStorage();
  String? participantName;
  String? profileImageBase64;
  bool isLoading = true;
  String? userPhone;
  String? conversationID;

  @override
  void initState() {
    super.initState();
    findConversationID();
  }

  Future<void> findConversationID() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Get the current user's phone number from secure storage
      userPhone = await storage.read(key: "userPhone");
      if (userPhone == null || userPhone!.isEmpty) {
        throw Exception("User phone not found or empty in secure storage.");
      }
      print("User Phone : $userPhone");

      // Get the spam contact's phone number using the quarantineId
      DocumentSnapshot spamContactSnapshot = await firestore
          .collection('spamContact')
          .doc(widget.quarantineId)
          .get();
      if (!spamContactSnapshot.exists) {
        throw Exception("Spam contact not found for the given quarantineId.");
      }

      final spamContactPhoneNo = spamContactSnapshot.get('phoneNo') as String;
      print("Spam Phone : $spamContactPhoneNo");

      // Generate conversationID
      final participants = [userPhone, spamContactPhoneNo];
      participants.sort();
      final generatedConversationID = participants.join('_');
      print("Generated conversationID: $generatedConversationID ");

      // Directly access the document by ID
      DocumentSnapshot conversationSnapshot = await firestore
          .collection('conversations')
          .doc(generatedConversationID)
          .get();

      if (conversationSnapshot.exists) {
        setState(() {
          conversationID = generatedConversationID;
        });
        print("Conversation found with ID: $conversationID");
      } else {
        throw Exception("Conversation not found for the given IDs.");
      }

      // Fetch participant details
      _loadParticipantDetails(spamContactPhoneNo);
    } catch (e) {
      debugPrint("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadParticipantDetails(String spamContactPhoneNo) async {
    final firestore = FirebaseFirestore.instance;

    // Fetch participant's details from Firestore
    final contactSnapshot = await firestore
        .collection('contact')
        .where('phoneNo', isEqualTo: spamContactPhoneNo)
        .get();

    if (contactSnapshot.docs.isNotEmpty) {
      var contactData = contactSnapshot.docs.first.data();
      String? name = contactData['name'];
      String? profileImageUrl = contactData['profileImageUrl'];

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        setState(() {
          participantName = name;
          profileImageBase64 = profileImageUrl;
          isLoading = false;
        });
      } else {
        setState(() {
          participantName = name ?? spamContactPhoneNo;
          profileImageBase64 = null;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        participantName =
            spamContactPhoneNo; // Default to phone number if name is unavailable
        profileImageBase64 = null;
        isLoading = false;
      });
    }
  }

  Future<String?> _getSmsUserID(String userPhone) async {
    final firestore = FirebaseFirestore.instance;

    // Get the smsUserID for the current user
    final smsUserSnapshot = await firestore
        .collection('smsUser')
        .where('phoneNo', isEqualTo: userPhone)
        .limit(1)
        .get();

    if (smsUserSnapshot.docs.isNotEmpty) {
      return smsUserSnapshot.docs.first.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: AppBar(
            leadingWidth: 30,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : profileImageBase64 != null
                          ? Image.memory(
                              base64Decode(profileImageBase64!),
                              height: 45,
                              width: 45,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              "images/HomePage/defaultProfile.png",
                              height: 45,
                              width: 45,
                            ),
                ),
                const SizedBox(width: 10),
                Text(
                  isLoading ? "Loading..." : participantName ?? "Unknown",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF113953),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: conversationID == null
          ? Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("No conversation found."),
            )
          : Column(
              children: [
                Expanded(
                  child: QuarantineChat(conversationID: conversationID!),
                ),
                const SizedBox(height: 30.0),
              ],
            ),
    );
  }
}
