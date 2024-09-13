import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart'; // Import the audioplayers package

class VoiceCallScreen extends StatefulWidget {
  final String doctorAvatar;
  final String doctorName;
  final String channelId; // Pass channelId to the screen

  VoiceCallScreen({
    required this.doctorAvatar,
    required this.doctorName,
    required this.channelId, // Expect channelId here
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
  final String appId = '3a7bf343ec50426697144687e52dfac6'; // Agora App ID

  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player for ringtone

  @override
  void initState() {
    super.initState();
    _initializeAgora();
    _playRingtone(); // Play ringtone when call starts
  }

  Future<void> _initializeAgora() async {
    // Request microphone permission
    PermissionStatus microphoneStatus = await Permission.microphone.request();

    if (microphoneStatus != PermissionStatus.granted) {
      print('Microphone permission not granted');
      return; // Exit if permission is not granted
    }

    // Initialize Agora engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: '3a7bf343ec50426697144687e52dfac6',
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Enable audio
    await _engine.enableAudio();
    print('Audio enabled');

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int uid) {
          setState(() {
            _joined = true;
          });
          print('Join channel: $uid');
          _stopRingtone(); // Stop ringtone when the call is connected
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _remoteUid = remoteUid;
          });
          print('Remote user joined: $remoteUid');
          _stopRingtone(); // Stop ringtone when remote user joins
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

    // Join the channel using the channelId and token
    await _engine.joinChannel(
      token:
          '007eJxTYGB10zhjai7y4/bGzl2iO478cpkf8Xzz29TUtX7H3zTXbc9RYDBONE9KMzYxTk02NTAxMjOzNDc0MTGzME81NUpJS0w2Uw98nNYQyMhg5aHFxMgAgSA+B0NeVmJOUmp+MQMDACQXIYc=', // Replace with actual token logic
      channelId: widget.channelId,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  // Play the ringtone when the call starts
  Future<void> _playRingtone() async {
    await _audioPlayer.play(AssetSource('audio/ringtone.mp3'));
    print('Playing ringtone...');
  }

  // Stop the ringtone when the call is answered or ends
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

  // To end the call and remove the channel from Firebase
  Future<void> _endCall() async {
    // Stop ringtone if still playing
    _stopRingtone();

    // Leave the Agora channel
    await _engine.leaveChannel();
    print('Left Agora channel');

    // Remove the channel from Firebase Realtime Database
    DatabaseReference dbRef =
        FirebaseDatabase.instance.ref('agoraChannels/${widget.channelId}');
    await dbRef.remove();
    print('Channel ${widget.channelId} removed from Firebase');

    // Pop the screen and go back to the previous screen
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _stopRingtone(); // Stop ringtone if the widget is disposed
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
            const SizedBox(height: 10),
            Text(
              widget.doctorName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
