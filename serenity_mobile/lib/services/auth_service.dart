import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:serenity_mobile/main.dart';
import 'package:serenity_mobile/resources/common/toast.dart';
import 'package:serenity_mobile/screens/incoming_call_screen.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _channelSubscription;
  late FlutterLocalNotificationsPlugin _notifications;

  AuthService() {
    initializeFirebase();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    _notifications = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Make sure this "await" is not throwing any errors.
    await _notifications.initialize(initializationSettings);

    print("FlutterLocalNotificationsPlugin initialized successfully.");
  }

  Future<void> _showCallNotification(String callerName, String callType) async {
    print(
        "Inside _showCallNotification: callerName = $callerName, callType = $callType");
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'incoming_calls',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      threadIdentifier: 'incoming_calls',
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notifications.show(
      0,
      'Incoming ${callType == 'audio' ? 'Voice' : 'Video'} Call',
      '$callerName is calling you',
      platformChannelSpecifics,
    );
  }

  Future<void> dispose() async {
    await _channelSubscription?.cancel();
  }

  Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
  }

  Future<User?> signUpWithEmailAndPassword(
      String email,
      String password,
      String username,
      String fullName,
      String phoneNumber,
      String condition) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = credential.user;

      if (user != null) {
        await _database.child('administrator/users').child(user.uid).set({
          'email': email,
          'username': username,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'condition': condition,
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showToast(message: 'The email address is already in use.');
      } else {
        showToast(message: 'An error occurred: ${e.code}');
      }
    }
    return null;
  }

  Future<String?> getUserId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot =
        await _database.child('administrator/users').child(user.uid).get();
    if (snapshot.exists) {
      return snapshot.child('userId').value as String?;
    }
    return null;
  }

// In your AuthService.dart:
  void listenForChannelsForPatient(
    Function(Map<String, dynamic>) onNewChannel,
    Function(Map<String, dynamic>)? onStatusUpdate,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No current user, listener not started.");
      return;
    }

    final String patientUid = user.uid;
    print("Listening for channels for patient: $patientUid");

    await _channelSubscription?.cancel();

    // Listen for NEW channels.
    _channelSubscription = _database
        .child('agoraChannels')
        .orderByChild('patientId')
        .equalTo(patientUid)
        .onChildAdded
        .listen((DatabaseEvent event) {
      _handleChannelEvent(event, onNewChannel);
    });

    // Listen for status updates.
    _database
        .child('agoraChannels')
        .orderByChild('patientId')
        .equalTo(patientUid)
        .onChildChanged
        .listen((DatabaseEvent event) {
      if (onStatusUpdate != null) {
        _handleChannelEvent(event, onStatusUpdate);
      }
    });
  }

  void _handleChannelEvent(
    DatabaseEvent event,
    Function(Map<String, dynamic>) callback,
  ) {
    if (!event.snapshot.exists) {
      print("No snapshot data for this event.");
      return;
    }

    final data = Map<String, dynamic>.from(
      event.snapshot.value as Map<dynamic, dynamic>,
    );
    print(
        "Channel event received for key: ${event.snapshot.key}, status: ${data['status']}");

    if (data['status'] == 'connecting') {
      final callerName = data['callerName'] as String?;
      final callType = data['callType'] as String? ?? 'video';
      if (callerName != null) {
        print(
            "Call is connecting, showing notification for caller: $callerName, type: $callType");
        _showCallNotification(callerName, callType);
      } else {
        print("No callerName found in the data.");
      }
      // Immediately push the IncomingCallScreen regardless of the current screen.
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            doctorAvatar: data['doctorAvatar'] ?? '',
            doctorName: data['callerName'] ?? 'Unknown Caller',
            channelId: data['channelName'] ?? '',
            token: data['token'] ?? '',
            patientId: FirebaseAuth.instance.currentUser!.uid,
          ),
        ),
      );
    }
    callback(data);
  }

  Future<User?> loginWithEmailOrUsernameOrPhone(
      String identifier, String password) async {
    try {
      UserCredential? userCredential;

      if (identifier.contains('@')) {
        userCredential = await _auth.signInWithEmailAndPassword(
            email: identifier, password: password);
      } else {
        final snapshot = await _database.child('administrator/users').get();

        if (snapshot.exists) {
          Map<String, dynamic>? userData;
          String? userId;

          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            final userMap = value as Map<dynamic, dynamic>;
            if (userMap['username'] == identifier) {
              userData = Map<String, dynamic>.from(userMap);
              userId = key as String;
            }
          });

          if (userData != null && userId != null) {
            userCredential = await _auth.signInWithEmailAndPassword(
                email: userData!['email'], password: password);
          } else {
            throw FirebaseAuthException(
                code: 'user-not-found',
                message: 'No user found for that identifier.');
          }
        } else {
          throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No users found in the database.');
        }
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors with custom messages
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = "The email address is badly formatted.";
          break;
        case 'user-disabled':
          errorMessage = "This user account has been disabled.";
          break;
        case 'user-not-found':
          errorMessage = "No user found with these credentials.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password. Please try again.";
          break;
        case 'too-many-requests':
          errorMessage =
              "Too many unsuccessful attempts. Please try again later.";
          break;
        case 'network-request-failed':
          errorMessage = "Network error. Please check your connection.";
          break;
        default:
          errorMessage = "An unknown error occurred. Please try again.";
      }

      showToast(message: errorMessage);
      return null;
    } catch (e) {
      // Handle any other types of exceptions that are not Firebase-specific
      showToast(message: "An unexpected error occurred. Please try again.");
      return null;
    }
  }
}
