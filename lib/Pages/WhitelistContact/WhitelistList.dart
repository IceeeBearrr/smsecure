import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/WhitelistContact/WhitelistDetail.dart';

class WhitelistList extends StatelessWidget {
  final String currentUserID;
  final String searchText;

  const WhitelistList({super.key, required this.currentUserID, required this.searchText});

  Future<String?> _getProfileImageUrl(String phoneNo, String? registeredSMSUserID) async {
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
      final smsUserId = contactData['registeredSMSUserID'] ?? registeredSMSUserID;
      if (smsUserId != null && smsUserId.isNotEmpty) {
        final smsUserDoc = await FirebaseFirestore.instance.collection('smsUser').doc(smsUserId).get();
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
            .collection('whitelist')
            .where('smsUserID', isEqualTo: currentUserID)
            .orderBy('name') // Add sorting by 'name' here
            .snapshots(),
        builder: (context, whitelistSnapshot) {
          if (whitelistSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!whitelistSnapshot.hasData || whitelistSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No whitelist contacts available"));
          }

          var whitelistContacts = whitelistSnapshot.data!.docs;

          
          // Filter contacts by search text (name or phone number)
          whitelistContacts = whitelistContacts.where((doc) {
            final name = doc['name']?.toString().toLowerCase() ?? '';
            final phoneNo = doc['phoneNo']?.toString().toLowerCase() ?? '';
            return name.contains(searchText) || phoneNo.contains(searchText);
          }).toList();
          
          return Scrollbar(
            thumbVisibility: true,
            thickness: 8.0,
            radius: const Radius.circular(8),
            child: ListView.builder(
              itemCount: whitelistContacts.length,
              itemBuilder: (context, index) {
                var whitelistEntry = whitelistContacts[index];
                var contactName = whitelistEntry['name'] ?? '';
                var phoneNo = whitelistEntry['phoneNo'];
                var registeredSMSUserID = whitelistEntry['smsUserID'];

                return FutureBuilder<String?>(
                  future: _getProfileImageUrl(phoneNo, registeredSMSUserID),
                  builder: (context, profileImageSnapshot) {
                    final profileImageUrl = profileImageSnapshot.data;
                    
                    // Check if contactName is numeric. If so, display only the phone number as the name
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
                          // Navigate to ContactDetailsPage with the contactId
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WhitelistDetailsPage(whitelistId: whitelistEntry.id),
                            ),
                          );
                        },
                        onLongPress: () {
                          _showContactOptions(context, displayName, whitelistEntry.id);
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
                  Navigator.pop(bottomSheetContext); // Close the bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WhitelistDetailsPage(whitelistId: contactId),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text(
                  'Remove from Whitelist',
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


  
  Future<void> _deleteContact(BuildContext parentContext, String contactId) async {
    try {
      // Ask for confirmation
      final bool? confirm = await showDialog(
        context: parentContext,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: const Text('Are you sure you want to remove this contact from the whitelist?'),
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

      if (confirm == true) {
        // Delete from Firestore
        await FirebaseFirestore.instance.collection('whitelist').doc(contactId).delete();

        // Show success dialog after deletion
        if (parentContext.mounted) {
          showDialog(
            context: parentContext,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Success'),
                content: const Text('Contact removed from whitelist successfully.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close the success dialog
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



}
