import 'package:flutter/material.dart';
import 'package:smsecure/Pages/WhitelistContact/WhitelistContactList.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/Contact/AddContact.dart';

// Initialize Flutter Secure Storage instance
const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class WhitelistContactPage extends StatefulWidget {
  const WhitelistContactPage({super.key});

  @override
  State<WhitelistContactPage> createState() => _WhitelistContactPageState();
}

class _WhitelistContactPageState extends State<WhitelistContactPage> {
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
    // Navigate to AddContactPage and wait for the result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddContactPage()),
    );

    // If a new contact was added, refresh the contact list
    if (result == true) {
      _loadUserPhone(); // Call this to refresh the data or any other function that reloads the contacts
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 25, right: 260, bottom: 25),
            child: Text(
              "Contacts",
              style: TextStyle(
                color: Color(0xFF113953),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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

          const SizedBox(height: 10),
          Expanded(
            child: (userPhone != null && currentSmsUserID != null)
                ? WhitelistContactList(currentUserID: currentSmsUserID!)
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
