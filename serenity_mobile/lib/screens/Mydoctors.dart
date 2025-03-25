import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lottie/lottie.dart';
// If you have a chat screen, import it:
import 'chat.dart';
import 'voicecallscreen.dart'; // <-- Import our VoiceCallScreen

class MyDoctors extends StatefulWidget {
  const MyDoctors({Key? key}) : super(key: key);

  @override
  _MyDoctorsState createState() => _MyDoctorsState();
}

class _MyDoctorsState extends State<MyDoctors> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> myAppointments = [];

  /// Store any real-time listeners here (if used)
  List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  /// Example: fetch from administrator/doctors or wherever your data is
  void _fetchAppointments() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentUserId = user.uid;

    // Example path: "administrator/doctors"
    // Adjust to match your actual DB structure
    DatabaseReference doctorsRef =
        _dbRef.child('administrator').child('doctors');
    DataSnapshot snapshot = await doctorsRef.get();

    if (!snapshot.exists) {
      setState(() {
        myAppointments = [];
      });
      return;
    }

    List<Map<String, dynamic>> tempList = [];

    // Iterate through each doctor
    for (var doctorSnapshot in snapshot.children) {
      final doctorId = doctorSnapshot.key ?? 'UnknownDoctorId';
      final doctorName = doctorSnapshot.child('name').value ?? 'Unknown Doctor';
      final doctorPhone = doctorSnapshot.child('phone').value ?? '';

      // We'll build a record if we find a match in "Appointments" or "mypatients"
      Map<String, dynamic> appointmentRecord = {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorPhone': doctorPhone,
        'status': null,
        'timestamp': null,
      };

      // ---------------------------
      // Check "Appointments"
      // ---------------------------
      final appointmentsSnapshot = doctorSnapshot.child('Appointments');
      if (appointmentsSnapshot.exists) {
        for (var apptSnap in appointmentsSnapshot.children) {
          final apptData = Map<String, dynamic>.from(apptSnap.value as Map);
          if (apptData['userId'] == currentUserId) {
            appointmentRecord['status'] = apptData['status'] ?? 'unknown';
            appointmentRecord['timestamp'] = apptData['timestamp'] ?? 'N/A';
            break;
          }
        }
      }

      // ---------------------------
      // Check "mypatients"
      // (e.g., if you store approved users there)
      // ---------------------------
      final myPatientsSnapshot = doctorSnapshot.child('mypatients');
      if (myPatientsSnapshot.exists) {
        for (var patientSnap in myPatientsSnapshot.children) {
          final patientData =
              Map<String, dynamic>.from(patientSnap.value as Map);
          // Notice "patientID" might be the field for user ID
          if (patientData['patientID'] == currentUserId) {
            appointmentRecord['status'] = patientData['status'] ?? 'unknown';
            appointmentRecord['timestamp'] =
                patientData['timestamp'] ?? appointmentRecord['timestamp'];
            break;
          }
        }
      }

      // Add only if status is found (pending/approved)
      if (appointmentRecord['status'] != null) {
        tempList.add(appointmentRecord);
      }
    }

    setState(() {
      myAppointments = tempList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Appointments'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: myAppointments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No appointments found.'),
                  SizedBox(height: 20),
                  Lottie.asset(
                    'assets/animation/snail.json',
                    width: 200,
                    height: 200,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: myAppointments.length,
              itemBuilder: (context, index) {
                final doc = myAppointments[index];
                final status = doc['status'] ?? 'unknown';
                final timestamp = doc['timestamp'] ?? 'N/A';

                // Choose an icon/color based on status
                IconData iconData;
                Color iconColor;
                if (status == 'approved') {
                  iconData = Icons.check_circle;
                  iconColor = Colors.green;
                } else if (status == 'pending') {
                  iconData = Icons.access_time;
                  iconColor = Colors.orange;
                } else {
                  iconData = Icons.help_outline;
                  iconColor = Colors.grey;
                }

                return Card(
                  margin: EdgeInsets.all(10.0),
                  child: ListTile(
                    leading: Icon(iconData, color: iconColor),
                    title: Text(
                      doc['doctorName'],
                      style: TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      'Status: $status\nDate: $timestamp',
                      style: TextStyle(fontSize: 14),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Chat button (you can hide if not approved, if you want)
                        IconButton(
                          icon: Icon(Icons.message, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  userName: doc['doctorName'],
                                  userAvatar: 'assets/dino.png',
                                  userId: doc['doctorId'],
                                ),
                              ),
                            );
                          },
                        ),
                        // Call button => Navigate to VoiceCallScreen
                        IconButton(
                          icon: Icon(Icons.call, color: Colors.green),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VoiceCallScreen(
                                  doctorAvatar: 'assets/dino.png',
                                  doctorName: doc['doctorName'],
                                  channelId: 'doctor-${doc['doctorId']}',
                                ),
                              ),
                            );
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
