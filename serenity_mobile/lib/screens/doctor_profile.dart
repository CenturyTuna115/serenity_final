import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:serenity_mobile/screens/homepage.dart';
import 'chat.dart';
import 'package:intl/intl.dart'; // Add this import

class DoctorProfile extends StatefulWidget {
  final String doctorId;

  DoctorProfile({required this.doctorId});

  @override
  _DoctorProfileState createState() => _DoctorProfileState();
}

class _DoctorProfileState extends State<DoctorProfile> {
  late DatabaseReference _doctorRef;
  late DatabaseReference _userRef;
  Map<String, dynamic>? doctorData;
  User? _currentUser;
  bool _isAppointedToThisDoctor = false;
  bool _isDoctorAvailable = true; // To track doctor's availability
  bool _hasAssignedDoctors = false; // To track if user has any assigned doctors

  @override
  void initState() {
    super.initState();
    _doctorRef = FirebaseDatabase.instance
        .ref('administrator/doctors/${widget.doctorId}');
    _currentUser = FirebaseAuth.instance.currentUser;
    _userRef = FirebaseDatabase.instance
        .ref('administrator/users/${_currentUser?.uid}');
    _fetchDoctorDetails();
    _checkIfAppointedToThisDoctor();
    _checkAssignedDoctors();
  }

  void _fetchDoctorDetails() async {
    DataSnapshot snapshot = await _doctorRef.get();
    if (snapshot.value != null) {
      setState(() {
        doctorData =
            Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
        _isDoctorAvailable =
            doctorData!['isAvailable'] ?? true; // Check availability
      });
    } else {
      setState(() {
        doctorData = {};
      });
      print('No data found for the specified doctor.');
    }
  }

  Future<void> _checkIfAppointedToThisDoctor() async {
    if (_currentUser == null) return;

    final userId = _currentUser!.uid;

    // Check if the Appointments node exists
    final snapshot = await _doctorRef.child('Appointments').get();
    if (snapshot.exists) {
      final appointments =
          Map<dynamic, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      for (var entry in appointments.values) {
        if (entry['userId'] == userId) {
          setState(() {
            _isAppointedToThisDoctor = true;
          });
          return;
        }
      }
    }

    // Check the status in the user's "mydoctors" node
    final myDoctorsSnapshot =
        await _userRef.child('mydoctors').child(widget.doctorId).get();
    if (myDoctorsSnapshot.exists) {
      final myDoctorData =
          Map<String, dynamic>.from(myDoctorsSnapshot.value as Map);
      if (myDoctorData['status'] == 'pending' ||
          myDoctorData['status'] == 'approved') {
        setState(() {
          _isAppointedToThisDoctor = true;
        });
        return;
      }
    }

    // If Appointments node does not exist or userId is not found
    setState(() {
      _isAppointedToThisDoctor = false;
    });
  }

  String formatSpecialization(dynamic specialization) {
    if (specialization is List) {
      return specialization.join(', ');
    } else if (specialization is String) {
      return specialization;
    } else {
      return 'Unknown';
    }
  }

  Future<void> _checkAssignedDoctors() async {
    if (_currentUser == null) {
      print('No current user');
      return;
    }

    print('Checking doctor status for user: ${_currentUser!.uid}');

    // Check the status for this specific doctor
    final myDoctorSnapshot =
        await _userRef.child('mydoctors').child(widget.doctorId).get();

    if (myDoctorSnapshot.exists) {
      final myDoctorData =
          Map<String, dynamic>.from(myDoctorSnapshot.value as Map);
      print('Doctor status: ${myDoctorData['status']}');

      setState(() {
        _hasAssignedDoctors = myDoctorData['status'] == 'approved';
      });
      return;
    }

    print('No doctor relationship found');
    setState(() {
      _hasAssignedDoctors = false;
    });
  }

  void _sendMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userName: doctorData!['name'] ?? 'Unknown',
          userAvatar: doctorData!['profilePic'] ?? 'assets/dino.png',
          userId: widget.doctorId,
        ),
      ),
    );
  }

  Future<void> _assignDoctor() async {
    if (_currentUser == null) {
      print("No user is logged in.");
      return;
    }

    try {
      final userId = _currentUser!.uid;

      // Fetch the user's full name from the database
      final userSnapshot = await _userRef.get();
      String userName = 'Unknown User';

      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        userName = userData['full_name'] ?? 'Unknown User';
      }

      // Format the timestamp as yyyy-MM-dd HH:mm:ss
      String timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Add the doctor to the user's "mydoctors" node with a status of "pending"
      await _userRef.child('mydoctors').child(widget.doctorId).set({
        'doctorId': widget.doctorId,
        'doctorName': doctorData!['name'] ?? 'Unknown',
        'status': 'pending', // Add status here
        'timestamp': timestamp, // Add formatted timestamp
      });

      // Add the userId under the doctor's Appointments node with a status of "pending"
      await _doctorRef.child('Appointments').push().set({
        'userId': userId,
        'userName': userName,
        'timestamp': timestamp, // Add formatted timestamp
        'status': 'pending', // Add status here
      });

      // Don't set assigned_doctor flag here - it will be set when status changes to approved

      print("Doctor appointment request added successfully.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Doctor appointed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to the homepage after assigning
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      print("Failed to appoint doctor: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to appoint doctor. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Profile'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: doctorData == null
          ? Center(child: CircularProgressIndicator())
          : doctorData!.isEmpty
              ? Center(child: Text('No data available for this doctor.'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 80,
                          backgroundImage:
                              NetworkImage(doctorData!['profilePic'] ?? ''),
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Text(
                          doctorData!['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        formatSpecialization(doctorData!['specialization']),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 20),
                      Text(
                        doctorData!['description'] ??
                            'No description available.',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              doctorData!['address'] ?? 'Unknown',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed:
                                  _hasAssignedDoctors ? _sendMessage : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFFFA726),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                              child: Text(
                                'Send Message',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white),
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: (_isAppointedToThisDoctor ||
                                      !_isDoctorAvailable)
                                  ? null
                                  : _assignDoctor,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isAppointedToThisDoctor ||
                                        !_isDoctorAvailable)
                                    ? Colors.grey
                                    : Color(0xFF66BB6A),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                              child: Text(
                                _isAppointedToThisDoctor
                                    ? 'Already Appointed'
                                    : (!_isDoctorAvailable
                                        ? 'Unavailable'
                                        : 'Appoint'),
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
