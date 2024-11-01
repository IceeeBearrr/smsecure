import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smsecure/Pages/Home/HomePage.dart';
import 'package:smsecure/firebase_options.dart';
import 'package:telephony/telephony.dart';
import 'package:smsecure/Pages/Login/CustLogin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final Telephony telephony = Telephony.instance;

  // Request permissions before proceeding
  bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

  if (permissionsGranted ?? false) {
    runApp(const MyApp());
  } else {
    print("Permissions not granted.");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F3),
          foregroundColor: Color(0xFF113953),
        ),
      ),
      home: _decideInitialScreen(),
    );
  }

  Widget _decideInitialScreen() {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data == true) {
          return FutureBuilder<String?>(
            future: _getUserID(),
            builder: (context, userIdSnapshot) {
              if (userIdSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (userIdSnapshot.hasData && userIdSnapshot.data != null) {
                return HomePage(userID: userIdSnapshot.data!);
              } else {
                return const Custlogin();
              }
            },
          );
        } else {
          return const Custlogin();
        }
      },
    );
  }

  Future<bool> _isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<String?> _getUserID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userID');
  }
}
