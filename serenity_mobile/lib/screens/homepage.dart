import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:serenity_mobile/screens/weeklygraph.dart';
import 'doctor_dashboard.dart';
import 'questionnaires.dart';
import 'emergencymode.dart'; // Import the Emergencymode page
import 'login.dart'; // Import the LoginScreen page
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Color(0xFFD7E9D7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/dino.png'),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        user?.email ?? 'User',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
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
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly graph',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 150,
                      child: WeeklyGraph(), // graph widget
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                padding: EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildMenuItem(
                    context,
                    'Doctor dashboard',
                    Icons.local_hospital,
                    DoctorDashboard(),
                  ),
                  _buildMenuItem(context, 'Buddy list', Icons.group, null),
                  _buildMenuItem(context, 'Gesture', Icons.gesture, null),
                  _buildMenuItem(context, 'Weekly Questions', Icons.question_answer, Questionnaires()),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF92A68A),
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
            icon: Icon(CupertinoIcons.square_arrow_right), // Change ellipsis to log out icon
            label: '',
          ),
        ],
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Color(0xFF94AF94),
        onTap: (index) {
          if (index == 2) { // Bell icon index
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Emergencymode()),
            );
          } else if (index == 3) { // Log out icon index
            _logout(context);
          }
          // Handle other navigation if needed
        },
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, Widget? route) {
    return GestureDetector(
      onTap: () {
        if (route != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => route),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF94AF94),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
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