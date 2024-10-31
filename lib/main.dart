import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Home/HomePage.dart';
import 'package:smsecure/Pages/CustomNavigationBar.dart';
import 'package:smsecure/firebase_options.dart';
import 'package:telephony/telephony.dart';

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
      initialRoute: '/',
      routes: {
        "/": (context) => const Customnavigationbar(),
        "/home": (context) => const HomePage(),
      },
    );
  }
}
