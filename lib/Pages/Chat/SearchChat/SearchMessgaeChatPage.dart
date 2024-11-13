import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/Chat/ChatPage.dart';

class SearchMessageChatPage extends StatefulWidget {
  final String conversationID;

  const SearchMessageChatPage({super.key, required this.conversationID});

  @override
  _SearchMessageChatPageState createState() => _SearchMessageChatPageState();
}

class _SearchMessageChatPageState extends State<SearchMessageChatPage> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>>? searchResults;
  List<Map<String, dynamic>> allMessages = [];

  @override
  void initState() {
    super.initState();
    fetchAllMessages(); // Fetch all messages once
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
    if (keyword.isEmpty) {
      setState(() {
        searchResults = null;
      });
      return;
    }

    setState(() {
      searchResults = allMessages.where((message) {
        final content = (message['content'] ?? '').toString().toLowerCase();
        return content.contains(keyword.toLowerCase());
      }).toList();
    });
  }

  void navigateToChatPage(Timestamp timestamp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Chatpage(
          conversationID: widget.conversationID,
          initialTimestamp: timestamp.toDate(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                searchMessages(value);
              },
            ),
          ),
          Expanded(
            child: searchResults == null
                ? const Center(child: Text('Search for messages'))
                : searchResults!.isEmpty
                    ? const Center(child: Text('No messages found'))
                    : ListView.builder(
                        itemCount: searchResults!.length,
                        itemBuilder: (context, index) {
                          var messageData = searchResults![index];
                          var messageContent = messageData['content'] ?? '';
                          var timestamp = messageData['timestamp'] as Timestamp;

                          return ListTile(
                            title: Text(messageContent),
                            onTap: () {
                              navigateToChatPage(timestamp);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
