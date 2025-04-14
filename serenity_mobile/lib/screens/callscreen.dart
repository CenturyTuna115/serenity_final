import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:serenity_mobile/screens/homepage.dart';

class CallScreen extends StatefulWidget {
  final String doctorAvatar;
  final String doctorName;
  final String channelId;
  final String token; // Agora token obtained beforehand

  const CallScreen({
    Key? key,
    required this.doctorAvatar,
    required this.doctorName,
    required this.channelId,
    required this.token,
  }) : super(key: key);

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _speakerEnabled = false; // Tracks speakerphone mode.
  final String appId = '3a7bf343ec50426697144687e52dfac6';

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    // Request microphone permission
    PermissionStatus micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      print('Microphone permission not granted');
      return;
    }

    print("Initializing Agora engine for incoming call");
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
    await _engine.enableAudio();

    // Register event handlers
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int uid) {
        print("Local user joined channel: $uid");
        setState(() {
          _joined = true;
        });
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        print("Remote user joined: $remoteUid");
        setState(() {
          _remoteUid = remoteUid;
        });
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        print("Remote user left: $remoteUid");
        setState(() {
          _remoteUid = null;
        });
        // Automatically end the call when the remote user leaves.
        _endCall();
      },
    ));

    // Join the Agora channel using the provided token and channelId
    print("Joining channel ${widget.channelId} with token ${widget.token}");
    await _engine.joinChannel(
      token: widget.token,
      channelId: widget.channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
    print('Local audio is ${_isMuted ? "muted" : "unmuted"}');
  }

  // Function to toggle speaker mode.
  Future<void> _toggleSpeakerMode() async {
    setState(() {
      _speakerEnabled = !_speakerEnabled;
    });
    await _engine.setEnableSpeakerphone(_speakerEnabled);
    print('Speaker is now ${_speakerEnabled ? "enabled" : "disabled"}');
  }

  Future<void> _endCall() async {
    await _engine.leaveChannel();

    // Optionally, remove the channel info from the database if needed.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DatabaseReference dbRef =
          FirebaseDatabase.instance.ref('agoraChannels/${widget.channelId}');
      await dbRef.remove();
    }

    // Navigate to HomePage.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => HomePage(currentIndex: 0)),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Call in Progress"),
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
            const SizedBox(height: 10),
            Text(
              widget.doctorName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _joined
                ? (_remoteUid != null
                    ? Text('Connected with user: $_remoteUid')
                    : const Text('Waiting for the other user to join...'))
                : const Text('Joining channel...'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _endCall,
                  child: const Text("End Call"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _toggleMute,
                  child: Text(_isMuted ? "Unmute" : "Mute"),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _toggleSpeakerMode,
                  child: Text(_speakerEnabled ? "Speaker Off" : "Speaker On"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
