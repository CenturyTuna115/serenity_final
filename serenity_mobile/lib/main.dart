import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart'
    show DatabaseReference, FirebaseDatabase, ServerValue;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your other screens (adjust the import paths as needed)
import 'package:serenity_mobile/screens/splashScreen.dart';
import 'package:serenity_mobile/screens/voicecallscreen.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request notification permissions and setup FCM token handling
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Handle token refresh with retry logic
  messaging.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseDatabase.instance
            .ref('administrator/users/${user.uid}')
            .update({'fcmToken': newToken});
        // Also store in SharedPreferences as backup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcmToken', newToken);
      } catch (e) {
        print('Failed to store refreshed FCM token: $e');
        // Retry after delay
        await Future.delayed(Duration(seconds: 5));
        await FirebaseDatabase.instance
            .ref('administrator/users/${user.uid}')
            .update({'fcmToken': newToken});
      }
    }
  });

  // Get initial token with retry logic
  final initialToken = await messaging.getToken();
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && initialToken != null) {
    try {
      await FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}')
          .update({'fcmToken': initialToken});
      // Also store in SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcmToken', initialToken);
    } catch (e) {
      print('Failed to store initial FCM token: $e');
      // Retry after delay
      await Future.delayed(Duration(seconds: 5));
      await FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}')
          .update({'fcmToken': initialToken});
    }
  }

  // Check for stored token if user is logged in but no token was stored
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

  // Register the background message handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize flutter_local_notifications.
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    // iOS initialization omitted for this example.
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (response) async {
      // Parse the payload from the notification.
      final payloadParts = response.payload?.split('|');
      if (response.actionId == 'ACCEPT_CALL') {
        if (payloadParts != null && payloadParts.length >= 3) {
          final callerName = payloadParts[0];
          final doctorAvatar = payloadParts[1];
          final channelId = payloadParts[2];
          Navigator.of(navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                doctorAvatar: doctorAvatar,
                doctorName: callerName,
                channelId: channelId,
                patientId:
                    '', // Retrieve patientId from SharedPreferences as needed.
              ),
            ),
          );
        }
      } else if (response.actionId == 'DECLINE_CALL') {
        if (payloadParts != null && payloadParts.length >= 3) {
          final channelId = payloadParts[2];
          final dbRef =
              FirebaseDatabase.instance.ref('agoraChannels/$channelId');
          await dbRef.update({
            'status': 'ended',
            'endTimestamp': ServerValue.timestamp,
          });
        }
      } else {
        // If no specific action was tapped, navigate to the incoming call screen.
        if (payloadParts != null && payloadParts.length >= 3) {
          final callerName = payloadParts[0];
          final doctorAvatar = payloadParts[1];
          final channelId = payloadParts[2];
          Navigator.of(navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                doctorAvatar: doctorAvatar,
                doctorName: callerName,
                channelId: channelId,
                patientId: '',
              ),
            ),
          );
        }
      }
    },
  );

  // Listen for foreground FCM messages.
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

// Function to display the local notification for an incoming call.
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

// --------------------------
// IncomingCallScreen Widget
// --------------------------

class IncomingCallScreen extends StatefulWidget {
  final String doctorAvatar;
  final String doctorName;
  final String channelId;
  final String patientId;

  const IncomingCallScreen({
    Key? key,
    required this.doctorAvatar,
    required this.doctorName,
    required this.channelId,
    required this.patientId,
  }) : super(key: key);

  @override
  _IncomingCallScreenState createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    _dbRef =
        FirebaseDatabase.instance.ref('agoraChannels').child(widget.channelId);
  }

  // Accept the call: update the call status in Firebase and navigate to the VoiceCallScreen.
  void _acceptCall() async {
    await _dbRef.update({
      'status': 'accepted',
      'acceptTimestamp': ServerValue.timestamp,
    });
    // Extract the doctorId from the channelId (assumes format "doctorId-userId")
    final doctorId = widget.channelId.split('-').first;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          doctorAvatar: widget.doctorAvatar,
          doctorName: widget.doctorName,
          doctorId: doctorId,
        ),
      ),
    );
  }

  // Decline the call: update Firebase and close this screen.
  void _declineCall() async {
    await _dbRef.update({
      'status': 'ended',
      'endTimestamp': ServerValue.timestamp,
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Caller avatar
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.doctorAvatar.isNotEmpty
                  ? (widget.doctorAvatar.startsWith('http')
                      ? NetworkImage(widget.doctorAvatar)
                      : AssetImage(widget.doctorAvatar))
                  : const AssetImage('assets/johndoe.jpg') as ImageProvider,
            ),
            const SizedBox(height: 20),
            // Caller name and message.
            Text(
              '${widget.doctorName} is calling...',
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 30),
            // Accept and Decline buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _acceptCall,
                  child: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _declineCall,
                  child: const Text('Decline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
