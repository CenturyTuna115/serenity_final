import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorProfile extends StatefulWidget {
  final String doctorId;

  DoctorProfile({required this.doctorId});

  @override
  _DoctorProfileState createState() => _DoctorProfileState();
}

class _DoctorProfileState extends State<DoctorProfile> {
  late DatabaseReference _doctorRef;
  Map<String, dynamic>? doctorData;

  @override
  void initState() {
    super.initState();
    _doctorRef = FirebaseDatabase.instance
        .ref('administrator/doctors/${widget.doctorId}');
    _fetchDoctorDetails();
  }

  void _fetchDoctorDetails() async {
    DataSnapshot snapshot = await _doctorRef.get();
    if (snapshot.value != null) {
      setState(() {
        doctorData =
            Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      });
    } else {
      setState(() {
        doctorData = {}; // or handle the case where no data is found
      });
      print('No data found for the specified doctor.');
    }
  }

  void _requestAppointment() {
    // Get the currently logged-in user
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Get the user's UID
      final String userUID = user.uid;

      // Create a new appointment request
      final appointmentRequest = {
        'userUID': userUID,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Push the appointment request to the doctor's appointments node
      _doctorRef.child('appointments').push().set(appointmentRequest).then((_) {
        // Show confirmation message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment request sent successfully')),
        );
      }).catchError((error) {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send appointment request: $error')),
        );
      });
    } else {
      // Handle the case where no user is logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No user is currently logged in')),
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
                      // Doctor's Profile Picture
                      Center(
                        child: CircleAvatar(
                          radius: 80,
                          backgroundImage:
                              NetworkImage(doctorData!['profilePic'] ?? ''),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Doctor's Name (Centered)
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

                      // Specialization (Left-aligned)
                      Text(
                        doctorData!['specialization'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 20),

                      // Description (Left-aligned)
                      Text(
                        doctorData!['description'] ??
                            'No description available.',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 20),

                      // Address (Left-aligned)
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
                      SizedBox(height: 20),

                      // Age (Left-aligned)
                      Row(
                        children: [
                          Icon(Icons.cake, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Age: ${doctorData!['age'] ?? 'Unknown'}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Experience (Left-aligned)
                      Row(
                        children: [
                          Icon(Icons.work_outline, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${doctorData!['experience'] ?? '0'} years of experience',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // License Number (Left-aligned)
                      Row(
                        children: [
                          Icon(Icons.verified_user, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'License: ${doctorData!['license'] ?? 'Unknown'}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Gender (Left-aligned)
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Gender: ${doctorData!['gender'] ?? 'Unknown'}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Graduated (Left-aligned)
                      Row(
                        children: [
                          Icon(Icons.school, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Graduated: ${doctorData!['graduated'] ?? 'Unknown'}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.black54),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 40),

                      // Credentials (Images, Left-aligned) - Moved Last
                      Text(
                        'Credentials:',
                        style: TextStyle(fontSize: 18, color: Colors.black87),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 10),
                      if (doctorData!['credentials'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var credentialUrl
                                in doctorData!['credentials'])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Image.network(credentialUrl),
                              ),
                          ],
                        ),
                      SizedBox(height: 20),

                      // Schedule Appointment Button (Centered)
                      Center(
                        child: ElevatedButton(
                          onPressed: _requestAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFFA726), // Button color
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
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
                      ),
                    ],
                  ),
                ),
    );
  }
}
