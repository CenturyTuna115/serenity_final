import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final String doctorAvatar;
  final String doctorName;

  VoiceCallScreen({
    required this.channelName,
    required this.token,
    required this.doctorAvatar,
    required this.doctorName,
  });

  @override
  _VoiceCallScreenState createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: '3a7bf343ec50426697144687e52dfac6',
    ));

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

    if (widget.token.isNotEmpty && widget.channelName.isNotEmpty) {
      await _engine.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: 0,
        options: ChannelMediaOptions(),
      );
    } else {
      print(
          'Error: Token or channel name is null when trying to join the channel.');
    }
  }

  void _endCall() {
    _engine.leaveChannel();
    Navigator.pop(context);
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
        title: Text('Voice Call'),
        backgroundColor: Color(0xFF92A68A),
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
            // End Call button
            ElevatedButton(
              onPressed: _endCall,
              child: Text('End Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
