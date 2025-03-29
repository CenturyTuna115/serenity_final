import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart'
    show DatabaseReference, FirebaseDatabase, ServerValue;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your other screens
import 'package:serenity_mobile/screens/splashScreen.dart';
import 'package:serenity_mobile/screens/voicecallscreen.dart';
import 'package:serenity_mobile/screens/incoming_call_screen.dart';
// Import your AuthService that contains the listener logic.
import 'package:serenity_mobile/services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in the background isolate.
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  await _showIncomingCallNotification(message);
}

// Global navigator key to enable navigation from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Single instance of the local notifications plugin.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _showIncomingCallNotification(RemoteMessage message) async {
  // Extract data from the FCM message.
  final callerName = message.data['callerName'] ?? 'Unknown Caller';
  final channelId = message.data['channelId'];
  final doctorAvatar = message.data['doctorAvatar'] ?? '';

  // Define Accept and Decline actions.
  final AndroidNotificationAction acceptAction = AndroidNotificationAction(
    'ACCEPT_CALL',
    'Accept',
    icon: DrawableResourceAndroidBitmap('@drawable/ic_accept_call'),
  );

  final AndroidNotificationAction declineAction = AndroidNotificationAction(
    'DECLINE_CALL',
    'Decline',
    icon: DrawableResourceAndroidBitmap('@drawable/ic_decline_call'),
  );

  // Configure Android notification details.
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'incoming_call_channel', // Channel ID
    'Incoming Calls', // Channel name
    channelDescription: 'Call notifications',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    playSound: true,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    actions: <AndroidNotificationAction>[acceptAction, declineAction],
  );

  final NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  // Show the notification.
  await flutterLocalNotificationsPlugin.show(
    999, // Unique ID for this notification
    'Incoming Call',
    '$callerName is calling...',
    platformDetails,
    payload: '$callerName|$doctorAvatar|$channelId',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request notification permissions and setup FCM token handling
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  messaging.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseDatabase.instance
            .ref('administrator/users/${user.uid}')
            .update({'fcmToken': newToken});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcmToken', newToken);
      } catch (e) {
        print('Failed to store refreshed FCM token: $e');
        await Future.delayed(Duration(seconds: 5));
        await FirebaseDatabase.instance
            .ref('administrator/users/${user.uid}')
            .update({'fcmToken': newToken});
      }
    }
  });

  final initialToken = await messaging.getToken();
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && initialToken != null) {
    try {
      await FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}')
          .update({'fcmToken': initialToken});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcmToken', initialToken);
    } catch (e) {
      print('Failed to store initial FCM token: $e');
      await Future.delayed(Duration(seconds: 5));
      await FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}')
          .update({'fcmToken': initialToken});
    }
  }

  if (user != null && initialToken == null) {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('fcmToken');
    if (storedToken != null) {
      await FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}')
          .update({'fcmToken': storedToken});
    }
  }

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (response) async {
      final payloadParts = response.payload?.split('|');
      if (response.actionId == 'ACCEPT_CALL') {
        if (payloadParts != null && payloadParts.length >= 3) {
          final callerName = payloadParts[0];
          final doctorAvatar = payloadParts[1];
          final channelId = payloadParts[2];
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                doctorAvatar: doctorAvatar,
                doctorName: callerName,
                channelId: channelId,
                patientId: '', // Retrieve actual patientId as needed.
                token: '', // You might include the token in your payload.
              ),
            ),
          );
        }
      } else if (response.actionId == 'DECLINE_CALL') {
        if (payloadParts != null && payloadParts.length >= 3) {
          final channelId = payloadParts[2];
          final dbRef = FirebaseDatabase.instance
              .ref('administrator/agoraChannels/$channelId');
          await dbRef.update({
            'status': 'ended',
            'endTimestamp': ServerValue.timestamp,
          });
        }
      } else {
        if (payloadParts != null && payloadParts.length >= 3) {
          final callerName = payloadParts[0];
          final doctorAvatar = payloadParts[1];
          final channelId = payloadParts[2];
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                doctorAvatar: doctorAvatar,
                doctorName: callerName,
                channelId: channelId,
                patientId: '',
                token: '',
              ),
            ),
          );
        }
      }
    },
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Foreground message received: ${message.messageId}");
    _showIncomingCallNotification(message);
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadDarkModePref();
    // Start listening for incoming call channels globally.
    _authService.listenForChannelsForPatient((data) {
      // When an incoming call is detected, navigate to the IncomingCallScreen.
      if (data['status'] == 'connecting') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => IncomingCallScreen(
              doctorAvatar: data['doctorAvatar'] ?? '',
              doctorName: data['callerName'] ?? 'Unknown Caller',
              channelId: data['channelName'] ?? '',
              token: data['token'] ?? '',
              patientId: FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
          ),
        );
      }
    }, null);
  }

  Future<void> _loadDarkModePref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serenity',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _darkMode
          ? ThemeData.dark().copyWith(
              primaryColor: Colors.green[800],
            )
          : ThemeData(
              primarySwatch: Colors.green,
            ),
      home: SplashScreen(),
    );
  }
}
