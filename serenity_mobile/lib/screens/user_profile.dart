import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serenity_mobile/screens/Login.dart';
import 'homepage.dart';
import 'chatbox.dart';
import 'emergencymode.dart';

class UserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Profile'),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('No user data found'));
          }
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String userName = userData['full_name'] ?? 'User';
          String userAvatar = userData['avatar'] ?? 'assets/dino.png';

          return Column(
            children: [
              SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage(userAvatar),
              ),
              SizedBox(height: 10),
              Text(
                userName,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  // Add edit functionality here
                },
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                onTap: () {
                  // Add settings functionality here
                },
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile Management'),
                onTap: () {
                  // Add profile management functionality here
                },
              ),
              ListTile(
                leading: Icon(Icons.help),
                title: Text('Help Support'),
                onTap: () {
                  // Add help support functionality here
                },
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Log Out'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF92A68A),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: '',
          ),
        ],
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: const Color(0xFF94AF94),
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatBox()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Emergencymode()),
            );
          } else if (index == 3) {
            FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
              (Route<dynamic> route) => false,
            );
          }
        },
      ),
    );
  }
}
