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
  final String channelId;
  final String patientId;

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
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String? _token;
  StreamSubscription<DatabaseEvent>? _callStatusSubscription;
  bool _isInitialized = false;

  late final DatabaseReference _dbRef;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _dbRef =
        FirebaseDatabase.instance.ref('agoraChannels').child(widget.channelId);
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _initializeAgora();
      await _playRingtone();
      _listenToCallStatus();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Initialization error: $e');
      if (mounted) {
        await Future.delayed(Duration(milliseconds: 500));
        Navigator.of(context).pop();
      }
    }
  }

  void _listenToCallStatus() {
    _callStatusSubscription = _dbRef.onValue.listen((event) {
      if (!event.snapshot.exists) {
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
    if (mounted) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  Future<void> _initializeAgora() async {
    PermissionStatus microphoneStatus = await Permission.microphone.request();
    if (microphoneStatus != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: '3a7bf343ec50426697144687e52dfac6',
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await _engine.enableAudio();
    await _engine.setLogFile('/storage/emulated/0/Download/agora_log.txt');

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int uid) {
          if (mounted) {
            setState(() {
              _joined = true;
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
            _stopRingtone();
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          if (mounted) {
            setState(() {
              _remoteUid = null;
            });
          }
        },
      ),
    );

    _token = await _generateToken(widget.channelId);
    if (_token != null) {
      await _engine.joinChannel(
        token: _token!,
        channelId: widget.channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    }
    await _engine.muteLocalAudioStream(false);
  }

  Future<void> _playRingtone() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/ringtone.mp3'));
  }

  Future<void> _stopRingtone() async {
    await _audioPlayer.stop();
  }

  void _toggleMute() {
    if (mounted) {
      setState(() {
        _isMuted = !_isMuted;
      });
      _engine.muteLocalAudioStream(_isMuted);
    }
  }

  void _toggleSpeaker() {
    if (mounted) {
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });
      _engine.setEnableSpeakerphone(_isSpeakerOn);
    }
  }

  Future<String?> _generateToken(String channelName) async {
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final result = await functions
          .httpsCallable('generateToken')
          .call({'channelName': channelName, 'patientId': widget.patientId});

      final token = result.data['token'];
      if (token == null || token.isEmpty) {
        throw Exception('Empty token received');
      }
      return token;
    } catch (e) {
      print('Token generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate call token'),
            duration: Duration(seconds: 5),
          ),
        );
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
      return null;
    }
  }

  Future<void> _endCall() async {
    try {
      _stopRingtone();
      if (_joined) {
        await _engine.leaveChannel();
      }
      _callStatusSubscription?.cancel();
      await _dbRef.update({
        'status': 'ended',
        'endTimestamp': ServerValue.timestamp,
      });
      await _dbRef.remove();
      await _engine.release();
    } catch (e) {
      print('Error ending call: $e');
    } finally {
      if (mounted) {
        await Future.delayed(Duration(milliseconds: 500));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _stopRingtone();
    _callStatusSubscription?.cancel();
    if (_joined) {
      _engine.leaveChannel();
    }
    _engine.release();
    _dbRef.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              backgroundImage: widget.doctorAvatar.isNotEmpty &&
                      widget.doctorAvatar != 'null'
                  ? (widget.doctorAvatar.startsWith('http')
                      ? NetworkImage(widget.doctorAvatar)
                      : AssetImage(widget.doctorAvatar))
                  : AssetImage('assets/johndoe.jpg') as ImageProvider,
              onBackgroundImageError: (exception, stackTrace) {
                setState(() {
                  // Fallback to default asset image
                });
              },
              child: null,
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
