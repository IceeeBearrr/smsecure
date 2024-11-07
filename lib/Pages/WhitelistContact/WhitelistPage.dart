import 'package:flutter/material.dart';
import 'WhitelistList.dart'; // Assuming this new widget will load the whitelist contacts
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/WhitelistContact/AddWhitelist.dart';

// Initialize Flutter Secure Storage instance
const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class WhitelistPage extends StatefulWidget {
  const WhitelistPage({super.key});

  @override
  State<WhitelistPage> createState() => _WhitelistPageState();
}

class _WhitelistPageState extends State<WhitelistPage> {
  String? userPhone;
  String? currentSmsUserID;

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    userPhone = await secureStorage.read(key: 'userPhone');
    setState(() {}); // Trigger a rebuild to update the UI with the userPhone if needed

    if (userPhone != null) {
      await _findSmsUserID();
    }
  }

  Future<void> _findSmsUserID() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final QuerySnapshot findSmsUserIDSnapshot = await firestore
        .collection('smsUser')
        .where('phoneNo', isEqualTo: userPhone)
        .limit(1)
        .get();

    if (findSmsUserIDSnapshot.docs.isNotEmpty) {
      currentSmsUserID = findSmsUserIDSnapshot.docs.first.id;
      setState(() {}); // Trigger a rebuild to update the UI with the currentSmsUserID
    }
  }

  Future<void> _navigateToAddContact() async {
    // Navigate to AddWhitelistPage and wait for the result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddWhitelistPage()),
    );

    // If a new contact was added, refresh the whitelist
    if (result == true) {
      _loadUserPhone(); // Call this to refresh the data or any other function that reloads the contacts
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Whitelisted Contacts",
          style: TextStyle(
            color: Color(0xFF113953),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113953)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: TextFormField(
                              decoration: const InputDecoration(
                                hintText: "Search",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Spacing between search bar and add button
                GestureDetector(
                  onTap: _navigateToAddContact,
                  child: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF113953),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: (userPhone != null && currentSmsUserID != null)
                ? WhitelistList(currentUserID: currentSmsUserID!) // Display whitelist contacts
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
