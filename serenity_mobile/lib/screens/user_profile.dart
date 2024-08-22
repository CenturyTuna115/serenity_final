import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/screens/userEdit.dart';

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
        backgroundColor: const Color(0xFF92A68A),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Profile'),
        centerTitle: true,
        actions: [
          Image.asset(
            'assets/logo.png',
            height: 40,
          ),
          SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/dino.png'),
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
            IconButton(
              icon: Icon(Icons.edit, color: Colors.grey),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserEdit()),
                );
              },
            ),
            SizedBox(height: 20),
            _buildUserInfoTile(Icons.person, 'Username', _username),
            _buildUserInfoTile(Icons.email, 'Email', _email),
            _buildUserInfoTile(Icons.phone, 'Phone Number', _number),
            _buildUserInfoTile(Icons.local_hospital, 'Condition', _condition),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                // Settings functionality placeholder
              },
            ),
            ListTile(
              leading: Icon(Icons.help),
              title: Text('Help Support'),
              onTap: () {
                // Help support functionality placeholder
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Log Out'),
              onTap: () {
                // Logout functionality placeholder
              },
            ),
          ],
        ),
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
          // Bottom navigation functionality placeholder
        },
      ),
    );
  }

  Widget _buildUserInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}
