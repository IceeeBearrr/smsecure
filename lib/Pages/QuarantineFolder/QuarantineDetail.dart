import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/Chat/ChatPage.dart';
import 'package:smsecure/Pages/QuarantineFolder/Chat/QuarantineChatPage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class QuarantineDetailsPage extends StatelessWidget {
  final String quarantineId;
  final storage = const FlutterSecureStorage();

  const QuarantineDetailsPage({super.key, required this.quarantineId});

  Future<Map<String, dynamic>> _fetchQuarantineDetails() async {
    final firestore = FirebaseFirestore.instance;
    final quarantineSnapshot =
        await firestore.collection('spamContact').doc(quarantineId).get();

    if (quarantineSnapshot.exists) {
      final quarantineData = quarantineSnapshot.data()!;
      final phoneNo = quarantineData['phoneNo'];
      final name = quarantineData['name'] ?? phoneNo;
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
            final smsUserDoc = await firestore
                .collection('smsUser')
                .doc(registeredSMSUserID)
                .get();
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

  Future<void> _sendMessage(BuildContext context, String receiverPhone) async {
    final firestore = FirebaseFirestore.instance;
    final userPhone = await storage.read(key: "userPhone");

    if (userPhone == null) {
      print("User phone not found in secure storage.");
      return;
    }

    QuerySnapshot conversationSnapshot = await firestore
        .collection('conversations')
        .where('participants', arrayContainsAny: [userPhone]).get();

    String? conversationID;
    for (var doc in conversationSnapshot.docs) {
      List<dynamic> participants = doc['participants'];
      if (participants.contains(receiverPhone) &&
          participants.contains(userPhone)) {
        conversationID = doc.id;
        break;
      }
    }

    if (conversationID == null) {
      DocumentReference newConversation =
          await firestore.collection('conversations').add({
        'participants': [userPhone, receiverPhone],
      });
      conversationID = newConversation.id;
    }

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
          'Quarantine Contact',
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
        future: _fetchQuarantineDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text("Error fetching quarantine details"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No quarantine details available"));
          }

          final data = snapshot.data!;
          final profileImage = data['profileImageUrl'] != null &&
                  data['profileImageUrl'].isNotEmpty
              ? MemoryImage(base64Decode(data['profileImageUrl']))
              : null;

          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 13.0, horizontal: 10.0),
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
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.white)
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10),
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
                            Icons.message, 'View Message Detail', onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuarantineChatPage(
                                  quarantineId: quarantineId),
                            ),
                          );
                        }),
                        _buildProfileOption(
                          Icons.block,
                          'Blacklist Contact',
                          color: Colors.red,
                          onTap: () {
                            _blacklistContact(context, quarantineId);
                          },
                        ),
                        _buildProfileOption(
                          Icons.delete,
                          'Remove from Quarantine',
                          color: Colors.red,
                          onTap: () {
                            _removeFromSpamContact(context, quarantineId);
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

  Future<void> _blacklistContact(
      BuildContext context, String quarantineId) async {
    try {
      // Fetch the contact data from the spamContact collection
      final contactDoc = await FirebaseFirestore.instance
          .collection('spamContact')
          .doc(quarantineId)
          .get();

      if (!contactDoc.exists) {
        throw 'Contact not found in spamContact collection.';
      }

      final contactData = contactDoc.data();

      // Show confirmation dialog
      final bool? confirm = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: Text(
                'Are you sure you want to blacklist this contact (${contactData?['name']} - ${contactData?['phoneNo']})?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // User cancels
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // User confirms
                },
                child: const Text('Blacklist'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        final phoneNo = contactData?['phoneNo'];
        final smsUserID = contactData?['smsUserID'];

        if (phoneNo == null || smsUserID == null) {
          throw 'Invalid contact data: phoneNo or smsUserID is missing.';
        }

        // Add the contact to the blacklist collection
        await FirebaseFirestore.instance.collection('blacklist').add({
          'name': contactData?['name'],
          'phoneNo': phoneNo,
          'smsUserID': smsUserID,
          'blacklistedFrom': 'Spam Contact', // Updated field
          'blacklistedDateTime': Timestamp.now(), // New field
        });

        // Update isBlacklisted in the contact collection
        final contactSnapshot = await FirebaseFirestore.instance
            .collection('contact')
            .where('smsUserID', isEqualTo: smsUserID)
            .where('phoneNo', isEqualTo: phoneNo)
            .get();

        if (contactSnapshot.docs.isNotEmpty) {
          for (var doc in contactSnapshot.docs) {
            await doc.reference.update({'isBlacklisted': true});
          }
          print(
              "Updated isBlacklisted field for contact(s) in the contact collection.");
        } else {
          print("No matching contact found in the contact collection.");
        }

        // Update isBlacklisted in the conversations collection
        final conversationSnapshot = await FirebaseFirestore.instance
            .collection('conversations')
            .where('smsUserID', isEqualTo: smsUserID)
            .where('participants', arrayContains: phoneNo)
            .get();

        if (conversationSnapshot.docs.isNotEmpty) {
          for (var conversationDoc in conversationSnapshot.docs) {
            await conversationDoc.reference.update({'isBlacklisted': true});
          }
          print(
              "Updated isBlacklisted field for conversations involving the contact.");
        } else {
          print("No matching conversations found for the contact.");
        }

        // Show success message
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Success'),
                content:
                    const Text('Contact has been successfully blacklisted.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close the dialog
                      Navigator.of(context)
                          .pop(true); // Return to the previous screen
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
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

  Future<void> _removeFromSpamContact(
      BuildContext context, String spamContactId) async {
    final firestore = FirebaseFirestore.instance;

    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text(
              'Are you sure you want to mark this contact as removed from spam contacts?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Fetch the spamContact document
        final spamContactDoc =
            await firestore.collection('spamContact').doc(spamContactId).get();
        if (!spamContactDoc.exists) {
          throw "Spam contact document not found.";
        }

        final spamContactData = spamContactDoc.data();
        final phoneNo = spamContactData?['phoneNo'];
        final smsUserID = spamContactData?['smsUserID'];

        if (phoneNo == null || smsUserID == null) {
          throw "Invalid data in the spam contact document.";
        }

        // Update `isRemoved` field in the spamContact document
        await firestore.collection('spamContact').doc(spamContactId).update({
          'isRemoved': true,
        });

        // Delete associated spamMessages sub-collection
        final spamMessagesQuery = await firestore
            .collection('spamContact')
            .doc(spamContactId)
            .collection('spamMessages')
            .get();

        for (var spamMessageDoc in spamMessagesQuery.docs) {
          await spamMessageDoc.reference.delete();
        }

        // Update `isSpam` in the contact collection
        final contactQuery = await firestore
            .collection('contact')
            .where('phoneNo', isEqualTo: phoneNo)
            .where('smsUserID', isEqualTo: smsUserID)
            .get();

        if (contactQuery.docs.isNotEmpty) {
          for (var contactDoc in contactQuery.docs) {
            await contactDoc.reference.update({
              'isSpam': false,
            });
          }
        }

        // Update `isSpam` in the conversations collection
        final conversationQuery = await firestore
            .collection('conversations')
            .where('smsUserID', isEqualTo: smsUserID)
            .where('participants', arrayContains: phoneNo)
            .get();

        if (conversationQuery.docs.isNotEmpty) {
          for (var conversationDoc in conversationQuery.docs) {
            await conversationDoc.reference.update({
              'isSpam': false,
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
                content: const Text(
                    'Contact marked as removed from spam contacts successfully.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close the dialog
                      Navigator.of(context)
                          .pop(true); // Return to the previous screen
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        // Handle errors gracefully
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text(
                    'An error occurred while marking as removed from spam contacts: $e'),
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
  }

  Widget _buildProfileOption(IconData icon, String title,
      {Color? color, VoidCallback? onTap}) {
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
