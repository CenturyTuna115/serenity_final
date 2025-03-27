import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lottie/lottie.dart';
import 'package:serenity_mobile/screens/Login.dart';
import 'package:serenity_mobile/screens/emergencymode.dart';
import 'package:serenity_mobile/screens/homepage.dart';
import 'package:serenity_mobile/screens/messages.dart';
import 'package:serenity_mobile/services/notification_service.dart';
import 'package:serenity_mobile/utils/auth_utils.dart';
import 'chat.dart';
import 'voicecallscreen.dart';

class MyDoctors extends StatefulWidget {
  final int currentIndex;

  const MyDoctors({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  _MyDoctorsState createState() => _MyDoctorsState();
}

class _MyDoctorsState extends State<MyDoctors> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> myAppointments = [];

  // Store any real-time listeners here.
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    // Listen for incoming call notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'call') {
        _handleIncomingCall(
          message.data['doctorId'] ?? '',
          message.data['doctorName'] ?? 'Unknown Doctor',
          // Even if channelId is sent in the FCM data, we no longer pass it
          // because VoiceCallScreen no longer accepts a named parameter "channelId".
          // If you need to pass it, update VoiceCallScreen accordingly.
          message.data['channelId'] ?? '',
        );
      }
    });
  }

  void _handleIncomingCall(
      String doctorId, String doctorName, String channelId) async {
    // Fetch doctor's details from the database.
    final doctorSnapshot =
        await _dbRef.child('administrator/doctors/$doctorId').get();
    final doctorAvatar =
        doctorSnapshot.child('profile_image').value?.toString() ??
            'assets/dino.png';

    // Ensure current user is logged in.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Navigate to VoiceCallScreen with the call details.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          doctorId: doctorId,
          doctorAvatar: doctorAvatar,
          doctorName: doctorName,
        ),
      ),
    );
  }

  void _showReportDialog(String doctorId, String doctorName) {
    final reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report $doctorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe the issue:'),
            const SizedBox(height: 10),
            TextField(
              controller: reportController,
              decoration: const InputDecoration(
                hintText: 'Minimum 10 characters',
                border: OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reportController.text.length >= 10) {
                _submitReport(doctorId, reportController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Report submitted successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Please provide more details (min 10 characters)'),
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _submitReport(String doctorId, String reason) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final reportRef = _dbRef.child('reports').push();
    reportRef.set({
      'doctorId': doctorId,
      'userId': userId,
      'reason': reason,
      'timestamp': ServerValue.timestamp,
      'status': 'pending',
    });
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  /// Fetch appointments by checking the "Appointments" and "mypatients" nodes for each doctor.
  Future<void> _fetchAppointments() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String currentUserId = user.uid;
    final DatabaseReference doctorsRef =
        _dbRef.child('administrator').child('doctors');
    final DataSnapshot snapshot = await doctorsRef.get();

    if (!snapshot.exists) {
      setState(() {
        myAppointments = [];
      });
      return;
    }

    final List<Map<String, dynamic>> tempList = [];

    // Iterate through each doctor record.
    for (var doctorSnapshot in snapshot.children) {
      final String doctorId = doctorSnapshot.key ?? 'UnknownDoctorId';
      final String doctorName =
          doctorSnapshot.child('name').value?.toString() ?? 'Unknown Doctor';
      final String doctorPhone =
          doctorSnapshot.child('phone').value?.toString() ?? '';
      final String doctorAvatar =
          doctorSnapshot.child('profile_image').value?.toString() ??
              'assets/dino.png';

      // Create a record for the doctor.
      final Map<String, dynamic> appointmentRecord = {
        'doctorId': doctorId,
        'doctorName': doctorName,
        'doctorPhone': doctorPhone,
        'doctorAvatar': doctorAvatar,
        'status': null,
        'timestamp': null,
      };

      // Check in "Appointments".
      final DataSnapshot appointmentsSnapshot =
          doctorSnapshot.child('Appointments');
      if (appointmentsSnapshot.exists) {
        for (var apptSnap in appointmentsSnapshot.children) {
          final Map<dynamic, dynamic> apptData =
              apptSnap.value as Map<dynamic, dynamic>;
          if (apptData['userId'] == currentUserId) {
            appointmentRecord['status'] = apptData['status'] ?? 'unknown';
            appointmentRecord['timestamp'] = apptData['timestamp'] ?? 'N/A';
            break;
          }
        }
      }

      // Check in "mypatients".
      final DataSnapshot myPatientsSnapshot =
          doctorSnapshot.child('mypatients');
      if (myPatientsSnapshot.exists) {
        for (var patientSnap in myPatientsSnapshot.children) {
          final Map<dynamic, dynamic> patientData =
              patientSnap.value as Map<dynamic, dynamic>;
          if (patientData['patientID'] == currentUserId) {
            appointmentRecord['status'] =
                patientData['status'] ?? appointmentRecord['status'];
            appointmentRecord['timestamp'] =
                patientData['timestamp'] ?? appointmentRecord['timestamp'];
            break;
          }
        }
      }

      // Only add the record if a status exists.
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
        title: const Text('My Doctors'),
        backgroundColor: const Color(0xFF92A68A),
      ),
      body: myAppointments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No appointments found.'),
                  const SizedBox(height: 20),
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
                final Map<String, dynamic> doc = myAppointments[index];
                final String status = doc['status']?.toString() ?? 'unknown';
                final String timestamp = doc['timestamp']?.toString() ?? 'N/A';

                return Card(
                  margin: const EdgeInsets.all(10.0),
                  child: ListTile(
                    // Display the doctor's avatar.
                    leading: CircleAvatar(
                      backgroundImage: doc['doctorAvatar']
                              .toString()
                              .startsWith('assets/')
                          ? AssetImage(doc['doctorAvatar'])
                          : NetworkImage(doc['doctorAvatar']) as ImageProvider,
                    ),
                    title: Text(
                      doc['doctorName'],
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: Text(
                      'Status: $status\nDate: $timestamp',
                      style: const TextStyle(fontSize: 14),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Report button shown only when appointment is approved.
                        if (status == 'approved')
                          IconButton(
                            icon: const Icon(Icons.report, color: Colors.red),
                            onPressed: () => _showReportDialog(
                                doc['doctorId'], doc['doctorName']),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
        currentIndex: widget.currentIndex,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: const Color(0xFF94AF94),
        iconSize: 30.0,
        selectedFontSize: 0.0,
        unselectedFontSize: 0.0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(currentIndex: 0),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MessagesTab(currentIndex: 1),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => Emergencymode(currentIndex: 2),
              ),
            );
          } else if (index == 3) {
            AuthUtils.logoutWithConfirmation(
              context: context,
              loginScreen: LoginScreen(),
            );
          }
        },
      ),
    );
  }
}
