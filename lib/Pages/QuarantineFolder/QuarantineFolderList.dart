import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/QuarantineFolder/QuarantineDetail.dart';

class QuarantineFolderList extends StatelessWidget {
  final String currentUserID;
  final String searchText;

  const QuarantineFolderList({
    super.key,
    required this.currentUserID,
    required this.searchText,
  });

  Future<String?> _getProfileImageUrl(String phoneNo, String? registeredSMSUserID) async {
    final contactQuerySnapshot = await FirebaseFirestore.instance
        .collection('contact')
        .where('phoneNo', isEqualTo: phoneNo)
        .limit(1)
        .get();

    if (contactQuerySnapshot.docs.isNotEmpty) {
      final contactData = contactQuerySnapshot.docs.first.data();

      String? profileImageUrl = contactData['profileImageUrl'];
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        return profileImageUrl;
      }

      final smsUserId = contactData['registeredSMSUserID'] ?? registeredSMSUserID;
      if (smsUserId != null && smsUserId.isNotEmpty) {
        final smsUserDoc = await FirebaseFirestore.instance.collection('smsUser').doc(smsUserId).get();
        if (smsUserDoc.exists) {
          profileImageUrl = smsUserDoc.data()?['profileImageUrl'];
          if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
            return profileImageUrl;
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
            .collection('spamContact')
            .where('smsUserID', isEqualTo: currentUserID)
            .orderBy('name')
            .snapshots(),
        builder: (context, quarantineSnapshot) {
          if (quarantineSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!quarantineSnapshot.hasData || quarantineSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No quarantined contacts available"));
          }

          var quarantineContacts = quarantineSnapshot.data!.docs;

          quarantineContacts = quarantineContacts.where((doc) {
            final name = doc['name']?.toString().toLowerCase() ?? '';
            final phoneNo = doc['phoneNo']?.toString().toLowerCase() ?? '';
            return name.contains(searchText) || phoneNo.contains(searchText);
          }).toList();

          return Scrollbar(
            thumbVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(8),
            child: ListView.builder(
              itemCount: quarantineContacts.length,
              itemBuilder: (context, index) {
                var quarantineEntry = quarantineContacts[index];
                var contactName = quarantineEntry['name'] ?? '';
                var phoneNo = quarantineEntry['phoneNo'];
                var registeredSMSUserID = quarantineEntry['smsUserID'];

                return FutureBuilder<String?>(
                  future: _getProfileImageUrl(phoneNo, registeredSMSUserID),
                  builder: (context, profileImageSnapshot) {
                    final profileImageUrl = profileImageSnapshot.data;

                    final isNumericName = int.tryParse(contactName) != null;
                    final displayName = isNumericName ? phoneNo : contactName;
                    final displayPhone = isNumericName ? '' : phoneNo;

                    final profileImage = profileImageUrl != null && profileImageUrl.isNotEmpty
                        ? MemoryImage(base64Decode(profileImageUrl))
                        : const AssetImage("images/HomePage/defaultProfile.png") as ImageProvider;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuarantineDetailsPage(quarantineId: quarantineEntry.id),
                            ),
                          );
                        },
                        onLongPress: () {
                          _showContactOptions(context, displayName, quarantineEntry.id);
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: isNumericName ? MainAxisAlignment.center : MainAxisAlignment.start,
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

  void _showContactOptions(BuildContext context, String contactName, String contactId) {
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
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuarantineDetailsPage(quarantineId: contactId),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text(
                  'Remove from Quarantine',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _deleteContact(context, contactId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteContact(BuildContext parentContext, String contactId) async {
    try {
      final bool? confirm = await showDialog(
        context: parentContext,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: const Text('Are you sure you want to remove this contact from quarantine?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await FirebaseFirestore.instance.collection('quarantine').doc(contactId).delete();

        if (parentContext.mounted) {
          showDialog(
            context: parentContext,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Success'),
                content: const Text('Contact removed from quarantine successfully.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
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
                    Navigator.of(dialogContext).pop();
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
