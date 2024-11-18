import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/SMSUser/QuarantineFolder/QuarantineFolderList.dart'; 

// Initialize Flutter Secure Storage instance
const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class QuarantineFolderPage extends StatefulWidget {
  const QuarantineFolderPage({super.key});

  @override
  State<QuarantineFolderPage> createState() => _QuarantineFolderPageState();
}

class _QuarantineFolderPageState extends State<QuarantineFolderPage> {
  String? userPhone;
  String? currentSmsUserID;
  String searchText = ""; // State to store search input

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  Future<void> _loadUserPhone() async {
    userPhone = await secureStorage.read(key: 'userPhone');
    setState(() {});

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
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Quarantine Folder",
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
                                hintText: "Search by name or phone number",
                                border: InputBorder.none,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  searchText = value.trim().toLowerCase(); // Update search text
                                });
                              },
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
          const SizedBox(height: 20),
          Expanded(
            child: (userPhone != null && currentSmsUserID != null)
                ? QuarantineFolderList(
                    currentUserID: currentSmsUserID!,
                    searchText: searchText, // Pass search text
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
