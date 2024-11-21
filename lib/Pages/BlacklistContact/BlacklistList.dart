import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/BlacklistContact/BlacklistDetail.dart';
import 'package:smsecure/Pages/Home/push_notification_service.dart';

class BlacklistList extends StatelessWidget {
  final String currentUserID;
  final String searchText; // Accept search text for filtering
  final PushNotificationService _pushNotificationService =
      PushNotificationService();

  BlacklistList(
      {super.key, required this.currentUserID, required this.searchText});

  Future<String?> _getProfileImageUrl(
      String phoneNo, String? registeredSMSUserID) async {
    final contactQuerySnapshot = await FirebaseFirestore.instance
        .collection('contact')
        .where('phoneNo', isEqualTo: phoneNo)
        .limit(1)
        .get();

    if (contactQuerySnapshot.docs.isNotEmpty) {
      final contactData = contactQuerySnapshot.docs.first.data();

      // First, check if the contact has a profileImageUrl
      String? profileImageUrl = contactData['profileImageUrl'];
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        return profileImageUrl; // Return this if it exists and is not empty
      }

      // If no profileImageUrl, check for a registeredSMSUserID
      final smsUserId =
          contactData['registeredSMSUserID'] ?? registeredSMSUserID;
      if (smsUserId != null && smsUserId.isNotEmpty) {
        final smsUserDoc = await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(smsUserId)
            .get();
        if (smsUserDoc.exists) {
          profileImageUrl = smsUserDoc.data()?['profileImageUrl'];
          if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
            return profileImageUrl; // Return this if it exists and is not empty
          }
        }
      }
    }
    return null; // Return null if no valid profileImageUrl found
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
            .collection('blacklist')
            .where('smsUserID', isEqualTo: currentUserID)
            .orderBy('name') // Add sorting by 'name' here
            .snapshots(),
        builder: (context, blacklistSnapshot) {
          if (blacklistSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!blacklistSnapshot.hasData ||
              blacklistSnapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No blacklisted contacts available"));
          }

          var blacklistContacts = blacklistSnapshot.data!.docs;

          // Filter contacts by search text (name or phone number)
          blacklistContacts = blacklistContacts.where((doc) {
            final name = doc['name']?.toString().toLowerCase() ?? '';
            final phoneNo = doc['phoneNo']?.toString().toLowerCase() ?? '';
            return name.contains(searchText) || phoneNo.contains(searchText);
          }).toList();

          return Scrollbar(
            thumbVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(8),
            child: ListView.builder(
              itemCount: blacklistContacts.length,
              itemBuilder: (context, index) {
                var blacklistEntry = blacklistContacts[index];
                var contactName = blacklistEntry['name'] ?? '';
                var phoneNo = blacklistEntry['phoneNo'];
                var registeredSMSUserID = blacklistEntry['smsUserID'];

                return FutureBuilder<String?>(
                  future: _getProfileImageUrl(phoneNo, registeredSMSUserID),
                  builder: (context, profileImageSnapshot) {
                    final profileImageUrl = profileImageSnapshot.data;

                    // Check if contactName is numeric. If so, display only the phone number as the name
                    final isNumericName = int.tryParse(contactName) != null;
                    final displayName = isNumericName ? phoneNo : contactName;
                    final displayPhone = isNumericName ? '' : phoneNo;

                    final profileImage = profileImageUrl != null &&
                            profileImageUrl.isNotEmpty
                        ? MemoryImage(base64Decode(profileImageUrl))
                        : const AssetImage("images/HomePage/defaultProfile.png")
                            as ImageProvider;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to BlacklistDetailsPage with the blacklistId
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlacklistDetailsPage(
                                  blacklistId: blacklistEntry.id),
                            ),
                          );
                        },
                        onLongPress: () {
                          _showContactOptions(
                              context, displayName, blacklistEntry.id);
                        },
                        child: SizedBox(
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: isNumericName
                                        ? MainAxisAlignment.center
                                        : MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Color(0xFF113953),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!isNumericName) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          displayPhone,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showContactOptions(
      BuildContext context, String contactName, String contactId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext bottomSheetContext) {
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
                  Navigator.pop(bottomSheetContext); // Close the bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BlacklistDetailsPage(blacklistId: contactId),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text(
                  'Remove from Blacklist',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext); // Close the bottom sheet
                  _deleteContact(context, contactId); // Use parent context here
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteContact(
      BuildContext parentContext, String contactId) async {
    try {
      // Ask for confirmation
      final bool? confirm = await showDialog(
        context: parentContext,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: const Text(
                'Are you sure you want to remove this contact from the blacklist?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false); // Cancel action
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true); // Confirm action
                },
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );

      print('Confirmation dialog result: $confirm');

      if (confirm == true) {
        final firestore = FirebaseFirestore.instance;

        // Fetch the blacklist document
        final blacklistDoc =
            await firestore.collection('blacklist').doc(contactId).get();
        if (!blacklistDoc.exists) {
          throw "Blacklist document not found.";
        }

        final blacklistData = blacklistDoc.data();
        final phoneNo = blacklistData?['phoneNo'];
        final smsUserID = blacklistData?['smsUserID'];

        if (phoneNo == null || smsUserID == null) {
          throw "Invalid data in the blacklist document.";
        }

        print('Checking for spam messages...');

        bool hasSpamMessages = await _checkForSpamMessages(
            FirebaseFirestore.instance, smsUserID, phoneNo);
        print('Spam messages found: $hasSpamMessages');

        // Update other collections (contact, conversations)
        print('Updating contact status...');
        await _updateContactStatus(firestore, phoneNo, smsUserID);
        print('Contact status updated.');

        // Delete the blacklist document
        print('Deleting blacklist document...');
        await firestore.collection('blacklist').doc(contactId).delete();
        print('Blacklist document deleted.');

        // Show spam notification if spam messages exist
        if (hasSpamMessages) {
          print('Sending FCM notification...');
          await PushNotificationService.sendNotificationToUser(
            smsUserID: smsUserID,
            senderName: "System Alert", // Customize the sender name
            senderPhone: phoneNo,
            messageContent:
                "Spam messages were found from $phoneNo. They are in the Quarantine Folder.",
          );
        }

        // Show success dialog after deletion
        if (parentContext.mounted) {
          showDialog(
            context: parentContext,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Success'),
                content:
                    const Text('Contact removed from blacklist successfully.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext)
                          .pop(); // Close the success dialog
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
      // Handle errors gracefully
      if (parentContext.mounted) {
        showDialog(
          context: parentContext,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('An error occurred: $e'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close the error dialog
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

  Future<bool> _checkForSpamMessages(
      FirebaseFirestore firestore, String smsUserID, String phoneNo) async {
    final spamContactQuery = await firestore
        .collection('spamContact')
        .where('smsUserID', isEqualTo: smsUserID)
        .where('phoneNo', isEqualTo: phoneNo)
        .where('isRemoved', isEqualTo: false)
        .limit(1)
        .get();

    if (spamContactQuery.docs.isNotEmpty) {
      final spamContactDoc = spamContactQuery.docs.first;
      final spamMessagesQuery = await firestore
          .collection('spamContact')
          .doc(spamContactDoc.id)
          .collection('spamMessages')
          .where('isRemoved', isEqualTo: false)
          .get();

      return spamMessagesQuery.docs.isNotEmpty;
    }

    return false;
  }

  Future<void> _updateContactStatus(
      FirebaseFirestore firestore, String phoneNo, String smsUserID) async {
    // Update contact status in contact collection
    final contactQuery = await firestore
        .collection('contact')
        .where('phoneNo', isEqualTo: phoneNo)
        .where('smsUserID', isEqualTo: smsUserID)
        .get();

    for (var contactDoc in contactQuery.docs) {
      await contactDoc.reference.update({'isBlacklisted': false});
    }

    try {
      // Fetch spam messages and build the map
      final spamContactSnapshot = await firestore
          .collection('spamContact')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('phoneNo', isEqualTo: phoneNo)
          .where('isRemoved', isEqualTo: false)
          .get();

      Map<String, String> spamMessagesWithKeywords = {};
      for (var spamContactDoc in spamContactSnapshot.docs) {
        final spamMessagesSnapshot = await firestore
            .collection('spamContact')
            .doc(spamContactDoc.id)
            .collection('spamMessages')
            .where('isRemoved', isEqualTo: false)
            .get();

        for (var spamMessageDoc in spamMessagesSnapshot.docs) {
          String normalizedId = normalizeID(spamMessageDoc.id);
          spamMessagesWithKeywords[normalizedId] =
              spamMessageDoc.get('keyword') ?? '';
        }
      }

      print('Normalized Spam Message IDs: ${spamMessagesWithKeywords.keys}');

      // Update conversation messages
      final conversationQuery = await firestore
          .collection('conversations')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('participants', arrayContains: phoneNo)
          .get();

      for (var conversationDoc in conversationQuery.docs) {
        print('Processing conversation: ${conversationDoc.id}');
        await conversationDoc.reference.update({'isBlacklisted': false});

        final messagesSnapshot =
            await conversationDoc.reference.collection('messages').get();

        for (var messageDoc in messagesSnapshot.docs) {
          String normalizedMessageId = normalizeID(messageDoc.id);

          print(
              'Checking Message ID: ${messageDoc.id}, Normalized ID: $normalizedMessageId');

          if (spamMessagesWithKeywords.containsKey(normalizedMessageId)) {
            try {
              await messageDoc.reference.update({'isBlacklisted': false});
              print('Updated isBlacklisted for Message ID: ${messageDoc.id}');
            } catch (e) {
              print('Failed to update message ID: ${messageDoc.id}, Error: $e');
            }
          } else {
            print(
                'No match found for Message ID: ${messageDoc.id}, skipping update.');
          }
        }
      }
    } catch (e) {
      print('Error updating contact status: $e');
    }
  }

  // Normalization function similar to QuarantineChat.dart
  String normalizeID(String id) {
    return id.split('_').first; // Normalize IDs by taking the first part
  }
}
