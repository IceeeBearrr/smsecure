import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/Login/ForgotPassword/ForgotPassword.dart';
import 'package:smsecure/Pages/SignUp/SignUp.dart';
import 'package:smsecure/Pages/Login/OtpVerificationCustLogin.dart';

class Custlogin extends StatefulWidget {
  const Custlogin({super.key});

  @override
  _CustloginState createState() => _CustloginState();
}

class _CustloginState extends State<Custlogin> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  Future<void> _loginUser() async {
    // Ensure the form is valid and mounted
    if (_formKey.currentState?.validate() ?? false) {
      final String phone = phoneController.text.trim();
      final String password = passwordController.text;

      try {
        // Query Firestore for matching credentials
        final QuerySnapshot result = await FirebaseFirestore.instance
            .collection('smsUser')
            .where('phoneNo', isEqualTo: phone)
            .where('password', isEqualTo: password)
            .get();

        // Check if any matching documents were found
        if (result.docs.isEmpty) {
          _showErrorDialog('Invalid phone number or password. Please try again.');
        } else if (mounted) {
          // Navigate to OTP verification screen if login is successful
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationCustLogin(
                phone: phone,
                password: password,
              ),
            ),
          );
        }
      } catch (e) {
        // Handle any errors that occur during Firestore query
        _showErrorDialog('An error occurred while logging in. Please try again later.');
        print("Error: $e"); // For debugging purposes
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    "Welcome back",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 40.0),
                  child: Text(
                    "Sign in to access your account",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
                // Phone Number Input
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Enter your phone number",
                      labelStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: const Icon(Icons.phone, color: Colors.black38),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (!RegExp(r'^\+60\d{9,10}$').hasMatch(value)) {
                        return 'Please enter in the format +60123456789';
                      }
                      return null;
                    },
                  ),
                ),
                // Password Input
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: TextFormField(
                    controller: passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "Password",
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
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                ),
                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotpasswordLogin(),
                          ),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Color.fromARGB(255, 47, 77, 129),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                // Next Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: ElevatedButton(
                    onPressed: _loginUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                    ),
                    child: const Text(
                      "Next   >",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "New Member? ",
                      style: TextStyle(color: Colors.black54),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Signup(),
                          ),
                        );
                      },
                      child: const Text(
                        "Register now",
                        style: TextStyle(
                          color: Color.fromARGB(255, 47, 77, 129),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
