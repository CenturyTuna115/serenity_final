import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static void initialize(BuildContext context) {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }

      if (message.data['type'] == 'call') {
        _handleMessage(message, context);
      }
    });

    // Handle when app is opened from terminated state
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message, context);
      }
    });

    // Handle when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message, context);
    });
  }

  static void _handleMessage(RemoteMessage message, [BuildContext? context]) {
    if (message.data['type'] == 'call') {
      // Handle call notification
      String doctorId = message.data['doctorId'];
      String doctorName = message.data['doctorName'];
      String channelId = message.data['channelId'];

      if (context == null) return;
      // Navigate to call screen
      Navigator.of(context).pushNamed('/call', arguments: {
        'channelId': channelId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'isIncoming': true
      });
    }
  }

  static Future<String?> getDeviceToken() async {
    return await _firebaseMessaging.getToken();
  }
}
