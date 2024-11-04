import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SideNavigationBar extends StatefulWidget {
  const SideNavigationBar({Key? key}) : super(key: key);

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
            profileImageUrl = userData['profileImageUrl'] ?? null;
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
            currentAccountPicture: profileImageUrl != null && profileImageUrl!.isNotEmpty
                ? _buildProfileImage(profileImageUrl!)
                : CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
            decoration: const BoxDecoration(
              color: Color(0xFF3B5998), // Adjust this color as needed
            ),
          ),
          _buildDrawerItem(Icons.home, "Home", context),
          _buildDrawerItem(Icons.contacts, "Contacts", context),
          _buildDrawerItem(Icons.message, "Messages", context),
          _buildDrawerItem(Icons.person, "Profile", context),
          _buildDrawerItem(Icons.check_circle, "Whitelisted Contacts", context),
          _buildDrawerItem(Icons.block, "Blacklisted Contacts", context),
          _buildDrawerItem(Icons.folder, "Quarantine Folder", context),
          _buildDrawerItem(Icons.settings, "Customisable Filtering Settings", context),
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

  ListTile _buildDrawerItem(IconData icon, String title, BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer on tap
      },
    );
  }
}
