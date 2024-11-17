import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/BlacklistContact/BlacklistPage.dart';
import 'package:smsecure/Pages/CustomisableFilteringSetting/CustomisableFilteringHomePage.dart';
import 'package:smsecure/Pages/QuarantineFolder/QuarantineFolderPage.dart';
import 'package:smsecure/Pages/WhitelistContact/WhitelistPage.dart';

class SideNavigationBar extends StatefulWidget {
  final Function(int) onMenuItemTap;

  const SideNavigationBar({super.key, required this.onMenuItemTap});

  @override
  _SideNavigationBarState createState() => _SideNavigationBarState();
}

class _SideNavigationBarState extends State<SideNavigationBar> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String userName = 'Loading...';
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userPhone = await _secureStorage.read(key: 'userPhone');
      if (userPhone != null) {
        // Fetch the user's profile data from Firestore
        final querySnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .where('phoneNo', isEqualTo: userPhone)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          setState(() {
            userName = userData['name'] ?? 'No Name';
            profileImageUrl = userData['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              userName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: null,
            currentAccountPicture: profileImageUrl != null &&
                    profileImageUrl!.isNotEmpty
                ? _buildProfileImage(profileImageUrl!)
                : CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    child:
                        const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
            decoration: const BoxDecoration(
              color: Color(0xFF113953), // Adjust this color as needed
            ),
          ),
          _buildDrawerItem(Icons.home, "Home", context, 0),
          _buildDrawerItem(Icons.contacts, "Contacts", context, 1),
          _buildDrawerItem(Icons.message, "Messages", context, 2),
          _buildDrawerItem(Icons.person, "Profile", context, 3),
          _buildDrawerItem2(Icons.check_circle, "Whitelisted Contacts", context,
              const WhitelistPage()),
          _buildDrawerItem2(Icons.block, "Blacklisted Contacts", context,
              const BlacklistPage()),
          _buildDrawerItem2(Icons.folder, "Quarantine Folder", context,
              const QuarantineFolderPage()),
          _buildDrawerItem2(Icons.settings, "Customisable Filtering Settings",
              context, const CustomisableFilteringHomePage()),
        ],
      ),
    );
  }

  /// Builds the profile image from a Base64-encoded string.
  Widget _buildProfileImage(String base64String) {
    try {
      final decodedBytes = base64Decode(base64String);
      return CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(decodedBytes),
        backgroundColor: Colors.grey[300],
      );
    } catch (e) {
      print("Error decoding Base64 profile image: $e");
      // If decoding fails, return default icon
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, size: 60, color: Colors.white),
      );
    }
  }

  ListTile _buildDrawerItem(
      IconData icon, String title, BuildContext context, int index) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF113953)),
      title: Text(
        title,
        style:
            const TextStyle(fontSize: 16, color: Color.fromARGB(200, 0, 0, 0)),
      ),
      onTap: () {
        Navigator.pop(context); // Close the drawer
        if (index >= 0) {
          widget.onMenuItemTap(index); // Notify the parent to update the index
        }
      },
    );
  }

  ListTile _buildDrawerItem2(IconData icon, String title, BuildContext context,
      Widget destinationPage) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF113953)),
      title: Text(
        title,
        style:
            const TextStyle(fontSize: 16, color: Color.fromARGB(200, 0, 0, 0)),
      ),
      onTap: () {
        Navigator.pop(context); // Close the drawer on tap
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  destinationPage), // Navigate to the provided page
        );
      },
    );
  }
}
