import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serenity_mobile/screens/splashScreen.dart';

// A top-level background message handler (required for FCM in background/terminated)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in the background isolate
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  // Show an "Incoming Call" notification even in background
  await _showIncomingCallNotification(message);
}

// Create a single instance of the local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 1) Request notification permissions
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  // 2) Register the background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3) Initialize flutter_local_notifications (Android-only in this example)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    // iOS: iOS initialization omitted since you said Android-only
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    // 4) Handle taps on the notification or action buttons
    onDidReceiveNotificationResponse: (response) {
      if (response.actionId == 'ACCEPT_CALL') {
        print("User tapped ACCEPT_CALL");
        // TODO: Navigate to your call screen or handle accept logic
      } else if (response.actionId == 'DECLINE_CALL') {
        print("User tapped DECLINE_CALL");
        // TODO: Handle decline logic
      } else {
        print("User tapped on the notification (no specific action)");
      }
    },
  );

  // 5) Handle FCM messages while app is in the foreground
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

  @override
  void initState() {
    super.initState();
    _loadDarkModePref();
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
      debugShowCheckedModeBanner: false,
      title: 'Serenity',
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

// 6) Function to show the local notification with Accept/Decline actions
Future<void> _showIncomingCallNotification(RemoteMessage message) async {
  // Suppose your Cloud Function sends "callerName" in the data payload
  final callerName = message.data['callerName'] ?? 'Unknown Caller';

  // Define the two Android actions
  final AndroidNotificationAction acceptAction = AndroidNotificationAction(
    'ACCEPT_CALL',
    'Accept',
    icon: DrawableResourceAndroidBitmap('ic_accept_call'),
  );

  final AndroidNotificationAction declineAction = AndroidNotificationAction(
    'DECLINE_CALL',
    'Decline',
    icon: DrawableResourceAndroidBitmap('ic_decline_call'),
  );

  // Configure the notification details for Android
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'incoming_call_channel', // channel ID
    'Incoming Calls', // channel name
    channelDescription: 'Call notifications',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    playSound: true,
    fullScreenIntent: true, // tries to show a heads-up or full-screen style
    category: AndroidNotificationCategory.call,
    actions: <AndroidNotificationAction>[
      acceptAction,
      declineAction,
    ],
  );

  // If you only care about Android, skip iOS details
  final NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  // Show the local notification
  await flutterLocalNotificationsPlugin.show(
    999, // a unique ID for this notification
    'Incoming Call',
    '$callerName is calling...',
    platformDetails,
    payload: 'custom-data-here', // optional extra data
  );
}
