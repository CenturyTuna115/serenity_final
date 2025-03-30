import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:serenity_mobile/screens/doctor_notes.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serenity_mobile/screens/customize.dart';
import 'package:serenity_mobile/screens/mydoctors.dart' as mydoctors;
import 'package:serenity_mobile/screens/buddy.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart'
    as doctor_dashboard;
import 'package:serenity_mobile/screens/questionnaires.dart';
import 'package:serenity_mobile/screens/emergencymode.dart';
import 'package:serenity_mobile/screens/login.dart';
import 'package:serenity_mobile/screens/messages.dart';
import 'package:serenity_mobile/screens/contacts.dart';
import 'package:serenity_mobile/screens/user_profile.dart';
import 'package:serenity_mobile/screens/weeklygraph.dart';
import 'package:serenity_mobile/screens/incoming_call_screen.dart';
import 'package:intl/intl.dart';
import 'package:serenity_mobile/services/auth_service.dart';
import 'package:serenity_mobile/widgets/app_bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  final int currentIndex;

  const HomePage({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDoctorAssigned = false;
  bool _canAnswerWeeklyQuestions = false;
  bool _isLoading = true;
  final AuthService _authService = AuthService();
  final List<StreamSubscription> _subscriptions = [];

  void _addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _setupIncomingCallListener();
  }

  void _setupIncomingCallListener() {
    _authService.listenForChannelsForPatient(
      (data) {
        if (data == null || !mounted) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                IncomingCallScreen(
              token: data['token'] ?? '',
              doctorAvatar: data['doctorAvatar'] ?? '',
              doctorName: data['callerName'] ?? 'Unknown Caller',
              channelId: data['channelName'] ?? '',
              patientId: FirebaseAuth.instance.currentUser!.uid,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      (error) {
        if (kDebugMode) {
          print('Error listening for channels: $error');
        }
      },
    );
  }

  Future<void> _checkLastAnswered() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/last_answered')
          .once();

      bool canAnswer = true;
      if (snapshot.snapshot.exists) {
        final lastAnsweredTimestamp =
            snapshot.snapshot.child('timestamp').value as String?;
        if (lastAnsweredTimestamp != null) {
          final lastAnsweredDate = DateTime.parse(lastAnsweredTimestamp);
          final now = DateTime.now();
          final difference = now.difference(lastAnsweredDate).inDays;
          canAnswer = difference >= 7;
        }
      }

      if (mounted) {
        setState(() {
          _canAnswerWeeklyQuestions = canAnswer;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _canAnswerWeeklyQuestions = false;
          _isLoading = false;
        });
      }
      if (kDebugMode) {
        print('Error checking last answered: $e');
      }
    }
  }

  void _setupRealtimeListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isDoctorAssigned = false;
        _canAnswerWeeklyQuestions = false;
        _isLoading = false;
      });
      return;
    }

    final userRef =
        FirebaseDatabase.instance.ref('administrator/users/${user.uid}');

    // Realtime listener for assigned_doctor only
    _addSubscription(userRef.child('assigned_doctor').onValue.listen((event) {
      if (!mounted) return;
      final isDoctorAssigned =
          event.snapshot.exists && event.snapshot.value == true;
      setState(() {
        _isDoctorAssigned = isDoctorAssigned;
      });
    }));

    // Check last_answered once when the page loads
    _checkLastAnswered();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD7E9D7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildWeeklyGraphCard(),
            _buildMenuGrid(),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: _handleBottomNavTap,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserProfile()),
              );
            },
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref(
                      'administrator/users/${FirebaseAuth.instance.currentUser?.uid}/profile_image')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final imageUrl = snapshot.data?.snapshot.value?.toString();
                return CircleAvatar(
                  radius: 30,
                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : const AssetImage('assets/dino.png') as ImageProvider,
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          FutureBuilder<DataSnapshot>(
            future: FirebaseDatabase.instance
                .ref(
                    'administrator/users/${FirebaseAuth.instance.currentUser?.uid}/full_name')
                .once()
                .then((event) => event.snapshot),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final userName = snapshot.data?.value?.toString() ?? 'User';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back!',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          Image.asset(
            'assets/logo.png',
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGraphCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly graph',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: WeeklyGraph(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Expanded(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildMenuItem(
                  context,
                  'Doctor dashboard',
                  Icons.local_hospital,
                  doctor_dashboard.DoctorDashboard(),
                  true,
                ),
                _buildMenuItem(
                  context,
                  'Buddy list',
                  Icons.group,
                  BuddyScreen(),
                  true,
                ),
                _buildMenuItem(
                  context,
                  'Contacts',
                  Icons.person,
                  Contacts(),
                  true,
                ),
                _buildMenuItem(
                  context,
                  'My Doctors',
                  Icons.person_search,
                  mydoctors.MyDoctors(),
                  true,
                ),
                _buildMenuItem(
                  context,
                  'Gesture',
                  Icons.gesture,
                  CustomizePage(),
                  true,
                ),
                _buildMenuItem(
                  context,
                  'Weekly Questions',
                  Icons.question_answer,
                  Questionnaires(),
                  _isDoctorAssigned && _canAnswerWeeklyQuestions,
                ),
              ],
            ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon,
      Widget? route, bool enabled) {
    return GestureDetector(
      onTap: enabled
          ? () {
              if (route != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => route),
                );
              }
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                try {
                  return Icon(
                    icon,
                    size: 48,
                    color: enabled ? const Color(0xFF00695C) : Colors.grey[600],
                  );
                } catch (e) {
                  return Icon(
                    Icons.error_outline,
                    size: 48,
                    color: enabled ? const Color(0xFF00695C) : Colors.grey[600],
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: enabled ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == widget.currentIndex) return;

    Widget page;
    switch (index) {
      case 0:
        page = HomePage(currentIndex: 0);
        break;
      case 1:
        page = MessagesTab(currentIndex: 1);
        break;
      case 2:
        page = Emergencymode(currentIndex: 2);
        break;
      case 3:
        page = FutureBuilder<DataSnapshot>(
          future: FirebaseDatabase.instance
              .ref(
                  'administrator/users/${FirebaseAuth.instance.currentUser?.uid}/mydoctors')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const DoctorNotesScreen();
          },
        );
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }
}
