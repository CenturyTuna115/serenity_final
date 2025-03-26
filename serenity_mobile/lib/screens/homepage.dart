import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  final int currentIndex;

  const HomePage({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDoctorAssigned = false; // To track if a doctor is assigned
  bool _canAnswerWeeklyQuestions =
      false; // To track if user can answer weekly questions
  bool _isLoading = true; // To handle loading state

  @override
  void initState() {
    super.initState();
    _fetchDoctorAssignmentAndQuestionnaireStatus();
  }

  Future<void> _fetchDoctorAssignmentAndQuestionnaireStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef =
          FirebaseDatabase.instance.ref('administrator/users/${user.uid}');

      // Check if a doctor is assigned
      final doctorSnapshot = await userRef.child('assigned_doctor').get();
      final isDoctorAssigned =
          doctorSnapshot.exists && doctorSnapshot.value == true;

      // Check the last answered timestamp for weekly questions
      final lastAnsweredSnapshot = await userRef.child('last_answered').get();
      bool canAnswer = true;

      if (lastAnsweredSnapshot.exists) {
        final lastAnsweredTimestamp =
            lastAnsweredSnapshot.child('timestamp').value as String;
        final lastAnsweredDate = DateTime.parse(lastAnsweredTimestamp);
        final now = DateTime.now();
        final difference = now.difference(lastAnsweredDate).inDays;

        if (difference < 7) {
          canAnswer = false;
        }
      }

      setState(() {
        _isDoctorAssigned = isDoctorAssigned;
        _canAnswerWeeklyQuestions = canAnswer;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isDoctorAssigned = false;
        _canAnswerWeeklyQuestions = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD7E9D7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                const AssetImage('assets/dino.png'),
                          );
                        }
                        final imageUrl =
                            snapshot.data?.snapshot.value?.toString();
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          return CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(imageUrl),
                          );
                        }
                        return CircleAvatar(
                          radius: 30,
                          backgroundImage: const AssetImage('assets/dino.png'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  FutureBuilder<DataSnapshot>(
                    future: FirebaseDatabase.instance
                        .ref(
                            'administrator/users/${FirebaseAuth.instance.currentUser?.uid}/full_name')
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return const Text('Error');
                      }
                      if (!snapshot.hasData || snapshot.data?.value == null) {
                        return const Text('User');
                      }
                      String userName =
                          snapshot.data?.value.toString() ?? 'full_name';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
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
            ),
            Padding(
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
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      padding: const EdgeInsets.all(16),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFF6F4EE),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.mail),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bell),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_arrow_right),
            label: '',
          ),
        ],
        currentIndex: widget.currentIndex,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: const Color(0xFF94AF94),
        iconSize: 30.0,
        selectedFontSize: 0.0,
        unselectedFontSize: 0.0,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MessagesTab(currentIndex: 1),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Emergencymode(currentIndex: 2),
              ),
            );
          } else if (index == 3) {
            _logout(context);
          }
        },
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
          : null, // Disable tap if not enabled
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: enabled
                  ? const Color.fromARGB(255, 10, 128, 146)
                  : Colors.grey,
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

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }
}
