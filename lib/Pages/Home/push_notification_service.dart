import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? userPhone;
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> initialize() async {
    // Request permissions
    await _firebaseMessaging.requestPermission();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      sound: true,
    );
    // Get the device token
    String? token = await _firebaseMessaging.getToken();
    print("Device Token: $token");
  }

  static Future<String> getServerAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "smsecure",
      "private_key_id": "d4a7562bc7f6e965215c4303c8ceb96bf6b4da92",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQClhkcx+JKGWPlV\ncCKt7S08Ca+ey8s9hQkBjk8Q0QVaUUp33AlHLKTb/2rY/Pe8KtRjOkgnwHPjtOnU\n+DEp3g2PoVCQ4vJacZmSv40Ghkk33UBB3FsZrbDjgwAhGcZ9bVwobRtjdHlYiNT4\nXpbC4hgeJPVgNM6PSPkCicaxpUVV2HnKdiezL0FXGFD4EFq7OwOw+U4zDSI4Wlqd\n/uK+yTW7TYNxpMJ3CHQc2BVP9Nt91/6rMoGMOYofgVjwTLhNQ/7z/OTuxlgQ+CQe\nW5wydj3nfM7mcYlllodSyc4qs5JYJy41aFD3f4gcF/MxXqF21VLLZ3OhimQ1rRkJ\n9wLU44NLAgMBAAECggEAAQ1L6YjjYYAyQXU/eyx9M5r6Jz+zUHZGeuCNJxW0+4B1\nwTJAStgBSjai1rMw3dzF0cWejMYf1mwhak2TfmkfW/DSAsG2eZWsPK8D9e0njPfW\nfzSnzY95htCf0RYJWWW3Bri+ylCErufbtqJfQejO724bsxtSzr1Pe9ElVp6uxJ9j\ncxrzJqOCmTX1Ozrz2RcbxF5ryWkw4ex3VXLv9NQvO1hOu6iNecK6FK6+MuC3RPBB\nhzI4WGMzjKhKOl3rVn3PV344R/NC8tIoKjxxL61WEYrdBMb+bDns1LEb8tW4e5pc\nAwWt/DdOlF7j5kz5qoZU79hUYrt0ygsjwVwrGr/kQQKBgQDdq/dZgS2fjff+zkMj\npEKCdVz8PKjCg/7ETjR04KlWJ7brVSXudC/6tZqdb3HdCtyNU4EatjwAn/POeBwj\nIqWNGSsuRlHM/vsqIwdypiFisZlR43VESmv8L2QHoZ/3CQpaoKUKqfThP2d7+Ihv\nwHxGnFZpOWjGSI40nsfN5ooTiwKBgQC/KGQ33CoNhSxXlFRjoBBBoYa2QMcmx4E6\nyBg9dFGfU/K+PYK9sPkl3fmfcork2LDIptRpOnTRMPoYqeK0Qs59WMih9n015CHd\nKL8ojYwGAMN9O4ZxOa9FnIUJQknOvYnbB5V6nKa+arDqCx9bghqvQ35OSX8HpUA0\n7/6r6ltHQQKBgAOV2HZWJIrEHRK9+1AERB8gDtT1ljUvNVuveCG70IFYOxkrU2W7\n81q2vT12o/zTRCX1B82KzQWlkKfyQWJAGTVjBtPEx2XtadqQnno4Pan+/V/Zsffc\nzEpT6eZFsvSn7Mbyejjl7tQF1oKmzm4gSuJJfQxOpWcvnT00pD6sT+dpAoGBAKa4\njMfnfsnx952e4gdOCD+lqH92efuJj118PSAEPlgu+I0RyuC05GgxdNCrLxavI2it\nkJ8Ce/YjuE0ghnhfuAa9E6em+sew5BQmwKqW4aQusFGeRACmpgaZn7JWnVbyGrTs\npWOeExQKq6hE8SF3lNx9ikCve1pot1o0YzL/oILBAoGATjKvXTg6EKhVXl/A3x8Y\nkh9owvexWctBP1yJWboN94HpMWU3+slNjAyuSF1grjq+v44SQ0IGOGP1DGCd+4Xy\nYOMO4yxH+Lto1rXhFKl55JUXTO1QaqlmKE0VAe84vgc5GghrDjtIi9opPjagib4z\niiOgRNZ3xtKfm3cJFyP3VPI=\n-----END PRIVATE KEY-----\n",
      "client_email":
          "firebase-adminsdk-v4lnw@smsecure.iam.gserviceaccount.com",
      "client_id": "117746177453697057097",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-v4lnw%40smsecure.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    List<String> scopes = [
      "https://www.googleapis.com/auth/firebase.messaging",
      "https://www.googleapis.com/auth/firebase.database",
    ];

    http.Client client = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
    );

    // Get Access Token
    auth.AccessCredentials credentials =
        await auth.obtainAccessCredentialsViaServiceAccount(
            auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
            scopes,
            client);
    client.close();
    print("log server access token: ${credentials.accessToken.data}");
    return credentials.accessToken.data;
  }

  Future<String?> getDeviceToken() async {
    try {
      String? deviceToken = await _firebaseMessaging.getToken();
      print("Device Token: $deviceToken");
      return deviceToken;
    } catch (e) {
      print("Error fetching device token: $e");
      return null;
    }
  }

  Future<void> saveDeviceToken(String deviceToken) async {
    String? userPhone = await secureStorage.read(key: "userPhone") ?? "";

    try {
      // Fetch the document(s) matching the query
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Get the first document reference
        DocumentReference documentRef = snapshot.docs.first.reference;

        // Update the document with the deviceToken
        await documentRef.update({'deviceToken': deviceToken});
        print("Device token saved successfully.");
      } else {
        print("No user found with the phone number: $userPhone");
      }
    } catch (error) {
      print("Error saving device token: $error");
    }
  }

  static sendNotification({
    required String deviceToken,
    required String message,
  }) async {
    final String serverToken = await getServerAccessToken();
    print("Server Token: $serverToken");

    // You will get Project Id from google-services.json
    String endpointFCM =
        "https://fcm.googleapis.com/v1/projects/smsecure/messages:send";
    final Map<String, dynamic> bodyMessage = {
      'message': {
        'token': deviceToken,
        'notification': {
          'title': 'Smsecure',
          'body': message,
        },
        'android': {
          'priority': 'HIGH',
        },
        'data': {}
      }
    };

    print("Payload being sent: ${jsonEncode(bodyMessage)}");

    try {
      final http.Response response = await http.post(
        Uri.parse(endpointFCM),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $serverToken',
        },
        body: jsonEncode(bodyMessage),
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("Sent Notification successfully");
      } else {
        print("Failed Notification. Response: ${response.body}");
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  static Future<void> sendNotificationToUser({
    required String smsUserID,
    required String senderName,
    required String senderPhone,
    required String messageContent,
  }) async {
    try {
      // Retrieve the device token from Firestore using the smsUserID
      final snapshot = await FirebaseFirestore.instance
          .collection('smsUser')
          .doc(smsUserID)
          .get();

      final String? deviceToken =
          snapshot.data()?['deviceToken']; // Safely handle null

      if (deviceToken == null || deviceToken.isEmpty) {
        print("Device token not found for user $smsUserID");
        return;
      }

      // Logic to determine the sender information
      String senderInfo = senderName == "Unknown" ? senderPhone : senderName;

      // Construct the notification title
      String notificationTitle = "New Message from $senderInfo";

      // Send the notification
      await PushNotificationService.sendNotification(
        deviceToken: deviceToken,
        message: "$notificationTitle\n$messageContent",
      );

      print("Notification sent successfully to user $smsUserID");
    } catch (error) {
      print("Error sending notification to user $smsUserID: $error");
    }
  }

  static Future<void> sendForegroundNotification({
    required String title,
    required String body,
  }) async {
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
      DateTime.now().millisecondsSinceEpoch ~/
          1000, // Unique ID for the notification
      title,
      body,
      notificationDetails,
    );
  }
}
