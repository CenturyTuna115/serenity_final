import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class MyDoctors extends StatefulWidget {
  @override
  _MyDoctorsState createState() => _MyDoctorsState();
}

class _MyDoctorsState extends State<MyDoctors> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> appointmentRequests =
      []; // To store appointment requests
  List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointmentRequests(); // Fetch appointment requests
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

              if (appointmentData['userId'] == currentUserId) {
                requests.add({
                  'doctorId': doctorId,
                  'doctorName': doctorSnapshot.child('name').value ?? 'Unknown',
                  'timestamp': appointmentData['timestamp'] ?? 'Unknown',
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
                  Text('No appointment requests found.',
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
                    leading: Icon(Icons.hourglass_empty, color: Colors.orange),
                    title: Text(
                      request['doctorName'],
                      style: TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      'Requested on: ${request['timestamp']}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
