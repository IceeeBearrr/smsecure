import 'package:flutter/material.dart';
import 'package:smsecure/Pages/SMSUser/Messages/Widget/RecentChats.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Initialize Flutter Secure Storage instance
const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class Messages extends StatefulWidget {
  const Messages({super.key});

  @override
  State<Messages> createState() => _MessagesState();
}

class _MessagesState extends State<Messages> {
  String? userPhone;
  String searchText = ""; // State for search input

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    userPhone = await secureStorage.read(key: 'userPhone');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 25, right: 240, bottom: 25),
              child: Text(
                "Messages",
                style: TextStyle(
                  color: Color(0xFF113953),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
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
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            hintText: "Search by name or phone number",
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchText = value
                                  .trim()
                                  .toLowerCase(); // Update search input
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: userPhone != null
                  ? Recentchats(
                      currentUserID: userPhone!,
                      searchText: searchText, // Pass search text
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
