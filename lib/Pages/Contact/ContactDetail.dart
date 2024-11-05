import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/Contact/EditContactDetail.dart';

class ContactDetailsPage extends StatelessWidget {
  final String contactId;

  const ContactDetailsPage({Key? key, required this.contactId}) : super(key: key);

  Future<Map<String, dynamic>> _fetchContactDetails() async {
    final firestore = FirebaseFirestore.instance;
    final contactSnapshot = await firestore.collection('contact').doc(contactId).get();
    if (contactSnapshot.exists) {
      final contactData = contactSnapshot.data()!;
      String? profileImageUrl;

      // Step 1: Check if the contact document has a profileImageUrl
      if (contactData['profileImageUrl'] != null && contactData['profileImageUrl'].isNotEmpty) {
        profileImageUrl = contactData['profileImageUrl'];
      } else if (contactData['registeredSMSUserID'] != null && contactData['registeredSMSUserID'].isNotEmpty) {
        // Step 2: If no profileImageUrl in contact, check for registeredSMSUserID and fetch the corresponding smsUser document
        final smsUserId = contactData['registeredSMSUserID'];
        final smsUserSnapshot = await firestore.collection('smsUser').doc(smsUserId).get();
        if (smsUserSnapshot.exists) {
          profileImageUrl = smsUserSnapshot.data()?['profileImageUrl'];
        }
      }

      // Retrieve other fields from contact document
      String name = contactData['name'] ?? 'No Name';
      String phoneNo = contactData['phoneNo'] ?? 'No Number';
      String note = contactData['note'] ?? 'No note';

      return {
        'name': name,
        'phoneNo': phoneNo,
        'note': note,
        'profileImageUrl': profileImageUrl,
      };
    } else {
      return {
        'name': 'No Name',
        'phoneNo': 'No Number',
        'note': 'No note',
        'profileImageUrl': null,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact',
          style: TextStyle(
            fontSize: 22,              
            fontWeight: FontWeight.bold,
            color: Color(0xFF113953),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchContactDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error fetching contact details"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No contact details available"));
          }

          final data = snapshot.data!;
          final profileImage = data['profileImageUrl'] != null && data['profileImageUrl'].isNotEmpty
              ? MemoryImage(base64Decode(data['profileImageUrl']))
              : null;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 20),
                    // Profile Picture
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 15),
                    // Contact Name
                    Text(
                      data['name'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF113953),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Outer Container for Mobile and Notes Sections
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          // Phone Number Section
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Mobile',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Spacer(),
                                Text(
                                  data['phoneNo'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Notes Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notes',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  data['note'],
                                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
                // Options Container at the Bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 20), // Add bottom padding for spacing
                  child: Container(
                    width: double.infinity, // Full-width container
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                    child: Column(
                      children: [
                        _buildProfileOption(Icons.message, 'Send Message', onTap: () {
                          // Implement Send Message action
                        }),
                        _buildProfileOption(Icons.person_add, 'Add to Whitelist', onTap: () {
                          // Implement Add to Whitelist action
                        }),
                        _buildProfileOption(Icons.edit, 'Edit Contact', onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditContactPage(contactId: contactId),
                            ),
                          );
                        }),
                        _buildProfileOption(Icons.delete, 'Delete Contact', color: Colors.red, onTap: () {
                          // Implement Delete Contact action
                        }),
                        _buildProfileOption(Icons.block, 'Blacklist Contact', color: Colors.red, onTap: () {
                          // Implement Blacklist Contact action
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 20.0), // Add horizontal padding here
        child: Row(
          children: [
            Icon(icon, color: color ?? const Color.fromARGB(255, 47, 77, 129)),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: color ?? const Color.fromARGB(188, 0, 0, 0),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
