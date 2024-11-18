import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smsecure/Pages/SMSUser/Login/ForgotPassword/ForgotPasswordOTP.dart';

class ForgotpasswordLogin extends StatefulWidget {
  const ForgotpasswordLogin({super.key});

  @override
  _ForgotpasswordLoginState createState() => _ForgotpasswordLoginState();
}

class _ForgotpasswordLoginState extends State<ForgotpasswordLogin> {
  final TextEditingController _phoneController = TextEditingController();

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
                Navigator.of(context).pop();
                if (isSuccess) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ForgotPasswordOTPLogin(
                          phone: _phoneController.text.trim()),
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

  Future<void> _handleContinue() async {
    final phoneNumber = _phoneController.text.trim();

    // Validate the phone number format
    if (phoneNumber.isEmpty || !RegExp(r'^\+60\d{9,10}$').hasMatch(phoneNumber)) {
      await _showMessageDialog(context, 'Invalid Phone Number',
          'Please enter a valid phone number in the format +60123456789.');
      return;
    }

    try {
      // Check if the phone number exists in the smsUser collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: phoneNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Phone number exists, navigate to ForgotPasswordOTPLogin.dart
        await _showMessageDialog(context, 'Phone Number Found',
            'We found your phone number. Proceeding to OTP verification...',
            isSuccess: true);
      } else {
        // Phone number does not exist, show error dialog
        await _showMessageDialog(context, 'Phone Number Not Found',
            'The entered phone number does not exist in our records. Please check and try again.');
      }
    } catch (e) {
      // Handle any errors that occur during Firestore query
      await _showMessageDialog(context, 'Error',
          'An error occurred while checking the phone number. Please try again later.');
      debugPrint('Error checking phone number: $e');
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

                // Image Banner
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Image.asset(
                    'images/HomePage/forgotPasswordBanner.png',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),

                // Title Text
                const Padding(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    "Forgot Password",
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
                    "Please enter your phone number. An OTP will be sent to you via SMS for verification.",
                    textAlign: TextAlign.justify,
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
                    controller: _phoneController,
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

                // Continue Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: ElevatedButton(
                    onPressed: _handleContinue, // Call the function on press
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
