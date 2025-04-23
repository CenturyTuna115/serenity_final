import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart'; // Import intl for date/time formatting.

// Import your chat and voice call screens accordingly.
import 'chat.dart';
import 'voicecallscreen.dart';
import 'reports.dart';

void main() async {
  // Ensure Firebase initialization.
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(); // Uncomment and configure as needed.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // Root widget for the application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Doctors App',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const MyDoctors(), // Set MyDoctors widget as the home screen.
    );
  }
}

class MyDoctors extends StatefulWidget {
  final int currentIndex;
  final void Function(int count)? onRecentApprovalsChanged;

  const MyDoctors({
    Key? key,
    this.currentIndex = 0,
    this.onRecentApprovalsChanged,
  }) : super(key: key);

  @override
  _MyDoctorsState createState() => _MyDoctorsState();
}

class _MyDoctorsState extends State<MyDoctors>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> myAppointments = [];
  List<Map<String, dynamic>> scheduledAppointments = [];
  late TabController _tabController;

  // Store any real-time listeners here.
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // First fetch the appointments (assigned doctors) then scheduled ones.
    _fetchAppointments().then((_) {
      _fetchScheduledAppointments();
      _checkRecentApprovals();
    });
    _setupNotificationListener();
  }

  void _checkRecentApprovals() {
    if (widget.onRecentApprovalsChanged == null) return;

    final now = DateTime.now();
    final recentApprovals = myAppointments.where((appt) {
      if (appt['status'] != 'approved') return false;
      if (appt['timestamp'] == null) return false;
      try {
        final approvalTime = DateTime.parse(appt['timestamp']);
        return now.difference(approvalTime).inHours <= 24;
      } catch (e) {
        return false;
      }
    }).length;

    widget.onRecentApprovalsChanged!(recentApprovals);
  }

  void _setupNotificationListener() {
    // Listen for incoming call notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'call') {
        _handleIncomingCall(
          message.data['doctorId'] ?? '',
          message.data['doctorName'] ?? 'Unknown Doctor',
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

  void _handleReport(String doctorId, String doctorName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDoctorScreen(
          doctorId: doctorId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel all active subscriptions to avoid memory leaks.
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  /// Fetch appointments from all doctors by checking the "Appointments" and "mypatients" nodes.
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
          doctorSnapshot.child('profilePic').value?.toString() ??
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

  /// Iterates over the user’s assigned doctor(s) from myAppointments and fetches the scheduled appointments
  /// from administrator/doctors/(DoctorID)/scheduled_appointments.
  Future<void> _fetchScheduledAppointments() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String currentUserId = user.uid;

    List<Map<String, dynamic>> tempList = [];

    // Iterate over each doctor already assigned (from myAppointments)
    for (var doc in myAppointments) {
      final String doctorId = doc['doctorId'];
      // Path for the doctor's scheduled appointments
      final DataSnapshot snapshot = await _dbRef
          .child('administrator/doctors/$doctorId/scheduled_appointments')
          .get();

      if (!snapshot.exists) continue;

      // Iterate over each scheduled appointment for the doctor.
      for (var apptSnapshot in snapshot.children) {
        final Map<dynamic, dynamic> apptData =
            apptSnapshot.value as Map<dynamic, dynamic>;

        // Check if the appointment is for the current user.
        if (apptData['appointmentUserId'] == currentUserId) {
          tempList.add({
            'appointmentTitle': apptData['appointmentTitle'] ?? 'No Title',
            'appointmentDate': apptData['appointmentDate'] ?? 'N/A',
            'appointmentStartTime': apptData['appointmentStartTime'] ?? 'N/A',
            'appointmentEndTime': apptData['appointmentEndTime'] ?? 'N/A',
            'appointmentPatient': apptData['appointmentPatient'] ?? 'N/A',
            'color': apptData['color'] ?? '#FFFFFF',
            // Optionally include doctor info.
            'doctorId': doctorId,
            'doctorName': doc['doctorName'],
          });
        }
      }
    }

    setState(() {
      scheduledAppointments = tempList;
    });
  }

  /// Helper to build the Scheduled Appointments tab with formatted date and time.
  Widget _buildScheduledAppointmentsTab() {
    return scheduledAppointments.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No scheduled appointments found.'),
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
            itemCount: scheduledAppointments.length,
            itemBuilder: (context, index) {
              final appointment = scheduledAppointments[index];

              // Format the date and time fields.
              final String formattedDate =
                  _formatDate(appointment['appointmentDate']);
              final String formattedStartTime =
                  _formatTime(appointment['appointmentStartTime']);
              final String formattedEndTime =
                  _formatTime(appointment['appointmentEndTime']);

              return Card(
                margin: const EdgeInsets.all(10.0),
                color: Color(_hexToColor(appointment['color'] as String)),
                child: ListTile(
                  title: Text(
                    appointment['appointmentTitle'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Date: $formattedDate\n'
                    'Start: $formattedStartTime\n'
                    'End: $formattedEndTime\n'
                    'Patient: ${appointment['appointmentPatient']}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
  }

  /// Helper function to parse a hex color string like "#ffb6a6" into an integer.
  int _hexToColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Add alpha value if missing.
    }
    return int.parse(hexColor, radix: 16);
  }

  /// Converts a date string (assumed to be in "yyyy-MM-dd") into a formatted string,
  /// e.g. "Friday, March 3, 2025".
  String _formatDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  /// Converts a time string (assumed to be in "HH:mm") into a formatted string with AM/PM,
  /// e.g. "2:30 PM".
  String _formatTime(String timeStr) {
    try {
      DateTime time = DateFormat("HH:mm").parse(timeStr);
      return DateFormat.jm().format(time);
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Doctors'),
          backgroundColor: const Color(0xFF92A68A),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'My Doctors'),
              Tab(text: 'Scheduled Appointments'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // My Doctors Tab.
            myAppointments.isEmpty
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
                      final String status =
                          doc['status']?.toString() ?? 'unknown';
                      final String timestamp =
                          doc['timestamp']?.toString() ?? 'N/A';

                      return Card(
                        margin: const EdgeInsets.all(10.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: doc['doctorAvatar']
                                    .toString()
                                    .startsWith('assets/')
                                ? AssetImage(doc['doctorAvatar'])
                                : NetworkImage(doc['doctorAvatar'])
                                    as ImageProvider,
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
                              if (status == 'approved')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.call,
                                          color: Colors.green),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => VoiceCallScreen(
                                            doctorId: doc['doctorId'],
                                            doctorAvatar: doc['doctorAvatar'],
                                            doctorName: doc['doctorName'],
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.message,
                                          color: Colors.blue),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            userName: doc['doctorName'],
                                            userAvatar: doc['doctorAvatar'],
                                            userId: doc['doctorId'],
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.report,
                                          color: Colors.red),
                                      onPressed: () => _handleReport(
                                          doc['doctorId'], doc['doctorName']),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // Scheduled Appointments Tab.
            _buildScheduledAppointmentsTab(),
          ],
        ),
      ),
    );
  }
}
