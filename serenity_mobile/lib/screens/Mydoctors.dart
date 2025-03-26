import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  /// Store any real-time listeners here (if used)
  List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    // Listen for incoming call notifications
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'call') {
        _handleIncomingCall(
          message.data['doctorId'],
          message.data['doctorName'],
          message.data['channelId'],
        );
      }
    });
  }

  void _handleIncomingCall(
      String doctorId, String doctorName, String channelId) async {
    final doctorSnapshot =
        await _dbRef.child('administrator/doctors/$doctorId').get();
    final doctorAvatar =
        doctorSnapshot.child('profile_image').value?.toString() ??
            'assets/dino.png';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          doctorAvatar: doctorAvatar,
          doctorName: doctorName,
          channelId: channelId,
          patientId: FirebaseAuth.instance.currentUser!.uid,
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
            Text('Please describe the issue:'),
            SizedBox(height: 10),
            TextField(
              controller: reportController,
              decoration: InputDecoration(
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
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reportController.text.length >= 10) {
                _submitReport(doctorId, reportController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Report submitted successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Please provide more details (min 10 chars)')),
                );
              }
            },
            child: Text('Submit'),
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
        'doctorAvatar':
            doctorSnapshot.child('profile_image').value ?? 'assets/dino.png',
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
        title: Text('My Doctors'),
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
                        // Chat button
                        if (status == 'approved')
                          IconButton(
                            icon: Icon(Icons.message, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    userName: doc['doctorName'],
                                    userAvatar: doc['doctorAvatar'],
                                    userId: doc['doctorId'],
                                  ),
                                ),
                              );
                            },
                          ),
                        // Call button => Navigate to VoiceCallScreen
                        if (status == 'approved')
                          IconButton(
                            icon: Icon(Icons.call, color: Colors.green),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VoiceCallScreen(
                                    doctorAvatar: doc['doctorAvatar'] ??
                                        'assets/dino.png',
                                    doctorName: doc['doctorName'],
                                    channelId: 'doctor-${doc['doctorId']}',
                                    patientId:
                                        FirebaseAuth.instance.currentUser!.uid,
                                  ),
                                ),
                              );
                            },
                          ),
                        // Report button - only shown for approved status
                        if (status == 'approved')
                          IconButton(
                            icon: Icon(Icons.report, color: Colors.red),
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
                  builder: (context) => HomePage(currentIndex: 0)),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => MessagesTab(currentIndex: 1)),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => Emergencymode(currentIndex: 2)),
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
