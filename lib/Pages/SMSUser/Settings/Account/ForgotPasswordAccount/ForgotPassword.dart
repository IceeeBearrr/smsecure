import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/SMSUser/Settings/Account/ForgotPasswordAccount/ForgotPasswordOTP.dart';

class Forgotpassword extends StatefulWidget {
  const Forgotpassword({super.key});

  @override
  _ForgotpasswordState createState() => _ForgotpasswordState();
}

class _ForgotpasswordState extends State<Forgotpassword> {
  final TextEditingController _phoneController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> _showMessageDialog(BuildContext context, String title, String message, {bool isSuccess = false}) async {
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
                      builder: (context) => ForgotPasswordOTP(phone: _phoneController.text.trim()),
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

  Future<void> _verifyPhoneNumber(String enteredPhoneNo) async {
    try {
      // Retrieve the phone number stored in secure storage
      final storedPhoneNo = await _secureStorage.read(key: 'userPhone');

      if (storedPhoneNo != null && enteredPhoneNo == storedPhoneNo) {
        // Show success dialog
        await _showMessageDialog(context, 'Success', 'Phone number verified successfully!', isSuccess: true);
      } else {
        // Show error dialog
        await _showMessageDialog(context, 'Error', 'Phone number does not match. Please try again.');
      }
    } catch (e) {
      // Handle any errors
      await _showMessageDialog(context, 'Error', 'An error occurred while verifying the phone number: $e');
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
                    "please enter your phone number, an OTP will be sent to you via SMS for verification",
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),

                // Phone Number Input
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: TextField(
                    controller: _phoneController,
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
                  ),
                ),

                // Continue Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: ElevatedButton(
                    onPressed: () {
                      final enteredPhoneNo = _phoneController.text.trim();
                      if (enteredPhoneNo.isNotEmpty) {
                        _verifyPhoneNumber(enteredPhoneNo);
                      } else {
                        _showMessageDialog(context, 'Error', 'Please enter a valid phone number.');
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
