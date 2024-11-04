import 'dart:convert'; // for base64 decoding
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/Profile/ProfileInformation.dart';

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? profileImageUrl;
  String? userPhone;
  String? currentSmsUserID;
  bool isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    userPhone = await secureStorage.read(key: 'userPhone');
    if (userPhone != null) {
      await _fetchUserProfile();
    }
    setState(() {
      isLoading = false; // Set loading to false after data is loaded
    });
  }

  Future<void> _fetchUserProfile() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      final QuerySnapshot findSmsUserIDSnapshot = await firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (findSmsUserIDSnapshot.docs.isNotEmpty) {
        currentSmsUserID = findSmsUserIDSnapshot.docs.first.id;

        final DocumentSnapshot userSnapshot = await firestore
            .collection('smsUser')
            .doc(currentSmsUserID)
            .get();
        
        if (userSnapshot.exists) {
          final data = userSnapshot.data() as Map<String, dynamic>?;
          setState(() {
            userName = data?['name'] ?? 'User Name';
            profileImageUrl = data?['profileImageUrl']; // Get the Base64-encoded image
          });
        }
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading // Show loading indicator if isLoading is true
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 40),
                // Display profile image if available, otherwise show default CircleAvatar
                profileImageUrl != null && profileImageUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 50,
                        backgroundImage: MemoryImage(base64Decode(profileImageUrl!)),
                        backgroundColor: Colors.grey[300],
                      )
                    : CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.person, size: 60, color: Colors.white),
                      ),
                const SizedBox(height: 10),
                Text(
                  userName ?? 'User Name',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF113953),
                  ),
                ),
                const SizedBox(height: 30),

                // Profile Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
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
                        _buildProfileOption(Icons.person, 'Profile', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileInformation()));
                        }),
                        _buildProfileOption(Icons.contacts, 'Whitelisted contacts', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileInformation()));
                        }),
                        _buildProfileOption(Icons.block, 'Blacklisted contacts', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileInformation()));
                        }),
                        _buildProfileOption(Icons.folder, 'Quarantine Folder', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileInformation()));
                        }),
                        _buildProfileOption(Icons.settings, 'Customisable Filtering Settings', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileInformation()));
                        }),
                        _buildProfileOption(Icons.logout, 'Logout', color: Colors.red, onTap: () {
                          // Handle logout action
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13.0),
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
