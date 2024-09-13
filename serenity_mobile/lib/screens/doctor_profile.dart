import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat.dart';

class DoctorProfile extends StatefulWidget {
  final String doctorId;

  DoctorProfile({required this.doctorId});

  @override
  _DoctorProfileState createState() => _DoctorProfileState();
}

class _DoctorProfileState extends State<DoctorProfile> {
  late DatabaseReference _doctorRef;
  Map<String, dynamic>? doctorData;
  String? appointmentStatus;

  @override
  void initState() {
    super.initState();
    _doctorRef = FirebaseDatabase.instance
        .ref('administrator/doctors/${widget.doctorId}');
    _fetchDoctorDetails();
    _fetchAppointmentStatus();
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

  void _fetchAppointmentStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userDoctorRef = FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/mydoctor');
      DataSnapshot snapshot = await userDoctorRef.get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> appointmentsData =
            snapshot.value as Map<dynamic, dynamic>;

        appointmentsData.forEach((key, value) {
          if (value['doctorId'] == widget.doctorId) {
            setState(() {
              appointmentStatus = value['status'];
            });
          }
        });
      }
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
        'doctorId': widget.doctorId,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Push the appointment request to the doctor's appointments node
      DatabaseReference newAppointmentRef =
          _doctorRef.child('appointments').push();
      newAppointmentRef
          .set({'userUID': userUID, ...appointmentRequest}).then((_) {
        // Push the same appointment request to the current user's mydoctor node
        DatabaseReference userDoctorRef = FirebaseDatabase.instance.ref(
            'administrator/users/$userUID/mydoctor/${newAppointmentRef.key}');

        userDoctorRef.set({
          'doctorId': widget.doctorId,
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        }).then((_) {
          // Update 'assigned_doctor' in the user's node
          DatabaseReference userRef =
              FirebaseDatabase.instance.ref('administrator/users/$userUID');
          userRef.update({
            'assigned_doctor': true, // Update assigned_doctor to true
          }).then((_) {
            // Show confirmation message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Appointment request sent and doctor assigned successfully')),
            );
            // Update the local status
            setState(() {
              appointmentStatus = 'pending';
            });
          }).catchError((error) {
            // Handle error for assigned_doctor update
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Failed to update assigned_doctor status: $error')),
            );
          });
        }).catchError((error) {
          // Handle error for user's mydoctor node
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to send appointment request to user: $error')),
          );
        });
      }).catchError((error) {
        // Handle error for doctor's appointments node
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to send appointment request to doctor: $error')),
        );
      });
    } else {
      // Handle the case where no user is logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No user is currently logged in')),
      );
    }
  }

  void _sendMessage() {
    // Navigate to ChatScreen with the doctor's details
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

                      // Credentials (Images, Left-aligned) - Slideshow
                      Text(
                        'Credentials',
                        style: TextStyle(
                            fontSize: 18,
                            color: Color.fromARGB(255, 76, 175, 160)),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 10),
                      if (doctorData!['credentials'] != null)
                        Container(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: doctorData!['credentials'].length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: Image.network(
                                  doctorData!['credentials'][index],
                                  fit: BoxFit.cover,
                                  height: 200,
                                ),
                              );
                            },
                          ),
                        ),
                      SizedBox(height: 20),

                      // Schedule Appointment and Message Buttons (Centered)
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: appointmentStatus == 'approved'
                                  ? null
                                  : _requestAppointment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appointmentStatus == 'approved'
                                    ? Colors.grey
                                    : Color(0xFFFFA726), // Button color
                                padding: EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                              child: Text(
                                'Assign',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            ElevatedButton(
                              onPressed: _sendMessage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromARGB(
                                    255, 76, 175, 160), // Button color
                                padding: EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                              child: Icon(
                                Icons.message,
                                color: Colors.white,
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
