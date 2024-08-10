import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Chat/ChatPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Recentchats extends StatelessWidget {
  const Recentchats({super.key});

  String formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('d MMM').format(date);
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
            .where('lastMessageTimeStamp', isGreaterThanOrEqualTo: DateTime(2024))
            .orderBy('lastMessageTimeStamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var conversations = snapshot.data!.docs;

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              var conversation = conversations[index];
              var receiverID = conversation['receiverID'] ?? 'Unknown';
              var lastMessageTimeStamp = conversation['lastMessageTimeStamp'];
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
                                  receiverID,
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
                                    if (!messageSnapshot.hasData ||
                                        messageSnapshot.data!.docs.isEmpty) {
                                      return const Text(
                                        "No messages yet...",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black54,
                                        ),
                                      );
                                    }
                                    var latestMessage =
                                        messageSnapshot.data!.docs.first;
                                    var messageContent =
                                        latestMessage.get('content') ?? '';
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
          );
        },
      ),
    );
  }
}
