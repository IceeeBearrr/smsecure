import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BlacklistDetailsPage extends StatelessWidget {
  final String blacklistId;
  final storage = FlutterSecureStorage();

  BlacklistDetailsPage({Key? key, required this.blacklistId}) : super(key: key);

  Future<Map<String, dynamic>> _fetchBlacklistDetails() async {
    final firestore = FirebaseFirestore.instance;
    final blacklistSnapshot = await firestore.collection('blacklist').doc(blacklistId).get();
    
    if (blacklistSnapshot.exists) {
      final blacklistData = blacklistSnapshot.data()!;
      final phoneNo = blacklistData['phoneNo'];
      final name = blacklistData['name'] ?? phoneNo;
      String? profileImageUrl;

      // Attempt to retrieve profile image from contact collection
      final contactSnapshot = await firestore
          .collection('contact')
          .where('phoneNo', isEqualTo: phoneNo)
          .limit(1)
          .get();

      if (contactSnapshot.docs.isNotEmpty) {
        final contactData = contactSnapshot.docs.first.data();
        profileImageUrl = contactData['profileImageUrl'];
        
        // If no profileImageUrl, check registeredSMSUserID for smsUser profile image
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

      return {
        'name': name,
        'phoneNo': phoneNo,
        'profileImageUrl': profileImageUrl,
      };
    } else {
      return {
        'name': 'No Name',
        'phoneNo': 'No Number',
        'profileImageUrl': null,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Blacklist Contact',
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
        future: _fetchBlacklistDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error fetching blacklist details"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No blacklist details available"));
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
                      backgroundImage: profileImage as ImageProvider<Object>?,
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
                      child: Container(
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
                        _buildProfileOption(
                          Icons.delete,
                          'Remove from Blacklist',
                          color: Colors.red,
                          onTap: () {
                            _removeFromBlacklist(context);
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

  Future<void> _removeFromBlacklist(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;

    // Show confirmation dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Are you sure you want to remove this contact from the blacklist?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Cancel action
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm action
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    // If user confirms, proceed with removal
    if (confirm == true) {
      try {
        // Fetch the blacklist entry
        final blacklistDoc = await firestore.collection('blacklist').doc(blacklistId).get();
        if (!blacklistDoc.exists) {
          throw "Blacklist entry not found.";
        }

        final blacklistData = blacklistDoc.data();
        final phoneNo = blacklistData?['phoneNo'];
        final smsUserID = blacklistData?['smsUserID'];

        if (phoneNo == null || smsUserID == null) {
          throw "Invalid data in blacklist entry.";
        }

        // Delete the blacklist entry by document ID
        await firestore.collection('blacklist').doc(blacklistId).delete();

        // Update `isBlacklisted` field in the contact collection
        final contactQuery = await firestore
            .collection('contact')
            .where('phoneNo', isEqualTo: phoneNo)
            .where('smsUserID', isEqualTo: smsUserID)
            .get();

        if (contactQuery.docs.isNotEmpty) {
          for (var contactDoc in contactQuery.docs) {
            await contactDoc.reference.update({
              'isBlacklisted': false,
            });
          }
        }

        // Show success dialog
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Success'),
                content: const Text('Contact removed from blacklist successfully.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close the dialog
                      Navigator.of(context).pop(true); // Return to the previous screen
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        // Handle errors and show error dialog
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('An error occurred while removing from blacklist: $e'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
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
