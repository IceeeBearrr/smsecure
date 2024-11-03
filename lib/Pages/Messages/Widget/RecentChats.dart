import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Chat/ChatPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Recentchats extends StatelessWidget {
  final String currentUserID; // Set this to the current user's phone number

  const Recentchats({super.key, required this.currentUserID});

  String formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    DateTime yesterday = now.subtract(const Duration(days: 1));

    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now)) {
      return DateFormat('HH:mm').format(date); // Shows time if the conversation is from today
    } else if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(yesterday)) {
      return 'Yesterday'; // Shows 'Yesterday' if the conversation is from the day before
    } else {
      return DateFormat('d MMM').format(date); // Shows the date for older conversations
    }
  }

  @override
  Widget build(BuildContext context) {
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

          if (!snapshot.hasData) {
            print("No data received from Firestore.");
            return const Center(child: Text("No conversations available"));
          }

          var conversations = snapshot.data!.docs;

          if (conversations.isEmpty) {
            print("Query returned no documents.");
            return const Center(
              child: Text("No conversations available"),
            );
          }

          print("Conversations found: ${conversations.length}");

          return Expanded( // Make this scrollable
            child: Scrollbar( // Add Scrollbar here
              thumbVisibility: true, // Make scrollbar thumb always visible
              thickness: 8.0, // Customize the thickness if needed
              radius: const Radius.circular(8), // Rounded edges for scrollbar
              child: ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  var conversation = conversations[index];
                  var participants = List<String>.from(conversation['participants'] ?? []);
                  var otherUserID = participants.firstWhere((id) => id != currentUserID, orElse: () => 'Unknown');
                  var lastMessageTimeStamp = conversation['lastMessageTimeStamp'] as Timestamp?;
                  var formattedDate = lastMessageTimeStamp != null
                      ? formatDate(lastMessageTimeStamp)
                      : 'Unknown';

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
                              child: Image.asset(
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
                                      otherUserID, // Show other user's ID
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF113953),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
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
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black54,
                                            ),
                                          );
                                        }
                                        var latestMessage = messageSnapshot.data!.docs.first;
                                        var messageContent = latestMessage.get('content') ?? '';
                                        return Text(
                                          messageContent,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54,
                                          ),
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
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
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
          );
        },
      ),
    );
  }
}
