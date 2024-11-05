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
import 'package:smsecure/Pages/SideNavigationBar.dart';

// Initialize secure storage instance
const FlutterSecureStorage secureStorage = FlutterSecureStorage();

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
        '/profile' : (context) => const ProfilePage(),
      },
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDrawerOpen = false;

  void onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _screens = [
    const HomePage(),
    const ContactPage(),
    const Messages(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideNavigationBar(), // Add the drawer here
      onDrawerChanged: (isOpen) {
        setState(() {
          _isDrawerOpen = isOpen;
        });
      },
      appBar: AppBar(        
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Icon(Icons.notifications),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _isDrawerOpen
          ? null // Hide BottomNavigationBar when the drawer is open
          : Customnavigationbar(
              selectedIndex: _selectedIndex,
              onTabChange: onTabChange,
            ),
    );
  }
}
