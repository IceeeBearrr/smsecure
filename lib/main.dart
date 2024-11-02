import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smsecure/Pages/Home/HomePage.dart';
import 'package:smsecure/firebase_options.dart';
import 'package:telephony/telephony.dart';
import 'package:smsecure/Pages/Login/CustLogin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run the app while checking permissions and login state
  runApp(MyApp());
}

// Initialize secure storage instance
final FlutterSecureStorage secureStorage = FlutterSecureStorage();

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Telephony telephony = Telephony.instance;
  String initialRoute = '/login';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request SMS permissions
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted ?? false) {
      initialRoute = await _determineInitialRoute();
    } else {
      print("Permissions not granted.");
      // Consider showing an in-app dialog here to prompt the user
    }
    if (mounted) {
      setState(() {}); // Trigger rebuild after permissions and route determination
    }
  }

  Future<String> _determineInitialRoute() async {
    String? phone = await secureStorage.read(key: 'userPhone');
    return phone != null ? '/home' : '/login';
  }

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
        '/home': (context) => FutureBuilder<String?>(
              future: _getUserPhone(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasData && snapshot.data != null) {
                  return const HomePage();
                } else {
                  return const Custlogin();
                }
              },
            ),
        '/login': (context) => const Custlogin(),
      },
    );
  }

  Future<String?> _getUserPhone() async {
    return await secureStorage.read(key: 'userPhone');
  }
}
