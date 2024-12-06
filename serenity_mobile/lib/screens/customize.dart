import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'messages.dart';
import 'emergencymode.dart';
import 'login.dart';

class CustomizePage extends StatelessWidget {
  final int currentIndex;

  CustomizePage({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255), // Background color
      appBar: AppBar(
        backgroundColor: Color(0xFF92A68A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.png', // Replace with your logo asset path
              height: 30,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 126, 243, 251),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/dino.png', // Replace with your image path
                      height: 150,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Shake It Your Way! \n Tailor Your Calm with Serenity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Health Trusted Companion',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Customize',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton('Upload', Icons.upload, Color.fromARGB(255, 232, 131, 0)),
                  _buildActionButton('Record', Icons.mic, Color.fromARGB(255, 0, 60, 29)),
                  _buildActionButton('Voices', Icons.headset, Color.fromARGB(255, 0, 60, 29)),
                  _buildActionButton('Health', Icons.health_and_safety, Color.fromARGB(255, 0, 60, 29)),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Recommendation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 1, // Single column for the row design
                childAspectRatio: 4, // Adjust for horizontal layout
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildRecommendationTile('River Flow', 'assets/gesture/river.jpg'),
                  _buildRecommendationTile('Birds Humm', 'assets/gesture/birds.jpg'),
                  _buildRecommendationTile('Breathing', 'assets/gesture/breath.png'),
                ],
              ),
            ],
          ),
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
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: const Color(0xFF94AF94),
        iconSize: 30.0,
        selectedFontSize: 0.0,
        unselectedFontSize: 0.0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage(currentIndex: 0)),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MessagesTab(currentIndex: 1)),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Emergencymode(currentIndex: 2)),
            );
          } else if (index == 3) {
            _logout(context);
          }
        },
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildRecommendationTile(String title, String imagePath) {
    return GestureDetector(
      onTap: () {
        // Handle recommendation click
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFD7E9D7),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8), // Rounded corners for the image
              child: Image.asset(
                imagePath,
                width: 90, // Adjust the size of the image
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 20), // Space between image and text
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
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
