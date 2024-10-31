import 'package:flutter/material.dart';
import 'package:smsecure/Pages/SignUp/SignUp.dart';

class Custlogin extends StatelessWidget {
  const Custlogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(bottom: 40.0),
                child: Text(
                  "sign in to access your account",
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

              // Password Input
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
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

              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: TextButton(
                    onPressed: () {
                      // Navigate to Forgot Password page
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
                  onPressed: () {
                    // Login logic
                  },
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
                        MaterialPageRoute(builder: (context) => const Signup()),
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
    );
  }
}
