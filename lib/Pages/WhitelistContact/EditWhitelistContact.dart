import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/WhitelistContact/WhitelistDetail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EditWhitelistPage extends StatefulWidget {
  final String whitelistId;

  const EditWhitelistPage({Key? key, required this.whitelistId}) : super(key: key);

  @override
  _EditWhitelistPageState createState() => _EditWhitelistPageState();
}

class _EditWhitelistPageState extends State<EditWhitelistPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _profileImageBase64;
  String? userPhone;
  String? currentSmsUserID;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _fetchWhitelistDetails();
  }

  Future<void> _fetchWhitelistDetails() async {
    final firestore = FirebaseFirestore.instance;
    final whitelistSnapshot = await firestore.collection('whitelist').doc(widget.whitelistId).get();

    if (whitelistSnapshot.exists) {
      final whitelistData = whitelistSnapshot.data()!;
      final phoneNo = whitelistData['phoneNo'];
      final name = whitelistData['name'] ?? phoneNo;

      // Fetch contact details by phoneNo
      final contactSnapshot = await firestore
          .collection('contact')
          .where('phoneNo', isEqualTo: phoneNo)
          .limit(1)
          .get();

      String? profileImageUrl;
      if (contactSnapshot.docs.isNotEmpty) {
        final contactData = contactSnapshot.docs.first.data();
        profileImageUrl = contactData['profileImageUrl'];

        // If no profileImageUrl in contact, check registeredSMSUserID in smsUser collection
        if (profileImageUrl == null || profileImageUrl.isEmpty) {
          final registeredSMSUserID = contactData['registeredSMSUserID'];
          if (registeredSMSUserID != null && registeredSMSUserID.isNotEmpty) {
            final smsUserDoc = await firestore.collection('smsUser').doc(registeredSMSUserID).get();
            if (smsUserDoc.exists) {
              profileImageUrl = smsUserDoc.data()?['profileImageUrl'];
            }
          }
        }
      }

      setState(() {
        _nameController.text = name;
        _phoneController.text = phoneNo;
        _profileImageBase64 = profileImageUrl;
      });
    }
  }

  Future<void> _saveWhitelistDetails() async {
    if (_formKey.currentState!.validate()) {
      final firestore = FirebaseFirestore.instance;
      final newPhoneNo = _phoneController.text.trim();
      final newName = _nameController.text.trim();

      try {
        // Check for duplicates in the whitelist collection
        final QuerySnapshot phoneQuery = await firestore
            .collection('whitelist')
            .where('phoneNo', isEqualTo: newPhoneNo)
            .get();

        final QuerySnapshot nameQuery = await firestore
            .collection('whitelist')
            .where('name', isEqualTo: newName)
            .get();

        final bool phoneExists = phoneQuery.docs.isNotEmpty && phoneQuery.docs.first.id != widget.whitelistId;
        final bool nameExists = nameQuery.docs.isNotEmpty && nameQuery.docs.first.id != widget.whitelistId;

        if (phoneExists || nameExists) {
          // Show error dialog if duplicates are found
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text(
                    'A whitelist entry with this name or phone number already exists.'),
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

        // Update the whitelist entry
        await firestore.collection('whitelist').doc(widget.whitelistId).update({
          'name': newName,
          'phoneNo': newPhoneNo,
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Success'),
              content: const Text('Whitelist contact updated successfully.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) =>
                            WhitelistDetailsPage(whitelistId: widget.whitelistId),
                      ),
                      (Route<dynamic> route) => route.isFirst,
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        // Handle errors
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
    final profileImage = _profileImageBase64 != null && _profileImageBase64!.isNotEmpty
        ? MemoryImage(base64Decode(_profileImageBase64!)!)
        : _profileImageBase64 != null
            ? MemoryImage(base64Decode(_profileImageBase64!))
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Whitelist Contact',
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
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: profileImage as ImageProvider<Object>?,
                  child: profileImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the contact name';
                    } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                      return 'Only letters and spaces are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveWhitelistDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
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
