import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class VoiceCallScreen extends StatefulWidget {
  final String doctorAvatar;
  final String doctorName;
  final String channelId; // Pass channel ID from Firebase RDB
  final String patientId; // Pass patient ID from constructor

  VoiceCallScreen({
    required this.doctorAvatar,
    required this.doctorName,
    required this.channelId,
    required this.patientId,
  });

  @override
  _VoiceCallScreenState createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _isMuted = false; // Track the mute state
  bool _isSpeakerOn = false; // Track the speaker state
  String? _token;
  StreamSubscription<DatabaseEvent>? _callStatusSubscription;

  // Declare the database reference without initialization
  late final DatabaseReference _dbRef;

  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player for ringtone

  @override
  void initState() {
    super.initState();
    // Initialize the database reference here
    _dbRef =
        FirebaseDatabase.instance.ref('agoraChannels').child(widget.channelId);

    _initializeAgora();
    _playRingtone(); // Start playing the ringtone when the call starts
    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    _callStatusSubscription = _dbRef.onValue.listen((event) {
      if (!event.snapshot.exists) {
        // Call has been ended by the other party
        _handleRemoteCallEnd();
        return;
      }

      final callData = event.snapshot.value as Map<dynamic, dynamic>;
      if (callData['status'] == 'ended') {
        _handleRemoteCallEnd();
      }
    });
  }

  void _handleRemoteCallEnd() {
    _stopRingtone();
    _engine.leaveChannel();
    Navigator.pop(context);
  }

  Future<void> _initializeAgora() async {
    // Request microphone permission
    PermissionStatus microphoneStatus = await Permission.microphone.request();

    if (microphoneStatus != PermissionStatus.granted) {
      print('Microphone permission not granted');
      return; // Exit if permission is not granted
    } else {
      print('Microphone permission granted');
    }

    // Initialize Agora engine manually with the updated channel profile
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: '3a7bf343ec50426697144687e52dfac6',
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Explicitly enable local audio
    await _engine.enableAudio();
    print('Audio enabled');

    // Enable logging for debugging
    await _engine.setLogFile('/storage/emulated/0/Download/agora_log.txt');

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int uid) {
          setState(() {
            _joined = true;
          });
          print('Join channel: $uid');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUid = remoteUid;
          });
          print('Remote user joined: $remoteUid');
          _stopRingtone(); // Stop the ringtone when a remote user joins
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          setState(() {
            _remoteUid = null;
          });
          print('Remote user left channel: $remoteUid');
        },
      ),
    );

    // Generate token dynamically
    try {
      _token = await _generateToken(widget.channelId);

      if (_token != null) {
        await _engine.joinChannel(
          token: _token!,
          channelId: widget.channelId,
          uid: 0, // Use 0 for Agora to assign a unique UID for this user
          options: const ChannelMediaOptions(
            autoSubscribeAudio:
                true, // Automatically subscribe to all audio streams
            publishMicrophoneTrack: true, // Publish microphone audio
            clientRoleType: ClientRoleType
                .clientRoleBroadcaster, // Set user role to broadcaster
          ),
        );
      }
    } catch (e) {
      print('Error generating or using token: $e');
      // Optionally show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate call token')),
      );
    }

    // Ensure that the audio stream is not muted
    await _engine.muteLocalAudioStream(false);
    print('Audio stream unmuted');
  }

  // Play the ringtone and loop it until someone joins the channel
  Future<void> _playRingtone() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Loop the ringtone
    await _audioPlayer
        .play(AssetSource('audio/ringtone.mp3')); // Your ringtone file
    print('Playing ringtone...');
  }

  // Stop the ringtone when someone joins the channel
  Future<void> _stopRingtone() async {
    await _audioPlayer.stop();
    print('Ringtone stopped.');
  }

  // To mute or unmute the microphone
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
    print('Local audio is ${_isMuted ? "muted" : "unmuted"}');
  }

  // To toggle the speaker mode
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _engine.setEnableSpeakerphone(_isSpeakerOn);
    print('Speaker is ${_isSpeakerOn ? "on" : "off"}');
  }

  // Generate Agora token from Firebase Function
  Future<String?> _generateToken(String channelName) async {
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final result = await functions.httpsCallable('generateToken').call({
        'channelName': channelName,
        'patientId': widget.patientId // Make sure to pass this from constructor
      });

      final token = result.data['token'];
      print('Token generation successful via Firebase Function');

      // You can access additional data if needed
      return token;
    } catch (e) {
      print('Firebase Function token generation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate call token. Please try again.'),
          duration: Duration(seconds: 5),
        ),
      );
      return null;
    }
  }

  // To end the call and remove the channel from Firebase
  Future<void> _endCall() async {
    try {
      _stopRingtone();
      await _engine.leaveChannel();

      // Update call status in Firebase
      await _dbRef.update({
        'status': 'ended',
        'endTimestamp': ServerValue.timestamp,
      });

      // Remove the channel after a short delay to ensure all parties receive the 'ended' status
      Future.delayed(Duration(seconds: 2), () {
        _dbRef.remove();
      });

      Navigator.pop(context);
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  @override
  void dispose() {
    _stopRingtone();
    _callStatusSubscription?.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Call'),
        backgroundColor: Color(0xFF92A68A),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(widget.doctorAvatar),
            ),
            SizedBox(height: 10),
            Text(
              widget.doctorName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _joined
                ? (_remoteUid != null
                    ? Text('Connected to remote user: $_remoteUid')
                    : Text('Waiting for the remote user to join...'))
                : Text('Ringing...'),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _endCall,
                  child: Text('End Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _toggleMute,
                  child: Text(_isMuted ? 'Unmute' : 'Mute'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMuted ? Colors.grey : Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _toggleSpeaker,
                  child: Text(_isSpeakerOn ? 'Earpiece' : 'Speaker'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isSpeakerOn ? Colors.green : Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
