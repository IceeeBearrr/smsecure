import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddWhitelistPage extends StatefulWidget {
  const AddWhitelistPage({super.key});

  @override
  _AddWhitelistPageState createState() => _AddWhitelistPageState();
}

class _AddWhitelistPageState extends State<AddWhitelistPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  Future<String?> getSmsUserID() async {
    try {
      const FlutterSecureStorage secureStorage = FlutterSecureStorage();
      String? userPhone = await secureStorage.read(key: 'userPhone');
      
      if (userPhone == null) {
        print("Error: userPhone is not set in secure storage.");
        return null;
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final QuerySnapshot querySnapshot = await firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      } else {
        print("Error: No smsUserID found for the given phone number.");
        return null;
      }
    } catch (e) {
      print("Error retrieving smsUserID: $e");
      return null;
    }
  }

  Future<void> _saveWhitelistEntry() async {
    if (_formKey.currentState!.validate()) {
      final firestore = FirebaseFirestore.instance;
      final enteredName = _nameController.text.trim();
      final enteredPhone = _phoneController.text.trim();

      try {
        // Check if the name or phone number already exists in the whitelist
        final nameQuery = await firestore
            .collection('whitelist')
            .where('name', isEqualTo: enteredName)
            .get();

        final phoneQuery = await firestore
            .collection('whitelist')
            .where('phoneNo', isEqualTo: enteredPhone)
            .get();

        if (nameQuery.docs.isNotEmpty || phoneQuery.docs.isNotEmpty) {
          // Show error dialog if duplicates are found
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('A whitelist entry with this name or phone number already exists.'),
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
          return;
        }

        // Retrieve the smsUserID for the current user
        final String? smsUserID = await getSmsUserID();
        if (smsUserID == null) {
          throw Exception('Could not retrieve smsUserID.');
        }

        // Add the new entry to the whitelist
        await firestore.collection('whitelist').add({
          'smsUserID': smsUserID,
          'name': enteredName,
          'phoneNo': enteredPhone,
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Success'),
              content: const Text('Whitelist entry added successfully.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close success dialog
                    Navigator.of(context).pop(true); // Close AddWhitelistPage and return true
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        // Handle any errors
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('An error occurred: $e'),
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
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add to Whitelist',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF113953),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 50),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                      return 'Only letters and spaces are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!RegExp(r'^\+60\d{9,10}$').hasMatch(value)) {
                      return 'Please enter in the format +60123456789';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveWhitelistEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
