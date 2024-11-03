import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smsecure/Pages/Home/HomePage.dart';
import 'package:smsecure/Pages/Login/CustLogin.dart';
import 'package:smsecure/Pages/Messages/Messages.dart';
import 'package:smsecure/firebase_options.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/CustomNavigationBar.dart';
import 'package:smsecure/Pages/Contact/ContactPage.dart';
import 'package:smsecure/Pages/Profile/Profile.dart';

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
        '/home': (context) => const MainApp(),
        '/login': (context) => const Custlogin(),
      },
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;

  void _onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _screens = [
    const HomePage(),
    // Replace with the Contacts screen if available
    const ContactPage(),
    const Messages(),
    // Replace with the Personal screen if available
    const Profile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Customnavigationbar(
        selectedIndex: _selectedIndex,
        onTabChange: _onTabChange,
      ),
    );
  }
}
