import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:smsecure/Pages/Home/push_notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _doNotDisturb = false;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  String? _smsUserID;
  final PushNotificationService _pushNotificationService =
      PushNotificationService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeUserData();
    _setupFirebaseForegroundHandler();
    _initializeLocalNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDoNotDisturbStatus();
    });
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print(
            'Foreground notification received: ${message.notification?.title}');
        // Handle the notification (e.g., show a dialog or update the UI)
      }
    });

    // Optional: Handle message taps (background or terminated state)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened: ${message.notification?.title}');
      // Navigate to a specific screen or perform any action
    });

    final pushNotificationService = PushNotificationService();
    pushNotificationService.getDeviceToken().then((deviceToken) {
      if (deviceToken != null) {
        pushNotificationService.saveDeviceToken(deviceToken);
      } else {
        print("Failed to retrieve device token.");
      }
    });
  }

  @override
  void dispose() {
    // Save current state when leaving the page
    if (_smsUserID != null) {
      _firestore
          .collection('smsUser')
          .doc(_smsUserID)
          .update({'doNotDisturb': _doNotDisturb}).catchError(
              (e) => debugPrint('Error saving DND state: $e'));
    }
    super.dispose();
  }

  void _initializeLocalNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _setupFirebaseForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print(
            'Foreground notification received: ${message.notification?.title}');
        _showLocalNotification(message.notification);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped: ${message.notification?.title}');
      // Handle what happens when the user taps on the notification
    });
  }

  Future<void> _showLocalNotification(RemoteNotification? notification) async {
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'foreground_channel', // Channel ID
      'Foreground Notifications', // Channel Name
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
    );
  }

  Future<void> _initializeUserData() async {
    await _getUserID();
    if (_smsUserID != null) {
      _fetchDoNotDisturbStatus();
      _setupNotificationListener();
    }
  }

  Future<void> _getUserID() async {
    try {
      final userPhone = await _secureStorage.read(key: 'userPhone');
      if (userPhone == null) {
        debugPrint("userPhone is null");
        return;
      }

      QuerySnapshot snapshot = await _firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _smsUserID = snapshot.docs.first.id;
        });
        debugPrint("Found smsUserID: $_smsUserID");
      }
    } catch (e) {
      debugPrint('Error getting user ID: $e');
    }
  }

// Your current code for fetching doNotDisturb status doesn't check if the field exists
  Future<void> _fetchDoNotDisturbStatus() async {
    try {
      if (_smsUserID == null) return;

      DocumentSnapshot userDoc =
          await _firestore.collection('smsUser').doc(_smsUserID).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (!data!.containsKey('doNotDisturb')) {
          // Create the field if it doesn't exist
          await _firestore
              .collection('smsUser')
              .doc(_smsUserID)
              .update({'doNotDisturb': false});
        }
        setState(() {
          _doNotDisturb = data['doNotDisturb'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching do not disturb status: $e');
    }
  }

  Future<void> _updateDoNotDisturbStatus(bool value) async {
    try {
      if (_smsUserID == null) return;

      // Update Firestore
      await _firestore
          .collection('smsUser')
          .doc(_smsUserID)
          .update({'doNotDisturb': value});

      // Update local state
      setState(() {
        _doNotDisturb = value;
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              value ? 'Do not disturb turned on' : 'Do not disturb turned off'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error updating do not disturb status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update do not disturb status'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _setupNotificationListener() {
    if (_smsUserID == null) return;

    _firestore
        .collection('notification')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      List<Map<String, dynamic>> notifications = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'adminName': doc['adminName'],
          'content': doc['content'],
          'timestamp': doc['timestamp'],
          'seenBy': List<dynamic>.from(doc['seenBy'] ?? []),
        };
      }).toList();

      // Handle new notifications - ONLY for unread messages
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          List<dynamic> seenBy = List<dynamic>.from(data['seenBy'] ?? []);

          // Only show notification if:
          // 1. Do Not Disturb is off
          // 2. User hasn't seen this notification yet
          if (!_doNotDisturb && !seenBy.contains(_smsUserID)) {
            // Send FCM notification
            PushNotificationService.sendNotificationToUser(
              smsUserID: _smsUserID!,
              senderName: data['adminName'] ?? 'System',
              senderPhone: '',
              messageContent: data['content'] ?? '',
            );

            // Send local notification for foreground
            PushNotificationService.sendForegroundNotification(
              title: data['adminName'] ?? 'New Notification',
              body: data['content'] ?? '',
            );
          }
        }
      }

      int unreadCount = notifications
          .where((notification) =>
              !(notification['seenBy'] as List<dynamic>).contains(_smsUserID))
          .length;

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
      });
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      if (_smsUserID == null) return;

      WriteBatch batch = _firestore.batch();
      QuerySnapshot querySnapshot =
          await _firestore.collection('notification').get();

      for (DocumentSnapshot doc in querySnapshot.docs) {
        List<dynamic> seenBy = List<dynamic>.from(doc['seenBy'] ?? []);
        if (!seenBy.contains(_smsUserID)) {
          seenBy.add(_smsUserID);
          batch.update(doc.reference, {'seenBy': seenBy});
        }
      }

      await batch.commit();

      // Update local state
      setState(() {
        _notifications = _notifications.map((notification) {
          List<dynamic> seenBy = List<dynamic>.from(notification['seenBy']);
          if (!seenBy.contains(_smsUserID)) {
            seenBy.add(_smsUserID);
          }
          return {
            ...notification,
            'seenBy': seenBy,
          };
        }).toList();
        _unreadCount = 0;
      });
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Switch(
            value: _doNotDisturb,
            onChanged: _updateDoNotDisturbStatus,
          ),
          const SizedBox(width: 8),
          Center(
            child: Text(
              'Do not disturb',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        elevation: 0,
                        color: Colors.white, // Add this line

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(
                            backgroundColor: Color.fromARGB(255, 124, 156, 180),
                            child: Icon(
                              Icons.notifications,
                              color: Color(0xFF113953),
                            ),
                          ),
                          title: Text(
                            notification['content'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Text(
                                  _formatTimestamp(notification['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'by ${notification['adminName']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _markAllAsRead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF113953),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
