import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class VoiceCallScreen extends StatefulWidget {
  final String doctorAvatar;
  final String doctorName;
  final String doctorId; // This is the doctor's ID

  VoiceCallScreen({
    required this.doctorAvatar,
    required this.doctorName,
    required this.doctorId,
  });

  @override
  _VoiceCallScreenState createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  final String appId = '3a7bf343ec50426697144687e52dfac6';
  AudioPlayer? _audioPlayer;
  bool _isRingtonePlaying = false;
  bool _isDisposed = false;

  // Cloud function URL – replace with your actual deployed URL.
  final String _cloudFunctionUrl =
      'https://asia-southeast1-serenity-c800c.cloudfunctions.net/generateToken';

  @override
  void initState() {
    super.initState();
    _initializeAgora();
    _initializeRingtone();
  }

  Future<void> _initializeRingtone() async {
    print("Initializing ringtone");
    _audioPlayer = AudioPlayer();
    await _audioPlayer?.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer?.setVolume(1.0);

    // Set audio context to use earpiece by default
    await _audioPlayer?.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.speech,
        audioMode: AndroidAudioMode.inCommunication,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {
          AVAudioSessionOptions.defaultToSpeaker,
        },
      ),
    ));

    // Add listener for state changes
    _audioPlayer?.onPlayerStateChanged.listen((PlayerState state) {
      print("AudioPlayer state changed to: $state");
    });

    _playRingtone();
  }

  Future<void> _playRingtone() async {
    if (_isDisposed || _isRingtonePlaying || _audioPlayer == null) return;

    try {
      print("Starting to play ringtone");
      await _audioPlayer?.play(
        AssetSource('audio/ringtone.mp3'),
      );
      if (!_isDisposed) {
        setState(() {
          _isRingtonePlaying = true;
        });
      }
      print("Ringtone playing successfully");
    } catch (e) {
      print('Error playing ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    print("Attempting to stop ringtone. Remote UID: $_remoteUid");
    if (!_isRingtonePlaying || _audioPlayer == null) {
      print("Ringtone not playing or audio player is null");
      return;
    }

    try {
      print("Stopping ringtone");
      await _audioPlayer?.stop();
      if (!_isDisposed) {
        setState(() {
          _isRingtonePlaying = false;
        });
      }
      print("Ringtone stopped successfully");
    } catch (e) {
      print('Error stopping ringtone: $e');
    }
  }

  Future<void> _initializeAgora() async {
    // Request microphone permission
    PermissionStatus micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      print('Microphone permission not granted');
      return;
    }

    print("Initializing Agora engine");
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: '3a7bf343ec50426697144687e52dfac6',
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
    await _engine.enableAudio();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int uid) {
          print("Local user joined channel: $uid");
          if (_isDisposed) return;
          setState(() {
            _joined = true;
          });
          // Explicitly ensure ringtone continues playing
          if (!_isRingtonePlaying) {
            _playRingtone();
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("Remote user joined: $remoteUid");
          if (_isDisposed) return;
          setState(() {
            _remoteUid = remoteUid;
          });
          _stopRingtone();
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print("Remote user left: $remoteUid");
          if (_isDisposed) return;
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final tokenResponse = await _fetchAgoraToken();
      final String token = tokenResponse['token'];
      final String returnedChannelName = tokenResponse['channelName'];

      print("Joining channel: $returnedChannelName");
      await _engine.joinChannel(
        token: token,
        channelId: returnedChannelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      print('Error initializing Agora: $e');
    }
  }

  // Calls the cloud function to generate an Agora token.
  Future<Map<String, dynamic>> _fetchAgoraToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    // Get full name from Firebase Database
    final userData = await FirebaseDatabase.instance
        .ref('administrator/users/${currentUser.uid}/full_name')
        .get();
    final String fullName =
        userData.exists ? userData.value.toString() : "Patient";

    final idToken = await currentUser.getIdToken();
    final url = Uri.parse(_cloudFunctionUrl);
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $idToken"
      },
      body: json.encode({
        "doctorId": widget.doctorId,
        "callerName": fullName,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 409) {
      throw Exception('Call already in progress with this doctor');
    } else {
      throw Exception(
          'Failed to fetch Agora token: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  // Toggle mute state.
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
    print('Local audio is ${_isMuted ? "muted" : "unmuted"}');
  }

  Future<void> _toggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });

    await _audioPlayer?.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.speech,
        audioMode: _isSpeakerOn
            ? AndroidAudioMode.normal
            : AndroidAudioMode.inCommunication,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {
          if (_isSpeakerOn) AVAudioSessionOptions.defaultToSpeaker,
        },
      ),
    ));

    print('Speaker mode is ${_isSpeakerOn ? "on" : "off"}');
  }

  // End the call and remove the channel info from the Realtime Database.
  Future<void> _endCall() async {
    // Don't stop ringtone here
    await _engine.leaveChannel();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DatabaseReference dbRef = FirebaseDatabase.instance
          .ref('agoraChannels/${widget.doctorId}-${currentUser.uid}');
      await dbRef.remove();
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    print("Disposing VoiceCallScreen");
    _isDisposed = true;
    if (_audioPlayer != null) {
      _audioPlayer!.dispose();
      _audioPlayer = null;
    }
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Call'),
        backgroundColor: const Color(0xFF92A68A),
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _joined
                ? (_remoteUid != null
                    ? Text('Connected $_remoteUid')
                    : const Text('Ringing...'))
                : const Text('Ringing...'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _endCall,
                  child: const Text('End Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _toggleMute,
                  child: Text(_isMuted ? 'Unmute' : 'Mute'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMuted ? Colors.grey : Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _toggleSpeaker,
                  child: Text(_isSpeakerOn ? 'Speaker Off' : 'Speaker On'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSpeakerOn ? Colors.green : Colors.blue,
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
