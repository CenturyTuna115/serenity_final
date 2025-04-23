import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/resources/common/toast.dart';
import 'package:intl/intl.dart';

class ReportDoctorScreen extends StatefulWidget {
  final String doctorId;
  ReportDoctorScreen({required this.doctorId});

  @override
  _ReportDoctorScreenState createState() => _ReportDoctorScreenState();
}

class _ReportDoctorScreenState extends State<ReportDoctorScreen> {
  final TextEditingController _reportController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Set<String> _selectedReasons = {}; // Change from String? to Set<String>

  final List<String> _reportReasons = [
    'Sexual',
    'Profanities',
    'Fraud',
    'Harrassment',
    'Privacy Violation',
    'Violence',
    'Misinformation',
    'Discrimination',
  ];

  void _submitReport() async {
    String details = _reportController.text.trim();
    User? user = FirebaseAuth.instance.currentUser;

    if (_selectedReasons.isEmpty) {
      showToast(message: "Please select at least one reason for reporting.");
      return;
    }

    if (details.isEmpty) {
      showToast(message: "Please provide more details about the issue.");
      return;
    }

    if (user == null) {
      showToast(message: "You must be logged in to submit a report.");
      return;
    }

    try {
      // Generate a unique report ID
      String reportId =
          _database.child('administrator/reports').push().key ?? '';

      // Join all selected reasons with commas and add a comma before details
      String reportDetails = '${_selectedReasons.join(',')},$details';

      // Format timestamp as "yyyy-MM-dd HH:mm:ss"
      String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.now().toUtc().add(const Duration(hours: 8)));

      // Create the report data structure
      Map<String, String> reportData = {
        'reportDetails': reportDetails,
        'reportedId': widget.doctorId,
        'reporterId': user.uid,
        'timestamp': timestamp,
      };

      // Save to the database under administrator/reports/{reportId}
      await _database
          .child('administrator/reports')
          .child(reportId)
          .set(reportData);

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Report",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Serenity ensures that the users experience a friendly and formal environment. Please provide details about the issue. Our team will review your report and take appropriate action.",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Why are you reporting this user? (Select all that apply)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: _reportReasons.map((reason) {
                  final isSelected = _selectedReasons.contains(reason);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedReasons.remove(reason);
                        } else {
                          _selectedReasons.add(reason);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            reason,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                "More Details",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _reportController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: "Please provide additional details...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Submit",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
