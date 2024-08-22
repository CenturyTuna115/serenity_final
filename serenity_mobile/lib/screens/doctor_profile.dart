import 'package:flutter/material.dart';

class DoctorProfile extends StatelessWidget {
  final String profilePic;
  final String name;
  final String specialization;
  final String experience;
  final String license;
  final String description;

  DoctorProfile({
    required this.profilePic,
    required this.name,
    required this.specialization,
    required this.experience,
    required this.license,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Profile'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Doctor's Profile Picture
            CircleAvatar(
              radius: 80,
              backgroundImage: NetworkImage(profilePic),
            ),
            SizedBox(height: 20),

            // Doctor's Name
            Text(
              name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),

            // Specialization
            Text(
              specialization,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // Experience
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_outline, color: Colors.orange),
                SizedBox(width: 10),
                Text(
                  '$experience years of experience',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
            SizedBox(height: 20),

            // License Number
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, color: Colors.orange),
                SizedBox(width: 10),
                Text(
                  'License: $license',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Description
            Text(
              description,
              style: TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),

            // Schedule Appointment Button
            ElevatedButton(
              onPressed: () {
                // Handle schedule appointment action
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFA726), // Button color
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              child: Text(
                'Request Appointment',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
