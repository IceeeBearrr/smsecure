// UserBanService.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class UserBanService {
  static StreamSubscription<QuerySnapshot>? _banStatusSubscription;
  static bool _isShowingBanDialog = false;
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage();

  static void startMonitoringBanStatus(String phone, BuildContext context) {
    // Cancel any existing subscription first
    stopMonitoringBanStatus();

    _banStatusSubscription = FirebaseFirestore.instance
        .collection('smsUser')
        .where('phoneNo', isEqualTo: phone)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && 
          snapshot.docs.first.get('isBanned') == true && 
          !_isShowingBanDialog) {
        _isShowingBanDialog = true;
        
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black87,
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
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
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
                      onPressed: () async {
                        // Clear stored credentials
                        await secureStorage.deleteAll();
                        
                        // Close the app
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
      }
    }, onError: (error) {
      print("Error in ban status monitoring: $error");
    });
  }

  static void stopMonitoringBanStatus() {
    _banStatusSubscription?.cancel();
    _isShowingBanDialog = false;
  }
}