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
  String searchText = ""; // State to store search input
  bool dontShowAgain = false; // Tracks the "Don't show again" option

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

      // Check if the dialog should be shown
      final dontShowDialog =
          await secureStorage.read(key: 'dontShowImportDialog') ?? 'false';

      if (dontShowDialog == 'false') {
        _showImportContactsDialog();
      }
    }
  }

  Future<void> _showImportContactsDialog() async {
    bool? userChoice = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text("Import Contacts"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Do you want to import all contacts to the whitelist?",
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: dontShowAgain,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            dontShowAgain = value ?? false;
                          });
                        },
                      ),
                      const Text("Don't show again"),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Save "Don't show again" preference if ticked
                    if (dontShowAgain) {
                      await secureStorage.write(
                          key: 'dontShowImportDialog', value: 'true');
                    }
                    Navigator.of(context).pop(false); // User clicked "No"
                  },
                  child: const Text("No"),
                ),
                TextButton(
                  onPressed: () async {
                    // Save "Don't show again" preference if ticked
                    if (dontShowAgain) {
                      await secureStorage.write(
                          key: 'dontShowImportDialog', value: 'true');
                    }
                    Navigator.of(context).pop(true); // User clicked "Yes"
                  },
                  child: const Text("Yes"),
                ),
              ],
            );
          },
        );
      },
    );

    if (userChoice == true) {
      await _importAllContacts();
    }
  }

  Future<void> _importAllContacts() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      final QuerySnapshot contactSnapshot = await firestore
          .collection('contact')
          .where('smsUserID', isEqualTo: currentSmsUserID)
          .get();

      WriteBatch batch = firestore.batch();

      for (var doc in contactSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> whitelistEntry = {
          'name': data['name'],
          'phoneNo': data['phoneNo'],
          'smsUserID': currentSmsUserID,
        };

        final whitelistRef = firestore.collection('whitelist').doc();
        batch.set(whitelistRef, whitelistEntry);
      }

      await batch.commit();

      _showMessageDialog(
        context,
        "Success",
        "All contacts have been successfully imported to the whitelist.",
      );
    } catch (e) {
      _showMessageDialog(
        context,
        "Error",
        "Failed to import contacts: $e",
      );
    }
  }

  Future<void> _showMessageDialog(
      BuildContext context, String title, String message) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToAddContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddWhitelistPage()),
    );

    if (result == true) {
      _loadUserPhone();
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
                                hintText: "Search by name or phone number",
                                border: InputBorder.none,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  searchText = value
                                      .trim()
                                      .toLowerCase(); // Update search text
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                ? WhitelistList(
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
