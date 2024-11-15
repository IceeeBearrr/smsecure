import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SetNewPassword extends StatefulWidget {
  final String phone;
  const SetNewPassword({super.key, required this.phone});

  @override
  _SetNewPasswordState createState() => _SetNewPasswordState();
}

class _SetNewPasswordState extends State<SetNewPassword> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _updatePassword(String newPassword) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: widget.phone)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;

        await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(docId)
            .update({'password': newPassword});

        _showMessageDialog(
          context,
          'Success',
          'Password updated successfully!',
          isSuccess: true,
        );
      } else {
        _showMessageDialog(
          context,
          'Error',
          'Phone number not found. Please try again.',
        );
      }
    } catch (e) {
      _showMessageDialog(
        context,
        'Error',
        'Failed to update password: $e',
      );
    }
  }

  Future<void> _showMessageDialog(
      BuildContext context, String title, String message,
      {bool isSuccess = false}) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (route) => false);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _validateAndUpdatePassword() {
    if (_formKey.currentState!.validate()) {
      final newPassword = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (newPassword == confirmPassword) {
        _updatePassword(newPassword);
      } else {
        _showMessageDialog(
          context,
          'Error',
          'Passwords do not match. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 110),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    "Set a new password",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 40.0),
                  child: Text(
                    "Create a new password, ensure it differs from previous ones for security",
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),

                // Password Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "Enter your new password",
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'Password must contain at least one uppercase letter';
                      }
                      if (!RegExp(r'[a-z]').hasMatch(value)) {
                        return 'Password must contain at least one lowercase letter';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'Password must contain at least one digit';
                      }
                      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_]').hasMatch(value)) {
                        return 'Password must contain at least one special character';
                      }
                      return null;
                    },
                  ),
                ),

                // Confirm Password Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "Re-enter password",
                      labelStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: const Icon(Icons.lock, color: Colors.black38),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.black38,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text.trim()) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ),

                // Update Password Button
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _validateAndUpdatePassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Update Password",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
