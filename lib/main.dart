import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smsecure/Pages/Home/HomePage.dart';
import 'package:smsecure/Pages/Login/CustLogin.dart';
import 'package:smsecure/firebase_options.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// Initialize secure storage instance
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  String initialRoute = '/login';
  String? phone = await secureStorage.read(key: 'userPhone');
  if (phone != null) {
    initialRoute = '/home';
  }

  runApp(MyApp(initialRoute: initialRoute));
}


// Define the main app widget
class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

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
      initialRoute: initialRoute,
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const Custlogin(),
      },
    );
  }
}
