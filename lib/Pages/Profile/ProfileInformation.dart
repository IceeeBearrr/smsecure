import 'dart:convert'; // for base64 decoding
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/Profile/EditProfileInformation.dart';

class ProfileInformation extends StatefulWidget {
  const ProfileInformation({super.key});

  @override
  _ProfileInformationState createState() => _ProfileInformationState();
}

class _ProfileInformationState extends State<ProfileInformation> {
  final _secureStorage = const FlutterSecureStorage();
  Map<String, dynamic>? profileData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userPhone = await _secureStorage.read(key: 'userPhone');
      if (userPhone != null) {
        print('userPhone found: $userPhone');

        final querySnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .where('phoneNo', isEqualTo: userPhone)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final smsUserID = querySnapshot.docs.first.id;
          print('smsUserID found: $smsUserID');

          final documentSnapshot = await FirebaseFirestore.instance
              .collection('smsUser')
              .doc(smsUserID)
              .get();

          if (documentSnapshot.exists) {
            print('Profile data retrieved successfully');
            setState(() {
              profileData = documentSnapshot.data();
              isLoading = false;
            });
          } else {
            print('Document does not exist');
            setState(() {
              isLoading = false;
            });
          }
        } else {
          print('No document found with the given phone number');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        print('userPhone not found in secure storage');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching profile data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getGenderText() {
    if (profileData != null && profileData!.containsKey('gender')) {
      final gender = profileData!['gender'];
      return gender != null && gender.isNotEmpty ? gender : 'Not Specified';
    }
    return 'Not Specified';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113953)),
          onPressed: () async {
            setState(() {
              isLoading = true; // Show loading indicator
            });
            await Future.delayed(const Duration(seconds: 1)); // Brief delay
            setState(() {
              isLoading = false; // Hide loading indicator
            });
            Navigator.pop(context); // Pop the screen
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileData == null
              ? const Center(child: Text('Profile information not found.'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profileData!['profileImageUrl'] != null &&
                                profileData!['profileImageUrl'].isNotEmpty
                            ? MemoryImage(base64Decode(profileData!['profileImageUrl']))
                            : null,
                        child: profileData!['profileImageUrl'] == null ||
                                profileData!['profileImageUrl'].isEmpty
                            ? const Icon(Icons.person, size: 60, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profileData!['name'] ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF113953),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Email field
                      _buildProfileField(
                        context,
                        icon: Icons.email,
                        text: profileData!['emailAddress'] ?? 'No Email',
                      ),
                      const SizedBox(height: 15),
                      // Phone field
                      _buildProfileField(
                        context,
                        icon: Icons.phone,
                        text: profileData!['phoneNo'] ?? 'No Phone Number',
                      ),
                      const SizedBox(height: 15),
                      // Gender field
                      _buildProfileField(
                        context,
                        icon: Icons.person_outline,
                        text: _getGenderText(),
                      ),
                      const SizedBox(height: 15),
                      // Birthday field
                      _buildProfileField(
                        context,
                        icon: Icons.cake,
                        text: profileData!['birthday'] ?? 'No Birthday',
                      ),
                      const SizedBox(height: 30),
                      // Edit Profile Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileInformation()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text(
                            "Edit Profile",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileField(BuildContext context, {required IconData icon, required String text}) {
    return TextFormField(
      initialValue: text,
      enabled: false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF113953)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      style: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)),
    );
  }
}
