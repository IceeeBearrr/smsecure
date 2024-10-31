import 'package:flutter/material.dart';

class Signup extends StatelessWidget {
  const Signup({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 70.0),
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
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    'by creating a free account.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 50.0),
                ),

                // Full Name Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      labelStyle: const TextStyle(color: Colors.black38),
                      prefixIcon:
                          const Icon(Icons.person_outline, color: Colors.black38),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Email Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: const Icon(Icons.email, color: Colors.black38),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Phone Number Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Phone number',
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

                // Password Field
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: const Icon(Icons.lock, color: Colors.black38),
                      suffixIcon: const Icon(Icons.visibility_off, color: Colors.black38),
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
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: const Icon(Icons.lock, color: Colors.black38),
                      suffixIcon: const Icon(Icons.visibility_off, color: Colors.black38),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Terms and Conditions Checkbox
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (value) {}),
                      const Expanded(
                        child: Text(
                          'By checking the box you agree to our Terms and Conditions.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
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
                    onPressed: () {
                      // Registration logic
                    },
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
    );
  }
}
