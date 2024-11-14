import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/Settings/Account/ForgotPasswordAccount/SetNewPassword.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  _ChangePasswordState createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isPasswordVisible = false;

  Future<void> _showMessageDialog(
      BuildContext context, String title, String message,
      {bool isSuccess = false, String? phoneNo}) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (isSuccess && phoneNo != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SetNewPassword(phone: phoneNo),
                    ),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verifyPassword(String enteredPassword) async {
    try {
      // Retrieve the phone number from secure storage
      final storedPhoneNo = await _secureStorage.read(key: 'userPhone');

      if (storedPhoneNo != null) {
        // Query Firestore to get the current password for the stored phone number
        final querySnapshot = await FirebaseFirestore.instance
            .collection('smsUser')
            .where('phoneNo', isEqualTo: storedPhoneNo)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final currentPassword = querySnapshot.docs.first['password'];

          // Check if the entered password matches the current password
          if (enteredPassword == currentPassword) {
            // Password matches, navigate to SetNewPassword
            await _showMessageDialog(
              context,
              'Success',
              'Password verified successfully!',
              isSuccess: true,
              phoneNo: storedPhoneNo,
            );
          } else {
            // Show error if passwords do not match
            await _showMessageDialog(
              context,
              'Error',
              'Incorrect password. Please try again.',
            );
          }
        } else {
          await _showMessageDialog(
            context,
            'Error',
            'Phone number not found in the database.',
          );
        }
      } else {
        await _showMessageDialog(
          context,
          'Error',
          'Phone number not found in secure storage.',
        );
      }
    } catch (e) {
      // Handle any errors
      await _showMessageDialog(
        context,
        'Error',
        'An error occurred: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 110), // Add some top padding

                // Title Text
                const Padding(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    "Change Password",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

                // Description Text
                const Padding(
                  padding: EdgeInsets.only(bottom: 40.0),
                  child: Text(
                    "Enter your current password to proceed with changing your password.",
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),

                // Current Password Input
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "Enter your current password",
                      labelStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: const Icon(Icons.lock, color: Colors.black38),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.black38,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Continue Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: ElevatedButton(
                    onPressed: () {
                      final enteredPassword = _passwordController.text.trim();
                      if (enteredPassword.isNotEmpty) {
                        _verifyPassword(enteredPassword);
                      } else {
                        _showMessageDialog(
                          context,
                          'Error',
                          'Please enter your current password.',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                    ),
                    child: const Text(
                      "Continue",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
