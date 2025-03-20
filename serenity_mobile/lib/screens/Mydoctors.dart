import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat.dart'; // Make sure this file exists and contains the ChatScreen widget

class MyDoctors extends StatefulWidget {
  @override
  _MyDoctorsState createState() => _MyDoctorsState();
}

class _MyDoctorsState extends State<MyDoctors> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> appointmentRequests = [];
  List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointmentRequests();
  }

  @override
  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _fetchAppointmentRequests() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String currentUserId = user.uid;
      DatabaseReference doctorsRef = _dbRef.child('administrator/doctors');
      DataSnapshot snapshot = await doctorsRef.get();

      if (snapshot.exists) {
        List<Map<String, dynamic>> requests = [];
        snapshot.children.forEach((doctorSnapshot) {
          String doctorId = doctorSnapshot.key ?? 'Unknown Doctor';
          final appointments = doctorSnapshot.child('Appointments');
          if (appointments.exists) {
            appointments.children.forEach((appointmentSnapshot) {
              final appointmentData =
                  Map<String, dynamic>.from(appointmentSnapshot.value as Map);
              // Only add if the appointment is for the current user and is approved
              if (appointmentData['userId'] == currentUserId &&
                  appointmentData['status'] == "approved") {
                requests.add({
                  'doctorId': doctorId,
                  'doctorName': doctorSnapshot.child('name').value ?? 'Unknown',
                  'timestamp': appointmentData['timestamp'] ?? 'Unknown',
                  'doctorPhone': doctorSnapshot.child('phone').value ?? '',
                });
              }
            });
          }
        });

        setState(() {
          appointmentRequests = requests;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Doctors'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: appointmentRequests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No approved appointment requests found.',
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 20),
                  Lottie.asset(
                    'assets/animation/snail.json',
                    width: 250,
                    height: 250,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: appointmentRequests.length,
              itemBuilder: (context, index) {
                final request = appointmentRequests[index];
                return Card(
                  margin: EdgeInsets.all(10.0),
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text(
                      request['doctorName'],
                      style: TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      'Approved on: ${request['timestamp']}',
                      style: TextStyle(fontSize: 14),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Message button
                        IconButton(
                          icon: Icon(Icons.message, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  userName: request['doctorName'],
                                  userAvatar:
                                      'assets/dino.png', // Default avatar since we don't have doctor's avatar
                                  userId: request['doctorId'],
                                ),
                              ),
                            );
                          },
                        ),
                        // Call button
                        IconButton(
                          icon: Icon(Icons.call, color: Colors.green),
                          onPressed: () async {
                            final phone = request['doctorPhone'];
                            if (phone.toString().isNotEmpty) {
                              final Uri launchUri =
                                  Uri(scheme: 'tel', path: phone.toString());
                              if (await canLaunchUrl(launchUri)) {
                                await launchUrl(launchUri);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text("Could not launch dialer")),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Doctor phone number not available")),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
