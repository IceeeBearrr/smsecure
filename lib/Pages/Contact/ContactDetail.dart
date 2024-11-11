import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/Chat/ChatPage.dart';
import 'package:smsecure/Pages/Contact/EditContactDetail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ContactDetailsPage extends StatelessWidget {
  final String contactId;
  final storage = const FlutterSecureStorage();

  const ContactDetailsPage({super.key, required this.contactId});

  Future<Map<String, dynamic>> _fetchContactDetails() async {
    final firestore = FirebaseFirestore.instance;
    final contactSnapshot = await firestore.collection('contact').doc(contactId).get();
    String? userPhone = await storage.read(key: "userPhone");
    String? smsUserID;

    final QuerySnapshot findSmsUserIDSnapshot = await firestore
      .collection('smsUser')
      .where('phoneNo', isEqualTo: userPhone)
      .limit(1)
      .get();

    if (findSmsUserIDSnapshot.docs.isNotEmpty) {
      smsUserID = findSmsUserIDSnapshot.docs.first.id;
    }
      
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
        'smsUserID': smsUserID,  
      };
    } else {
      return {
        'name': 'No Name',
        'phoneNo': 'No Number',
        'note': 'No note',
        'profileImageUrl': null,
        'smsUserID': smsUserID,  
      };
    }
  }
  

  Future<void> _addToWhitelist(BuildContext context, Map<String, dynamic> contactData) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Check if phone number already exists in the whitelist for the current user
      final existingWhitelistQuery = await firestore
          .collection('whitelist')
          .where('phoneNo', isEqualTo: contactData['phoneNo'])
          .where('smsUserID', isEqualTo: contactData['smsUserID'])
          .get();

      if (existingWhitelistQuery.docs.isNotEmpty) {
        // If phone number already exists, show error message
        _showMessageDialog(context, "Error", "This contact is already in your whitelist.");
        return;
      }

      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: Text('Are you sure you want to add "${contactData['name']}" to the whitelist?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return; // If not confirmed, exit the function

      // Add contact to the whitelist
      await firestore.collection('whitelist').add({
        'name': contactData['name'],
        'phoneNo': contactData['phoneNo'],
        'smsUserID': contactData['smsUserID'],
      });

      // Show success dialog
      if (!context.mounted) {
        print("Context is no longer mounted; cannot show success dialog.");
        return;
      }

      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Contact added to whitelist successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error in _addToWhitelist: $e");

      // Show error message
      if (context.mounted) {
        _showMessageDialog(context, "Error", "Error adding to whitelist: $e");
      }
    }
  }




  void _showMessageDialog(BuildContext context, String title, String message) {
    showDialog(
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
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToBlacklist(BuildContext context, String contactId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Fetch contact details
      final contactDoc = await firestore.collection('contact').doc(contactId).get();
      if (!contactDoc.exists) {
        _showMessageDialog(context, "Error", "Contact not found.");
        return;
      }

      final contactData = contactDoc.data();
      final name = contactData?['name'];
      final phoneNo = contactData?['phoneNo'];
      final smsUserID = contactData?['smsUserID'];

      if (name == null || phoneNo == null || smsUserID == null) {
        _showMessageDialog(context, "Error", "Failed to retrieve contact details.");
        return;
      }

      // Check if contact is already in the blacklist
      final existingBlacklist = await firestore
          .collection('blacklist')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('phoneNo', isEqualTo: phoneNo)
          .get();

      if (existingBlacklist.docs.isNotEmpty) {
        _showMessageDialog(context, "Error", "This contact is already in the blacklist.");
        return;
      }

      // Check if contact exists in the whitelist
      final existingWhitelist = await firestore
          .collection('whitelist')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('phoneNo', isEqualTo: phoneNo)
          .get();

      bool contactExistsInWhitelist = existingWhitelist.docs.isNotEmpty;

      // Show appropriate confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: Text(contactExistsInWhitelist
                ? 'The selected contact "$name" is already in the whitelist. By blacklisting this contact, it will also be removed from the whitelist. Do you want to continue?'
                : 'Are you sure you want to blacklist "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Blacklist'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      // Add to blacklist
      await firestore.collection('blacklist').add({
        'name': name,
        'phoneNo': phoneNo,
        'smsUserID': smsUserID,
        'blacklistedFrom': 'Contact', // New field
        'blacklistedDateTime': Timestamp.now(), // New field
      });

      // Update isBlacklisted field in the contact collection
      await firestore.collection('contact').doc(contactId).update({
        'isBlacklisted': true,
      });

      // Remove from whitelist if it exists
      if (contactExistsInWhitelist) {
        for (var doc in existingWhitelist.docs) {
          await firestore.collection('whitelist').doc(doc.id).delete();
        }
      }

      // Check for existing conversations and update their isBlacklisted field
      final existingConversations = await firestore
          .collection('conversations')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('participants', arrayContains: phoneNo)
          .get();

      for (var conversation in existingConversations.docs) {
        await firestore
            .collection('conversations')
            .doc(conversation.id)
            .update({'isBlacklisted': true});
      }

      // Show success dialog
      if (context.mounted) {
        _showMessageDialog(context, "Success", "Contact successfully added to the blacklist.");
      }
    } catch (e) {
      if (context.mounted) {
        _showMessageDialog(context, "Error", "Error adding to blacklist: $e");
      }
    }
  }



  Future<void> _sendMessage(BuildContext context, String receiverPhone) async {
    final firestore = FirebaseFirestore.instance;
    final userPhone = await storage.read(key: "userPhone");

    if (userPhone == null) {
      // Handle error if userPhone is not available
      print("User phone not found in secure storage.");
      return;
    }

    // Check for an existing conversation
    QuerySnapshot conversationSnapshot = await firestore
        .collection('conversations')
        .where('participants', arrayContainsAny: [userPhone])
        .get();

    String? conversationID;
    for (var doc in conversationSnapshot.docs) {
      List<dynamic> participants = doc['participants'];
      if (participants.contains(receiverPhone) && participants.contains(userPhone)) {
        conversationID = doc.id;
        break;
      }
    }

    if (conversationID == null) {
      // No conversation found, create a new one
      DocumentReference newConversation = await firestore.collection('conversations').add({
        'participants': [userPhone, receiverPhone],
      });
      conversationID = newConversation.id;
    }

    // Navigate to ChatPage with the conversationID
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Chatpage(conversationID: conversationID!),
      ),
    );
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
          icon: const Icon(Icons.arrow_back),
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
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      data['name'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF113953),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
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
                                const Spacer(),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    width: double.infinity,
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
                          _sendMessage(context, data['phoneNo']);
                        }),
                        _buildProfileOption(Icons.person_add, 'Add to Whitelist', onTap: () {
                          _addToWhitelist(context, data);
                        }),
                        _buildProfileOption(Icons.edit, 'Edit Contact', onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditContactPage(contactId: contactId),
                            ),
                          );
                        }),
                        _buildProfileOption(
                          Icons.delete,
                          'Delete Contact',
                          color: Colors.red,
                          onTap: () {
                            _deleteContact(context);
                          },
                        ),
                        _buildProfileOption(
                          Icons.block,
                          'Blacklist Contact',
                          color: Colors.red,
                          onTap: () {
                            _addToBlacklist(context, contactId);
                          },
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
    );
  }

  Future<void> _deleteContact(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: const Text('Are you sure you want to delete this contact?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return; // If not confirmed, exit function

      // Delete contact
      await firestore.collection('contact').doc(contactId).delete();
      print("Contact successfully deleted");

      // Show success dialog
      if (!context.mounted) {
        print("Context is no longer mounted; cannot show success dialog.");
        return;
      }

      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Contact deleted successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  Navigator.of(context).pop(); // Navigate back to the previous screen
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error in _deleteContact: $e");

      // Show error message
      if (context.mounted) {
        _showMessageDialog(context, "Error", "Error deleting contact: $e");
      }
    }
  }


  Widget _buildProfileOption(IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 20.0),
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
