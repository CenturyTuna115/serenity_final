import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serenity_mobile/screens/Login.dart';
import 'package:serenity_mobile/screens/userEdit.dart';
import 'package:serenity_mobile/screens/favorites_screen.dart';
import 'package:serenity_mobile/screens/subscription_screen.dart';

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
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),
            FutureBuilder(
              future: SharedPreferences.getInstance(),
              builder: (context, prefsSnapshot) {
                if (prefsSnapshot.connectionState == ConnectionState.waiting) {
                  return CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/dino.png'),
                  );
                }

                return FutureBuilder<DataSnapshot>(
                  future: FirebaseDatabase.instance
                      .ref(
                          'administrator/users/${FirebaseAuth.instance.currentUser?.uid}/profile_image')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircleAvatar(
                        radius: 50,
                        backgroundImage: AssetImage('assets/dino.png'),
                        child: Icon(Icons.person, size: 50),
                      );
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.value == null ||
                        snapshot.data!.value.toString().isEmpty) {
                      return CircleAvatar(
                        radius: 50,
                        backgroundImage: AssetImage('assets/dino.png'),
                      );
                    }
                    return CircleAvatar(
                      radius: 50,
                      backgroundImage: snapshot.data!.value != null &&
                              snapshot.data!.value.toString().isNotEmpty
                          ? NetworkImage(snapshot.data!.value.toString())
                          : null,
                      child: snapshot.data!.value == null ||
                              snapshot.data!.value.toString().isEmpty
                          ? Icon(Icons.person, size: 50)
                          : null,
                    );
                  },
                );
              },
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
                style: TextStyle(color: Colors.white),
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
            Divider(),
            _buildProfileOption(Icons.subscriptions, 'Subscription'),
            Divider(),
            _buildProfileOption(Icons.logout, 'Log Out'),
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
        switch (title) {
          case 'Favorites':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FavoritesScreen()),
            );
            break;
          case 'Subscription':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SubscriptionScreen()),
            );
            break;
          case 'Log Out':
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Log Out'),
                  content: Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LoginScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      child: Text('Log Out'),
                    ),
                  ],
                );
              },
            );
            break;
        }
      },
    );
  }
}
