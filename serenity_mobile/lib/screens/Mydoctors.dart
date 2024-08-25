import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'doctor_profile.dart';
import 'chatScreen.dart';
import 'dart:async';

class MyDoctors extends StatefulWidget {
  @override
  _MyDoctorsState createState() => _MyDoctorsState();
}

class _MyDoctorsState extends State<MyDoctors> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> myDoctorsList = [];
  List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchMyDoctors();
  }

  @override
  void dispose() {
    // Cancel all subscriptions when the widget is disposed
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _fetchMyDoctors() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userDoctorsRef =
          _dbRef.child('administrator/users/${user.uid}/mydoctor');
      DatabaseEvent event = await userDoctorsRef.once();

      if (event.snapshot.exists) {
        List<Map<String, dynamic>> doctorsList = [];
        Map<dynamic, dynamic> doctorsData =
            event.snapshot.value as Map<dynamic, dynamic>;

        for (var entry in doctorsData.entries) {
          final doctorKey =
              entry.key; // This is the reference key under mydoctor
          final doctorInfo = entry.value as Map<dynamic, dynamic>;

          // Check both keys "docID" and "doctorId"
          final String? docID = doctorInfo['docID'] as String? ??
              doctorInfo['doctorId'] as String?;

          if (docID == null) {
            continue; // Skip this entry if docID is null
          }

          DataSnapshot doctorSnapshot =
              await _dbRef.child('administrator/doctors/$docID').get();
          if (doctorSnapshot.exists) {
            Map<String, dynamic> doctorDetails =
                Map<String, dynamic>.from(doctorSnapshot.value as Map);

            String profilePicUrl = doctorDetails['profilePic'] ??
                'https://via.placeholder.com/150';

            Map<String, dynamic> doctorData = {
              'docID': docID,
              'doctorName': doctorDetails['name'] ?? 'Unknown',
              'status': doctorInfo['status'] ?? 'Unknown',
              'profilePic': profilePicUrl,
              'doctorKey': doctorKey,
            };

            // Add a listener for real-time status updates
            _listenForStatusUpdates(user.uid, doctorKey, doctorData);

            doctorsList.add(doctorData);
          }
        }

        setState(() {
          myDoctorsList = doctorsList;
        });
      }
    }
  }

  void _listenForStatusUpdates(
      String userId, String doctorKey, Map<String, dynamic> doctorData) {
    DatabaseReference statusRef =
        _dbRef.child('administrator/users/$userId/mydoctor/$doctorKey/status');

    // Listen for changes in the status field
    StreamSubscription<DatabaseEvent> subscription =
        statusRef.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        String newStatus = event.snapshot.value as String;
        setState(() {
          doctorData['status'] = newStatus;
        });
      }
    });

    // Store the subscription to be canceled later
    _subscriptions.add(subscription);
  }

  void _sendMessage(String doctorId, String doctorName, String doctorAvatar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userName: doctorName,
          userAvatar: doctorAvatar,
          userId: doctorId,
        ),
      ),
    );
  }

  void _deleteDoctor(String doctorId, String doctorKey) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userDoctorsRef =
          _dbRef.child('administrator/users/${user.uid}/mydoctor/$doctorKey');
      DatabaseReference doctorPatientsRef =
          _dbRef.child('administrator/doctors/$doctorId/mypatient/$doctorKey');

      // Start both deletion tasks
      Future<void> deleteUserDoctor = userDoctorsRef.remove();
      Future<void> deleteDoctorPatient = doctorPatientsRef.remove();

      try {
        // Wait for both deletions to complete
        await Future.wait([deleteUserDoctor, deleteDoctorPatient]);

        setState(() {
          myDoctorsList.removeWhere((doctor) => doctor['docID'] == doctorId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Doctor removed successfully')),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove doctor: $error')),
        );
      }
    }
  }

  Icon _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      // Ensure case-insensitive comparison
      case 'approved': // Handle the approved status
        return Icon(Icons.check_circle, color: Colors.green, size: 18);
      case 'pending':
        return Icon(Icons.hourglass_empty, color: Colors.orange, size: 18);
      default:
        return Icon(Icons.help_outline, color: Colors.grey, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Doctors'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: myDoctorsList.isEmpty
          ? Center(child: Text('No doctors found.'))
          : ListView.builder(
              itemCount: myDoctorsList.length,
              itemBuilder: (context, index) {
                final doctor = myDoctorsList[index];
                return Card(
                  margin: EdgeInsets.all(10.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(doctor['profilePic']),
                    ),
                    title: Text(
                      doctor['doctorName'] ?? 'Unknown',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Status: ${doctor['status']}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        _getStatusIcon(doctor['status']),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 0, // space between two icons
                      children: [
                        IconButton(
                          icon: Icon(Icons.message, color: Colors.green),
                          onPressed: () {
                            _sendMessage(
                              doctor['docID'],
                              doctor['doctorName'],
                              doctor['profilePic'],
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteDoctor(
                              doctor['docID'],
                              doctor['doctorKey'],
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorProfile(
                            doctorId: doctor['docID'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
