import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/screens/userEdit.dart';
import 'homepage.dart'; // Import the HomePage

class UserProfile extends StatefulWidget {
  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String _fullName = "Loading...";
  String _email = "Loading...";
  String _username = "Loading...";
  String _number = "Loading...";
  String _condition = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  void _fetchUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      final snapshot =
          await _dbRef.child('administrator/users/${user.uid}').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _fullName = data['full_name'] ?? "Unknown User";
          _email = data['email'] ?? "Unknown Email";
          _username = data['username'] ?? "Unknown Username";
          _number = data['phone_number'] ?? "Unknown Number";
          _condition = data['condition'] ?? "Unknown Condition";
        });
      } else {
        setState(() {
          _fullName = "Unknown User";
          _email = "Unknown Email";
          _username = "Unknown Username";
          _number = "Unknown Number";
          _condition = "Unknown Condition";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF92A68A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('My Profile', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              // Settings functionality placeholder
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/dino.png'), // User profile image
            ),
            SizedBox(height: 10),
            Text(
              _fullName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              _email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserEdit()),
                );
              },
              child: Text(
                'Edit Profile',
                style: TextStyle(color: Colors.white),  // Text color changed to white
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            SizedBox(height: 20),
            Divider(),
            _buildProfileOption(Icons.favorite, 'Favorites'),
            _buildProfileOption(Icons.account_circle_rounded, 'About me'),
            Divider(),
            _buildProfileOption(Icons.language, 'Language'),
            _buildProfileOption(Icons.subscriptions, 'Subscription'),
            Divider(),
            _buildProfileOption(Icons.bug_report, 'Report'),
            _buildProfileOption(Icons.contact_support, 'Contact Support'),
            Divider(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Icon(Icons.chevron_right),
      onTap: () {
        // Handle tap event
      },
    );
  }
}
