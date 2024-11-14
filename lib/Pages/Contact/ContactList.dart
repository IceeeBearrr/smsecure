import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/Contact/ContactDetail.dart';

class ContactList extends StatefulWidget {
  final String currentUserID;
  final String searchText;

  const ContactList({
    super.key,
    required this.currentUserID,
    required this.searchText,
  });

  @override
  _ContactListState createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  late Future<List<String>> _spamContactsFuture;

  @override
  void initState() {
    super.initState();
    _spamContactsFuture = _getSpamContacts();
  }


  Future<String?> _getProfileImageUrl(
      String contactId, String? registeredSMSUserID) async {
    final contactDoc = await FirebaseFirestore.instance
        .collection('contact')
        .doc(contactId)
        .get();

    if (contactDoc.exists) {
      final contactData = contactDoc.data();
      final profileImageUrl = contactData?['profileImageUrl'];

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        return profileImageUrl;
      }

      final smsUserId =
          contactData?['registeredSMSUserID'] ?? registeredSMSUserID;
      if (smsUserId != null && smsUserId.isNotEmpty) {
        final smsUserDoc = await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(smsUserId)
            .get();
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

  Future<void> _addToWhitelist(BuildContext context, String contactId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      print("Start of _addToWhitelist");

      // Fetch contact details
      final contactDoc =
          await firestore.collection('contact').doc(contactId).get();
      if (!contactDoc.exists) {
        _showMessageDialog(context, "Error", "Contact not found.");
        return;
      }

      final contactData = contactDoc.data();
      print("Contact details fetched: $contactData");

      final name = contactData?['name'];
      final phoneNo = contactData?['phoneNo'];
      final smsUserID = contactData?['smsUserID'];

      if (name == null || phoneNo == null || smsUserID == null) {
        _showMessageDialog(
            context, "Error", "Failed to retrieve contact details.");
        return;
      }

      // Check if contact is already in whitelist
      final existingWhitelist = await firestore
          .collection('whitelist')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('phoneNo', isEqualTo: phoneNo)
          .get();

      print(
          "Whitelist query results: ${existingWhitelist.docs.map((doc) => doc.data())}");
      if (existingWhitelist.docs.isNotEmpty) {
        print("Contact already exists in whitelist. Showing error dialog.");
        _showMessageDialog(
            context, "Error", "This contact is already in the whitelist.");
        return;
      }

      // Confirm addition
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content:
                Text('Are you sure you want to add "$name" to the whitelist?'),
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

      print("Confirm dialog result: $confirm");
      if (confirm != true) return;

      // Add to whitelist
      await firestore.collection('whitelist').add({
        'name': name,
        'phoneNo': phoneNo,
        'smsUserID': smsUserID,
      });

      print("Contact successfully added to whitelist");

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

  Future<List<String>> _getSpamContacts() async {
    final spamQuery = await FirebaseFirestore.instance
        .collection('spamContact')
        .where('smsUserID', isEqualTo: widget.currentUserID)
        .where('isRemoved', isEqualTo: false)
        .get();

    final spamContacts =
        spamQuery.docs.map((doc) => doc['phoneNo'] as String).toList();
    print("Retrieved spam contacts: $spamContacts"); // Debugging log
    return spamContacts;
  }

  void _showMessageDialog(BuildContext context, String title, String message) {
    if (!context.mounted) {
      print("Context is not mounted; cannot show dialog.");
      return;
    }
    Future.microtask(() {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    });
  }

  void _reloadContacts() {
    setState(() {
      _spamContactsFuture = _getSpamContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
        future: _getSpamContacts(), // Fetch spam contacts
        builder: (context, spamSnapshot) {
          if (spamSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (spamSnapshot.hasError) {
            return const Center(child: Text("Error loading spam contacts"));
          }

          final spamContacts =
              spamSnapshot.data ?? []; // Retrieve spam contacts
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
                  .where('smsUserID', isEqualTo: widget.currentUserID)
                  .where('isBlacklisted', isEqualTo: false)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No contacts available"));
                }

                var contacts = snapshot.data!.docs;

                // Filter out spam contacts
                contacts = contacts.where((doc) {
                  final phoneNo = doc['phoneNo'].toString();
                  print("Checking contact phoneNo: $phoneNo");
                  final isNotSpam = !spamContacts.contains(phoneNo);
                  print("Is not spam: $isNotSpam");
                  return isNotSpam;
                }).toList();

                // Filter contacts based on searchText (name or phone number)
                contacts = contacts.where((doc) {
                  final name = doc['name']?.toString().toLowerCase() ?? '';
                  final phoneNo =
                      doc['phoneNo']?.toString().toLowerCase() ?? '';
                  return name.contains(widget.searchText) ||
                      phoneNo.contains(widget.searchText);
                }).toList();

                return Scrollbar(
                  thumbVisibility: true,
                  thickness: 8.0,
                  radius: const Radius.circular(8),
                  child: ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      var contact = contacts[index];
                      var contactName = contact['name'] ?? '';
                      var contactPhone = contact['phoneNo'] ?? '';

                      // Check if contactName is numeric. If so, display only the phone number as the name
                      final isNumericName = int.tryParse(contactName) != null;
                      final displayName =
                          isNumericName ? contactPhone : contactName;
                      final displayPhone = isNumericName ? '' : contactPhone;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ContactDetailsPage(contactId: contact.id),
                              ),
                            ).then((result) {
                              if (result == true) {
                                // Reload the page or refresh the data
                                _reloadContacts();
                              }
                            });
                          },
                          onLongPress: () {
                            _showContactOptions(
                                context, displayName, contact.id);
                          },
                          child: FutureBuilder<String?>(
                            future: _getProfileImageUrl(
                                contact.id, contact['registeredSMSUserID']),
                            builder: (context, snapshot) {
                              final profileImage = snapshot.hasData &&
                                      snapshot.data!.isNotEmpty
                                  ? MemoryImage(base64Decode(snapshot.data!))
                                  : const AssetImage(
                                          "images/HomePage/defaultProfile.png")
                                      as ImageProvider;

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
        });
  }

  void _showContactOptions(
      BuildContext parentContext, String contactName, String contactId) {
    showModalBottomSheet(
      context: parentContext,
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
                  Navigator.pop(context); // Dismiss modal first
                  Navigator.push(
                    parentContext,
                    MaterialPageRoute(
                      builder: (context) => ContactDetailsPage(contactId: contactId),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _reloadContacts();
                    }
                  });
                },
              ),
              ListTile(
                title: const Text('Add to Whitelist'),
                onTap: () {
                  Navigator.pop(context);
                  _addToWhitelist(parentContext, contactId).then((_) {
                    _reloadContacts();
                  });
                },
              ),
              ListTile(
                title: const Text(
                  'Blacklist Contact',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addToBlacklist(parentContext, contactId).then((_) {
                    _reloadContacts();
                  });
                },
              ),
              ListTile(
                title: const Text(
                  'Delete Contact',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteContact(parentContext, contactId).then((_) {
                    _reloadContacts();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addToBlacklist(BuildContext context, String contactId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Fetch contact details
      final contactDoc =
          await firestore.collection('contact').doc(contactId).get();
      if (!contactDoc.exists) {
        _showMessageDialog(context, "Error", "Contact not found.");
        return;
      }

      final contactData = contactDoc.data();
      final name = contactData?['name'];
      final phoneNo = contactData?['phoneNo'];
      final smsUserID = contactData?['smsUserID'];

      if (name == null || phoneNo == null || smsUserID == null) {
        _showMessageDialog(
            context, "Error", "Failed to retrieve contact details.");
        return;
      }

      // Check if contact is already in the blacklist
      final existingBlacklist = await firestore
          .collection('blacklist')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('phoneNo', isEqualTo: phoneNo)
          .get();

      if (existingBlacklist.docs.isNotEmpty) {
        _showMessageDialog(
            context, "Error", "This contact is already in the blacklist.");
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
        _showMessageDialog(
            context, "Success", "Contact successfully added to the blacklist.");
      }
    } catch (e) {
      if (context.mounted) {
        _showMessageDialog(context, "Error", "Error adding to blacklist: $e");
      }
    }
  }

  Future<void> _deleteContact(BuildContext context, String contactId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      print("Start of _deleteContact");

      // Confirm deletion
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content:
                const Text('Are you sure you want to delete this contact?'),
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

      print("Confirm dialog result: $confirm");
      if (confirm != true) return;

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
                onPressed: () => Navigator.of(dialogContext).pop(),
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
}
