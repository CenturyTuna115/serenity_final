import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/firebase_database.dart' show ServerValue;
import 'package:flutter/material.dart';
import 'package:serenity_mobile/screens/callscreen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String doctorAvatar;
  final String doctorName;
  final String channelId; // This is the Agora channel name
  final String token; // Agora token
  final String patientId;

  const IncomingCallScreen({
    Key? key,
    required this.doctorAvatar,
    required this.doctorName,
    required this.channelId,
    required this.token,
    required this.patientId,
  }) : super(key: key);

  @override
  _IncomingCallScreenState createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    // Point to the specific channel record in the Realtime Database.
    _dbRef =
        FirebaseDatabase.instance.ref('agoraChannels').child(widget.channelId);
    print("IncomingCallScreen initialized for channel: ${widget.channelId}");
  }

  // Accept the call: update status and navigate to CallScreen.
  void _acceptCall() async {
    print("Accepting call for channel: ${widget.channelId}");
    await _dbRef.update({
      'status': 'connected',
      'acceptTimestamp': ServerValue.timestamp,
    }).catchError((error) {
      print("Error updating call status to accepted: $error");
    });
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          doctorAvatar: widget.doctorAvatar,
          doctorName: widget.doctorName,
          channelId: widget.channelId,
          token: widget.token,
        ),
      ),
    );
  }

  // Decline the call: update status and close the screen.
  void _declineCall() async {
    print("Declining call for channel: ${widget.channelId}");
    await _dbRef.update({
      'status': 'declined',
      'endTimestamp': ServerValue.timestamp,
    }).catchError((error) {
      print("Error updating call status to ended: $error");
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Semi-transparent dark background for an incoming call overlay.
      backgroundColor: Colors.black.withOpacity(0.7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Caller avatar.
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.doctorAvatar.isNotEmpty
                  ? (widget.doctorAvatar.startsWith('http')
                      ? NetworkImage(widget.doctorAvatar)
                      : AssetImage(widget.doctorAvatar))
                  : const AssetImage('assets/johndoe.jpg') as ImageProvider,
            ),
            const SizedBox(height: 20),
            // Caller name and message.
            Text(
              '${widget.doctorName} is calling...',
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 30),
            // Accept and Decline buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _acceptCall,
                  child: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _declineCall,
                  child: const Text('Decline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
