import 'package:flutter/material.dart';

class Forgotpassword extends StatelessWidget {
  const Forgotpassword ({Key? key}) : super(key: key);

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
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => const OtpVerification()),
                      // );
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
