import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/QuarantineFolder/QuarantineDetail.dart';

class QuarantineFolderList extends StatefulWidget {
  final String currentUserID;
  final String searchText;

  const QuarantineFolderList({
    super.key,
    required this.currentUserID,
    required this.searchText,
  });

  @override
  _QuarantineFolderListState createState() => _QuarantineFolderListState();
}

class _QuarantineFolderListState extends State<QuarantineFolderList> {
  Future<String?> _getProfileImageUrl(
      String phoneNo, String? registeredSMSUserID) async {
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
            return profileImageUrl;
          }
        }
      }
    }
    return null;
  }

  Future<void> _reloadPage() async {
    setState(() {});
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
            .where('smsUserID', isEqualTo: widget.currentUserID)
            .orderBy('name')
            .snapshots(),
        builder: (context, quarantineSnapshot) {
          if (quarantineSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!quarantineSnapshot.hasData ||
              quarantineSnapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No quarantined contacts available"));
          }

          var quarantineContacts = quarantineSnapshot.data!.docs;

          // Filter out blacklisted contacts
          return FutureBuilder<List<DocumentSnapshot>>(
            future: _filterNonBlacklistedContacts(quarantineContacts),
            builder: (context, filteredSnapshot) {
              if (filteredSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!filteredSnapshot.hasData || filteredSnapshot.data!.isEmpty) {
                return const Center(
                    child: Text("No non-blacklisted contacts available"));
              }

              var filteredContacts = filteredSnapshot.data!;

              return Scrollbar(
                thumbVisibility: true,
                thickness: 8.0,
                radius: const Radius.circular(8),
                child: ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    var quarantineEntry = filteredContacts[index];
                    var contactName = quarantineEntry['name'] ?? '';
                    var phoneNo = quarantineEntry['phoneNo'];
                    var registeredSMSUserID = quarantineEntry['smsUserID'];

                    return FutureBuilder<String?>(
                      future: _getProfileImageUrl(phoneNo, registeredSMSUserID),
                      builder: (context, profileImageSnapshot) {
                        final profileImageUrl = profileImageSnapshot.data;

                        final isNumericName = int.tryParse(contactName) != null;
                        final displayName =
                            isNumericName ? phoneNo : contactName;
                        final displayPhone = isNumericName ? '' : phoneNo;

                        final profileImage = profileImageUrl != null &&
                                profileImageUrl.isNotEmpty
                            ? MemoryImage(base64Decode(profileImageUrl))
                            : const AssetImage(
                                    "images/HomePage/defaultProfile.png")
                                as ImageProvider;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuarantineDetailsPage(
                                      quarantineId: quarantineEntry.id),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  setState(() {
                                    // Trigger a reload of the data
                                  });
                                }
                              });
                            },
                            onLongPress: () {
                              _showContactOptions(
                                  context, displayName, quarantineEntry.id);
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
          );
        },
      ),
    );
  }

  // Function to filter non-blacklisted contacts
  Future<List<DocumentSnapshot>> _filterNonBlacklistedContacts(
      List<DocumentSnapshot> spamContacts) async {
    List<DocumentSnapshot> filteredContacts = [];

    for (var contact in spamContacts) {
      var phoneNo = contact['phoneNo'];
      var smsUserID = contact['smsUserID'];

      // Check the contact collection for blacklisted status
      final contactSnapshot = await FirebaseFirestore.instance
          .collection('contact')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('phoneNo', isEqualTo: phoneNo)
          .limit(1)
          .get();

      // If contact exists and is not blacklisted, add to the filtered list
      if (contactSnapshot.docs.isEmpty ||
          contactSnapshot.docs.first.data()['isBlacklisted'] != true) {
        filteredContacts.add(contact);
      }
    }

    return filteredContacts;
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
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          QuarantineDetailsPage(quarantineId: contactId),
                    ),
                  ).then((result) {
                    if (result == true) {
                      setState(() {
                        // Trigger a reload of the data
                      });
                    }
                  });
                },
              ),
              ListTile(
                title: const Text(
                  'Blacklist Contact',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _blacklistContact(context, contactId);
                },
              ),
              ListTile(
                title: const Text(
                  'Remove from Quarantine',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _removeFromSpamContact(context, contactId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _blacklistContact(BuildContext context, String contactId) async {
    try {
      // Fetch the contact data from the spamContact collection
      final contactDoc = await FirebaseFirestore.instance
          .collection('spamContact')
          .doc(contactId)
          .get();

      if (!contactDoc.exists) {
        throw 'Contact not found in spamContact collection.';
      }

      final contactData = contactDoc.data();

      // Show confirmation dialog
      final bool? confirm = await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: Text(
                'Are you sure you want to blacklist this contact (${contactData?['name']} - ${contactData?['phoneNo']})?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false); // User cancels
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true); // User confirms
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

        // Reload the page
        _reloadPage();

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
      // Show error message
      if (context.mounted) {
        showDialog(
          context: context,
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

  Future<void> _removeFromSpamContact(
      BuildContext context, String spamContactId) async {
    final firestore = FirebaseFirestore.instance;

    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text(
              'Are you sure you want to remove this contact from spam contacts?'),
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

        // Delete associated spamMessages sub-collection
        final spamMessagesQuery = await firestore
            .collection('spamContact')
            .doc(spamContactId)
            .collection('spamMessages')
            .get();

        for (var spamMessageDoc in spamMessagesQuery.docs) {
          await spamMessageDoc.reference.delete();
        }

        // Delete the spamContact document
        await firestore.collection('spamContact').doc(spamContactId).delete();

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
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Success'),
                content: const Text(
                    'Contact removed from spam contacts successfully.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop(true);
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
                    'An error occurred while removing from spam contacts: $e'),
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
}
