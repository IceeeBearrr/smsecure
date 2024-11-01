import 'package:flutter/material.dart';
import 'package:smsecure/Pages/ForgotPassword/SetPasswordSuccess.dart';

class SetNewPassword extends StatelessWidget {
  const SetNewPassword({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child:  SingleChildScrollView( // Allows the screen to scroll when keyboard appears
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 110), // Add some top padding
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
                  "create a new password, ensure it differs from previous ones for security",
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
                child: TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Enter your new password",
                    labelStyle: const TextStyle(color: Colors.black38),
                    prefixIcon: const Icon(Icons.lock, color: Colors.black38),
                    suffixIcon:
                        const Icon(Icons.visibility_off, color: Colors.black38),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Confirm Password Field
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Re-enter password",
                    labelStyle: const TextStyle(color: Colors.black38),
                    prefixIcon: const Icon(Icons.lock, color: Colors.black38),
                    suffixIcon:
                        const Icon(Icons.visibility_off, color: Colors.black38),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Update Password Button
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SetPasswordSuccess()),
                      );
                    },
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
    );
  }
}
