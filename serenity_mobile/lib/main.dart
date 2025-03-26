import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serenity_mobile/screens/splashScreen.dart';
import 'package:serenity_mobile/services/notification_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set up FCM
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
    NotificationService.initialize(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Serenity',
      theme: _darkMode
          ? ThemeData.dark().copyWith(
              primaryColor: Colors.green[800],
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                selectedItemColor: Colors.orange[300],
                unselectedItemColor: Colors.grey[500],
                backgroundColor: Colors.grey[900],
                selectedIconTheme: IconThemeData(size: 24.0),
                unselectedIconTheme: IconThemeData(size: 24.0),
                type: BottomNavigationBarType.fixed,
              ),
            )
          : ThemeData(
              primarySwatch: Colors.green,
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                selectedItemColor: Color(0xFFFFA726),
                unselectedItemColor: Color(0xFF94AF94),
                backgroundColor: Color(0xFFF6F4EE),
                selectedIconTheme: IconThemeData(size: 24.0),
                unselectedIconTheme: IconThemeData(size: 24.0),
                type: BottomNavigationBarType.fixed,
              ),
            ),
      home: SplashScreen(),
    );
  }
}
