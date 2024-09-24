import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/resources/common/toast.dart';

class ReportDoctorScreen extends StatefulWidget {
  final String doctorId; // The ID of the doctor to report
  ReportDoctorScreen({required this.doctorId});

  @override
  _ReportDoctorScreenState createState() => _ReportDoctorScreenState();
}

class _ReportDoctorScreenState extends State<ReportDoctorScreen> {
  final TextEditingController _reportController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  void _submitReport() async {
    String report = _reportController.text.trim();
    User? user = FirebaseAuth.instance.currentUser;

    if (report.isEmpty) {
      showToast(message: "Please provide details for the report.");
      return;
    }

    if (user == null) {
      showToast(message: "You must be logged in to submit a report.");
      return;
    }

    try {
      // Create a unique report ID
      String reportId =
          _database.child('administrator/reports').push().key ?? '';

      // Prepare the report data
      Map<String, dynamic> reportData = {
        'reporterId': user.uid,
        'doctorId': widget.doctorId,
        'reportDetails': report,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Store the report under administrator/reports
      await _database.child('administrator/reports/$reportId').set(reportData);

      // Notify the user
      showToast(message: "Report submitted successfully.");
      Navigator.pop(context);
    } catch (e) {
      showToast(message: "Failed to submit report: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Report Doctor"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Provide the details of your report:",
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            TextField(
              controller: _reportController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Enter your report here...",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitReport,
              child: Text("Submit Report"),
            ),
          ],
        ),
      ),
    );
  }
}
