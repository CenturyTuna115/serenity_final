import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'homepage.dart';
import 'chatbox.dart';
import 'emergencymode.dart';
import 'login.dart';

class BuddyScreen extends StatelessWidget {
  final List<Contact> buddies;

  BuddyScreen({required this.buddies});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support Buddies'),
        backgroundColor: const Color(0xFF6D9773),
      ),
      body: ListView.builder(
        itemCount: buddies.length,
        itemBuilder: (context, index) {
          final buddy = buddies[index];
          return ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage('assets/dino.png'), // Default avatar
            ),
            title: Text(buddy.displayName ?? 'Unknown'),
            subtitle: Text(buddy.phones?.isNotEmpty ?? false
                ? buddy.phones!.first.value!
                : 'No phone number'),
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
