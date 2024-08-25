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
  List<Map<String, dynamic>> myDoctorsList = [];

  @override
  void initState() {
    super.initState();
    _fetchMyDoctors();
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

          final String? docID = doctorInfo['docID'] as String?;

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

            doctorsList.add(doctorData);
          }
        }

        setState(() {
          myDoctorsList = doctorsList;
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

  void _deleteDoctor(String doctorId, String doctorKey) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userDoctorsRef =
          _dbRef.child('administrator/users/${user.uid}/mydoctor/$doctorKey');

      await userDoctorsRef.remove().then((_) {
        setState(() {
          myDoctorsList.removeWhere((doctor) => doctor['docID'] == doctorId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Doctor removed successfully')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove doctor: $error')),
        );
      });
    }
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icon(Icons.check_circle, color: Colors.green, size: 18);
      case 'declined':
        return Icon(Icons.cancel, color: Colors.red, size: 18);
      case 'pending':
        return Icon(Icons.hourglass_empty, color: Colors.orange, size: 18);
      default :
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
