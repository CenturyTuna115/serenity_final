import 'package:flutter/material.dart';

class CallScreen extends StatelessWidget {
  final String userName;
  final String userAvatar;

  CallScreen({required this.userName, required this.userAvatar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E), // Dark background color
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundImage: AssetImage(userAvatar),
                    radius: 60,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Calling',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.mic_off, color: Colors.white, size: 30),
                      onPressed: () {
                        // Add mute functionality here
                      },
                    ),
                    SizedBox(width: 40),
                    IconButton(
                      icon: Icon(Icons.message, color: Colors.white, size: 30),
                      onPressed: () {
                        // Add message functionality here
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                        // Add answer call functionality here
                      },
                      backgroundColor: Colors.green,
                      child: Icon(Icons.call, color: Colors.white, size: 30),
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        // Add end call functionality here
                      },
                      backgroundColor: Colors.red,
                      child: Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
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
          // Handle navigation for bottom navigation items
        },
      ),
    );
  }
}
