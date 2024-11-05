import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // For decoding Base64
import 'package:smsecure/Pages/Contact/ContactDetail.dart';

class ContactList extends StatelessWidget {
  final String currentUserID;

  const ContactList({super.key, required this.currentUserID});

  Future<String?> _getProfileImageUrl(String contactId, String? registeredSMSUserID) async {
    final contactDoc = await FirebaseFirestore.instance.collection('contact').doc(contactId).get();

    // Step 1: Check if contact has profileImageUrl
    if (contactDoc.exists) {
      final contactData = contactDoc.data();
      final profileImageUrl = contactData?['profileImageUrl'];

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        return profileImageUrl;
      }

      // Step 2: Check if registeredSMSUserID is provided and has a value
      final smsUserId = contactData?['registeredSMSUserID'] ?? registeredSMSUserID;
      if (smsUserId != null && smsUserId.isNotEmpty) {
        // Fetch the corresponding smsUser document
        final smsUserDoc = await FirebaseFirestore.instance.collection('smsUser').doc(smsUserId).get();
        if (smsUserDoc.exists) {
          final smsUserData = smsUserDoc.data();
          final smsProfileImageUrl = smsUserData?['profileImageUrl'];
          if (smsProfileImageUrl != null && smsProfileImageUrl.isNotEmpty) {
            return smsProfileImageUrl;
          }
        }
      }
    }
    return null;
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
            .collection('contact')
            .where('smsUserID', isEqualTo: currentUserID)
            .orderBy('name') // Sort by name alphabetically
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No contacts available"));
          }

          var contacts = snapshot.data!.docs;

          return Scrollbar(
            thumbVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(8),
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                var contact = contacts[index];
                var contactName = contact['name'] ?? 'No Name';
                var contactPhone = contact['phoneNo'] ?? 'No Number';
                var contactId = contact.id;
                var registeredSMSUserID = contact['registeredSMSUserID'];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: GestureDetector(
                    onLongPress: () {
                      _showContactOptions(context, contactName, contactId);
                    },
                    child: FutureBuilder<String?>(
                      future: _getProfileImageUrl(contactId, registeredSMSUserID),
                      builder: (context, snapshot) {
                        final profileImage = snapshot.hasData && snapshot.data!.isNotEmpty
                            ? MemoryImage(base64Decode(snapshot.data!))
                            : AssetImage("images/HomePage/defaultProfile.png") as ImageProvider;

                        return SizedBox(
                          height: 65,
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(33),
                                child: Image(
                                  image: profileImage,
                                  height: 65,
                                  width: 65,
                                  fit: BoxFit.cover,
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
                                        contactName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Color(0xFF113953),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        contactPhone,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showContactOptions(BuildContext context, String contactName, String contactId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  contactName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContactDetailsPage(contactId: contactId),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('Add to Whitelist'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement Add to Whitelist action
                },
              ),
              ListTile(
                title: const Text(
                  'Blacklist Contact',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Implement Blacklist Contact action
                },
              ),
              ListTile(
                title: const Text(
                  'Delete Contact',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteContact(contactId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteContact(String contactId) {
    FirebaseFirestore.instance.collection('contact').doc(contactId).delete();
    // Handle any additional logic for deleting the contact
  }
}
