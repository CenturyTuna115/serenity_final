import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'doctor_profile.dart'; // Import the DoctorProfile screen
import 'chatScreen.dart'; // Import the ChatScreen

class MyDoctors extends StatefulWidget {
  @override
  _MyDoctorsState createState() => _MyDoctorsState();
}

class _MyDoctorsState extends State<MyDoctors> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> doctorAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctorAppointments();
  }

  void _fetchDoctorAppointments() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userAppointmentsRef =
          _dbRef.child('administrator/users/${user.uid}/appointments');
      DatabaseEvent event = await userAppointmentsRef.once();

      if (event.snapshot.exists) {
        List<Map<String, dynamic>> appointmentsList = [];
        Map<dynamic, dynamic> appointmentsData =
            event.snapshot.value as Map<dynamic, dynamic>;

        for (var entry in appointmentsData.entries) {
          final appointmentKey = entry.key;
          final appointment = entry.value as Map<dynamic, dynamic>;
          
          // Assuming the doctor ID is not the key but stored inside the appointment data
          final doctorId = appointment['doctorId'];

          // Fetch doctor details
          DataSnapshot doctorSnapshot =
              await _dbRef.child('administrator/doctors/$doctorId').get();
          if (doctorSnapshot.exists) {
            Map<String, dynamic> doctorData =
                Map<String, dynamic>.from(doctorSnapshot.value as Map);
            doctorData['appointmentStatus'] = appointment['status'];
            doctorData['appointmentKey'] = appointmentKey; // Store appointment key
            doctorData['doctorId'] = doctorId; // Add the doctorId to the data
            appointmentsList.add(doctorData);
          }
        }

        setState(() {
          doctorAppointments = appointmentsList;
        });
      }
    }
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

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icon(Icons.check_circle, color: Colors.green);
      case 'declined':
        return Icon(Icons.cancel, color: Colors.red);
      case 'pending':
        return Icon(Icons.hourglass_empty, color: Colors.orange);
      default:
        return Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Doctors'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: doctorAppointments.isEmpty
          ? Center(child: Text('No appointments found.'))
          : ListView.builder(
              itemCount: doctorAppointments.length,
              itemBuilder: (context, index) {
                final doctor = doctorAppointments[index];
                return Card(
                  margin: EdgeInsets.all(10.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(doctor['profilePic']),
                    ),
                    title: Text(doctor['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Specialization: ${doctor['specialization']}'),
                        Row(
                          children: [
                            Text('Status: ${doctor['appointmentStatus']}'),
                            SizedBox(width: 8),
                            _getStatusIcon(doctor['appointmentStatus']),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.message, color: Colors.green),
                      onPressed: () {
                        _sendMessage(
                          doctor['doctorId'],
                          doctor['name'],
                          doctor['profilePic'],
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorProfile(
                            doctorId: doctor['doctorId'],
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
