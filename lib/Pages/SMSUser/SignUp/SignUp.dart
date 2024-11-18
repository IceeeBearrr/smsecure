import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/SMSUser/SignUp/OtpVerificationSignUp.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool termsAccepted = false;
  final _formKey = GlobalKey<FormState>();

  // State variables to control password visibility
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _registerUser() async {
    if (_formKey.currentState!.validate()) {
      if (!termsAccepted) {
        _showErrorDialog('Please accept the terms and conditions.');
        return;
      }

      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final password = passwordController.text;

      // Check if the phone number or email already exists in Firestore
      final QuerySnapshot emailCheck = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('emailAddress', isEqualTo: email)
          .get();

      final QuerySnapshot phoneCheck = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: phone)
          .get();

      if (emailCheck.docs.isNotEmpty || phoneCheck.docs.isNotEmpty) {
        _showErrorDialog(
            'An account with this email or phone number already exists.');
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context); // Redirect to the login page
        });
      } else {
        // Proceed to OTP verification if no existing account was found
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationSignUp(
              name: name,
              email: email,
              phone: phone,
              password: password,
            ),
          ),
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
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

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Terms and Conditions',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            height:
                400, // Set a fixed height for the modal to show the scroll bar
            width: double.maxFinite,
            child: Scrollbar(
              thumbVisibility: true, // Ensures the scroll bar is visible
              child: SingleChildScrollView(
                child: RichText(
                  textAlign: TextAlign.justify,
                  text: const TextSpan(
                    style: TextStyle(color: Colors.black, fontSize: 16),
                    children: [
                      TextSpan(
                        text: 'Welcome to SMSecure!\n\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'By using our application, you agree to the following terms and conditions:\n\n',
                      ),
                      TextSpan(
                        text: '1. User Account Responsibility:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- You are responsible for maintaining the confidentiality of your account information.\n'
                            '- You must provide accurate and up-to-date information when creating an account.\n\n',
                      ),
                      TextSpan(
                        text: '2. Usage Restrictions:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- The app must not be used for illegal, fraudulent, or malicious purposes.\n'
                            '- You agree not to attempt to reverse engineer, modify, or tamper with the app.\n\n',
                      ),
                      TextSpan(
                        text: '3. Data Privacy:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- SMSecure collects and stores user data in compliance with data protection regulations.\n'
                            '- Your personal information will not be shared with third parties without your consent.\n\n',
                      ),
                      TextSpan(
                        text: '4. Spam Filtering:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- Our app uses advanced machine learning models to filter spam messages.\n'
                            '- While we strive for accuracy, no filtering system is perfect, and legitimate messages may occasionally be flagged.\n\n',
                      ),
                      TextSpan(
                        text: '5. Limitation of Liability:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- SMSecure is not liable for any damages or losses arising from the use or inability to use the app.\n\n',
                      ),
                      TextSpan(
                        text: '6. Modifications to the Service:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- We reserve the right to update or discontinue features of the app at any time.\n\n',
                      ),
                      TextSpan(
                        text: '7. Termination of Account:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- Your account may be terminated if you violate these terms.\n\n',
                      ),
                      TextSpan(
                        text: '8. Intellectual Property:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- The app and its content are the intellectual property of SMSecure and are protected by copyright laws.\n\n',
                      ),
                      TextSpan(
                        text: '9. Updates and Notifications:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- By using SMSecure, you agree to receive notifications regarding updates, maintenance, and promotions.\n\n',
                      ),
                      TextSpan(
                        text: '10. Governing Law:\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '- These terms are governed by the laws of your jurisdiction.\n\n',
                      ),
                      TextSpan(
                        text:
                            'By continuing to use the SMSecure app, you acknowledge that you have read, understood, and agreed to these terms.\n\n',
                      ),
                      TextSpan(
                        text: 'Thank you for choosing SMSecure!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 70),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 50.0),
                    child: Text(
                      'by creating a free account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Full Name Field
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        labelStyle: const TextStyle(color: Colors.black38),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Colors.black38),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                          return 'Only letters and spaces are allowed';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Email Field
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.black38),
                        prefixIcon:
                            const Icon(Icons.email, color: Colors.black38),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Phone Number Field
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        labelStyle: const TextStyle(color: Colors.black38),
                        prefixIcon:
                            const Icon(Icons.phone, color: Colors.black38),
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

                  // Password Field
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: TextFormField(
                      controller: passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.black38),
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.black38),
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
                        if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_]')
                            .hasMatch(value)) {
                          return 'Password must contain at least one special character';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Confirm Password Field
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: TextFormField(
                      controller: confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: const TextStyle(color: Colors.black38),
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.black38),
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
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Terms and Conditions Checkbox
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: termsAccepted,
                          onChanged: (value) {
                            setState(() {
                              termsAccepted = value!;
                            });
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsAndConditions,
                            child: const Text(
                              'By checking the box, you agree to our Terms and Conditions.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration
                                    .underline, // Underline the text
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Next Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _registerUser,
                      child: const Text(
                        'Next   >',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already a member? ',
                        style: TextStyle(color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Navigate back to Login Page
                        },
                        child: const Text(
                          'Log In',
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
      ),
    );
  }
}
