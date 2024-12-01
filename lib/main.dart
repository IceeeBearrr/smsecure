import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:smsecure/Pages/BlacklistContact/BlacklistPage.dart';
import 'package:smsecure/Pages/Home/HomePage.dart';
import 'package:smsecure/Pages/Home/push_notification_service.dart';
import 'package:smsecure/Pages/Login/CustLogin.dart';
import 'package:smsecure/Pages/Messages/Messages.dart';
import 'package:smsecure/Pages/Notification.dart';
import 'package:smsecure/Pages/QuarantineFolder/QuarantineFolderPage.dart';
import 'package:smsecure/Pages/UserBanService.dart';
import 'package:smsecure/Pages/WhitelistContact/WhitelistPage.dart';
import 'package:smsecure/firebase_options.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smsecure/Pages/CustomNavigationBar.dart';
import 'package:smsecure/Pages/Contact/ContactPage.dart';
import 'package:smsecure/Pages/Profile/Profile.dart';
import 'package:smsecure/Pages/SideNavigationBar.dart';
import 'dart:io'; // To exit the app

// Initialize secure storage instance
const FlutterSecureStorage secureStorage = FlutterSecureStorage();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  String initialRoute = '/login';
  String? phone = await secureStorage.read(key: 'userPhone');
  if (phone != null) {
    final QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('smsUser')
        .where('phoneNo', isEqualTo: phone)
        .limit(1)
        .get();

    if (userSnapshot.docs.isNotEmpty && userSnapshot.docs.first.get('isBanned') == true) {
      await secureStorage.deleteAll(); // Clear credentials if banned
      initialRoute = '/login';
    } else {
      initialRoute = '/home';
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await PushNotificationService.initializeLocalNotifications();
  runApp(MyApp(initialRoute: initialRoute));
}

Future<void> _resetSecureStorage() async {
  try {
    await secureStorage.deleteAll();
  } catch (e) {
    print("Error clearing secure storage: $e");
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle the background message
  print('Handling a background message: ${message.messageId}');
}

Future<void> checkIfUserIsBanned(String phone) async {
  try {
    QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('smsUser')
        .where('phoneNo', isEqualTo: phone)
        .limit(1)
        .get();

    if (userSnapshot.docs.isNotEmpty && userSnapshot.docs.first.get('isBanned') == true) {
      // Clear stored credentials first
      await secureStorage.deleteAll();
      
      if (navigatorKey.currentContext != null) {
        await showDialog(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: const Text(
                  'Account Banned',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block,
                      color: Colors.red,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Your account has been banned due to malicious behavior.\n\n'
                      'The application will now close.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('OK'),
                    onPressed: () {
                      if (Platform.isAndroid) {
                        SystemNavigator.pop();
                      } else if (Platform.isIOS) {
                        exit(0);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      }
      // Force return to login screen if dialog is somehow dismissed
      navigatorKey.currentState?.pushReplacementNamed('/login');
    }
  } catch (e) {
    print("Error checking if user is banned: $e");
  }
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
      navigatorKey: navigatorKey, // Add the navigatorKey here
      initialRoute: initialRoute,
      routes: {
        '/home': (context) => const MainApp(),
        '/login': (context) => const Custlogin(),
        '/profile': (context) => const ProfilePage(),
        '/contact': (context) => const ContactPage(),
        '/messages': (context) => const Messages(),
        '/whitelist': (context) => const WhitelistPage(),
        '/blacklist': (context) => const BlacklistPage(),
        '/quarantine': (context) => const QuarantineFolderPage(),
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
  bool _isBanned = false;
  StreamSubscription<DocumentSnapshot>? _banStatusSubscription;

  void onTabChange(int index) {
    if (!_isBanned) {
      // Only allow tab changes if not banned
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeBanMonitoring();
  }

  Future<void> _initializeBanMonitoring() async {
    try {
      String? phone = await secureStorage.read(key: 'userPhone');
      if (phone != null) {
        // Initial check
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('smsUser')
            .doc(phone)
            .get();

        if (userDoc.exists && userDoc.get('isBanned') == true) {
          setState(() => _isBanned = true);
        }

        // Start real-time monitoring
        UserBanService.startMonitoringBanStatus(phone, context);
      }
    } catch (e) {
      print("Error initializing ban monitoring: $e");
    }
  }

  @override
  void dispose() {
    UserBanService.stopMonitoringBanStatus();
    super.dispose();
  }

  final List<Widget> _screens = [
    const HomePage(),
    const ContactPage(),
    const Messages(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          drawer: SideNavigationBar(
            onMenuItemTap: (index) {
              if (!_isBanned) {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
          ),
          onDrawerChanged: (isOpen) {
            if (!_isBanned) {
              setState(() {
                _isDrawerOpen = isOpen;
              });
            }
          },
          appBar: AppBar(
            actions: [
              if (!_isBanned)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: () {
                          if (!_isBanned) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationPage(),
                              ),
                            );
                          }
                        },
                      ),
                      // Optional: Add notification badge if you want to show unread count
                      Positioned(
                        right: 0,
                        top: 8,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('notification')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();

                            int unreadCount = 0;
                            // Get the user ID and calculate unread notifications
                            // Note: You'll need to implement this logic based on your needs

                            return unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : const SizedBox();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: AbsorbPointer(
            absorbing: _isBanned, // Prevent interactions if banned
            child: _screens[_selectedIndex],
          ),
          bottomNavigationBar: _isDrawerOpen || _isBanned
              ? null
              : Customnavigationbar(
                  selectedIndex: _selectedIndex,
                  onTabChange: onTabChange,
                ),
        ),
        if (_isBanned)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.block,
                      color: Colors.red,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Account Banned',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Your account has been banned due to malicious behavior.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
