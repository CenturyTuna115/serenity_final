import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:audioplayers/audioplayers.dart';

final logger = Logger('VoiceCallScreen');

class VoiceCallScreen extends StatefulWidget {
  final String doctorAvatar;
  final String doctorName;
  final String doctorId; // Doctor's ID

  const VoiceCallScreen({
    Key? key,
    required this.doctorAvatar,
    required this.doctorName,
    required this.doctorId,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late RtcEngine _engine;
  AudioPlayer? _audioPlayer;
  bool _joined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  final String appId =
      '3a7bf343ec50426697144687e52dfac6'; // Replace with your App ID
  final String _cloudFunctionUrl =
      'https://asia-southeast1-serenity-c800c.cloudfunctions.net/generateToken';

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      print('Microphone permission not granted');
      return;
    }

    // Create engine and initialize
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(
        appId: '3a7bf343ec50426697144687e52dfac6',
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Minimal audio setup
    await _engine.enableAudio();
    await _engine.enableLocalAudio(true);

    // Enable volume indication for debugging
    await _engine.enableAudioVolumeIndication(
      interval: 200,
      smooth: 3,
      reportVad: true,
    );

    // Register event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int uid) {
          print('Local user joined: $uid');
          setState(() => _joined = true);
          // Start playing the ringtone while waiting for the remote user
          _startRingtone();
        },
        onUserJoined:
            (RtcConnection connection, int remoteUid, int elapsed) async {
          print('Remote user joined: $remoteUid');
          setState(() => _remoteUid = remoteUid);
          // Stop the ringtone as the remote user has joined
          _stopRingtone();
          // Automatically mute and then unmute to ensure the remote user can hear you.
          print('Auto toggling mute/unmute...');
          await _engine.muteLocalAudioStream(true);
          await Future.delayed(const Duration(seconds: 1));
          await _engine.muteLocalAudioStream(false);
          print('Auto toggle complete.');
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) async {
          print('Remote user left: $remoteUid. Ending call automatically.');
          // Automatically end the call if the remote user leaves.
          await _endCall();
        },
        onAudioVolumeIndication: (RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int totalVolume,
            int speakerNumber) {
          logger.info(
              'Local audio volume: $totalVolume, number of speakers: $speakerNumber');
        },
      ),
    );

    // Fetch token, then join channel
    try {
      final tokenData = await _fetchAgoraToken();
      final token = tokenData['token'];
      final channelName = tokenData['channelName'];
      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      print('Error joining channel: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchAgoraToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    final userData = await FirebaseDatabase.instance
        .ref('administrator/users/${currentUser.uid}/full_name')
        .get();
    final fullName = userData.exists ? userData.value.toString() : 'Patient';

    final idToken = await currentUser.getIdToken();
    final url = Uri.parse(_cloudFunctionUrl);
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken'
      },
      body: json.encode({
        'doctorId': widget.doctorId,
        'callerName': fullName,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to fetch Agora token: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  Future<void> _startRingtone() async {
    try {
      if (_audioPlayer != null) return;
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.play(AssetSource('audio/ringtone.mp3'), volume: 1.0);
      print('Ringtone started');
    } catch (e) {
      print('Error playing ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        _audioPlayer = null;
        print('Ringtone stopped');
      }
    } catch (e) {
      print('Error stopping ringtone: $e');
    }
  }

  // Manual toggle remains available, if needed.
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  Future<void> _endCall() async {
    await _engine.leaveChannel();
    _stopRingtone();
    setState(() => _remoteUid = null);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final dbRef = FirebaseDatabase.instance
          .ref('agoraChannels/${widget.doctorId}-${currentUser.uid}');
      await dbRef.remove();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    _stopRingtone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Call'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(widget.doctorAvatar),
            ),
            const SizedBox(height: 8),
            Text(widget.doctorName, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            _joined
                ? (_remoteUid != null
                    ? const Text('Connected')
                    : const Text('Ringing...'))
                : const Text('Ringing...'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _endCall,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('End Call'),
                ),
                const SizedBox(width: 12),
                // Optionally, the manual mute button can still be used if needed.
                ElevatedButton(
                  onPressed: _toggleMute,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text(_isMuted ? 'Unmute' : 'Mute'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _toggleSpeaker,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text(_isSpeakerOn ? 'Speaker Off' : 'Speaker On'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
