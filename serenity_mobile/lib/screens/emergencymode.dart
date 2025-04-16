import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'homepage.dart';
import 'messages.dart';
import 'doctor_notes.dart';
import 'package:serenity_mobile/widgets/app_bottom_nav_bar.dart';

class Emergencymode extends StatefulWidget {
  static const MethodChannel _channel =
      MethodChannel('com.example.serenity_mobile/service');

  final int currentIndex;

  const Emergencymode({Key? key, this.currentIndex = 2}) : super(key: key);

  @override
  _EmergencymodeState createState() => _EmergencymodeState();
}

class _EmergencymodeState extends State<Emergencymode> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Telephony telephony = Telephony.instance;
  double _shakeThreshold = 15.0;
  double _lastX = 0.0, _lastY = 0.0, _lastZ = 0.0;
  bool _audioPlaying = false;
  bool _audioPlayedRecently = false;
  bool _smsPermissionGranted = false;
  late StreamSubscription<AccelerometerEvent> _subscription;
  String? _selectedAudioUrl;
  String _currentAudioName = 'Breathing Exercise';

  @override
  void initState() {
    super.initState();
    _loadSelectedAudio();
    _requestSmsPermission();
    _initForegroundService();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      bool firstTime = prefs.getBool('emergency_mode_first_time') ?? true;

      if (firstTime && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Shake Gesture'),
            content:
                Text('To enable the shake gesture, shake your phone first'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  prefs.setBool('emergency_mode_first_time', false);
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    });
    try {
      _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
        double deltaX = (event.x - _lastX).abs();
        double deltaY = (event.y - _lastY).abs();
        double deltaZ = (event.z - _lastZ).abs();

        if ((deltaX > _shakeThreshold ||
                deltaY > _shakeThreshold ||
                deltaZ > _shakeThreshold) &&
            !_audioPlayedRecently) {
          _sendEmergencySMS();
          _playAudio();
          _startCooldown();
        }

        _lastX = event.x;
        _lastY = event.y;
        _lastZ = event.z;
      });
    } catch (e) {
      debugPrint('Failed to initialize sensors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize shake detection')),
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      _subscription.cancel();
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
    }
    _audioPlayer.dispose();
    try {
      Emergencymode._channel.invokeMethod('stopService');
    } catch (e) {
      debugPrint('Error stopping service: $e');
    }
    super.dispose();
  }

  Future<void> _initForegroundService() async {
    try {
      await Emergencymode._channel.invokeMethod('startService');
    } on PlatformException catch (e) {
      debugPrint('Failed to start service: ${e.message}');
    }
  }

  Future<void> _loadSelectedAudio() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('user_settings/${user.uid}/selected_audio')
          .once();

      if (snapshot.snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          _selectedAudioUrl = data['url'];
          _currentAudioName = data['name'] ?? 'Custom Audio';
        });
      } else {
        setState(() {
          _selectedAudioUrl = null;
          _currentAudioName = 'Breathing Exercise';
        });
      }
    } catch (e) {
      debugPrint('Error loading selected audio: $e');
    }
  }

  Future<void> _requestSmsPermission() async {
    final bool? hasPermission = await telephony.requestSmsPermissions;
    if (mounted) {
      setState(() {
        _smsPermissionGranted = hasPermission ?? false;
      });
      if (!_smsPermissionGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission required for emergency alerts'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _playAudio() async {
    try {
      if (_selectedAudioUrl != null) {
        await _audioPlayer.play(UrlSource(_selectedAudioUrl!));
      } else {
        await _audioPlayer.play(AssetSource('audio/audio3.mp3'));
      }
      setState(() {
        _audioPlaying = true;
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _stopAudio() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _audioPlaying = false;
      });
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  Future<void> _sendEmergencySMS() async {
    if (!_smsPermissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable SMS permissions in settings'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('administrator/users/${user.uid}');
        DatabaseEvent userEvent = await userRef.once();

        String userName = "User";
        if (userEvent.snapshot.exists) {
          Map<dynamic, dynamic> userData =
              userEvent.snapshot.value as Map<dynamic, dynamic>;
          userName = userData['full_name'] ?? "User";
        }

        DatabaseReference userBuddiesRef = FirebaseDatabase.instance
            .ref('administrator/users/${user.uid}/buddies');
        DatabaseEvent buddiesEvent = await userBuddiesRef.once();

        if (buddiesEvent.snapshot.exists) {
          Map<dynamic, dynamic> buddiesData =
              buddiesEvent.snapshot.value as Map<dynamic, dynamic>;

          buddiesData.forEach((key, value) async {
            try {
              String? phoneNumber = value['phoneNumber'];
              if (phoneNumber != null && phoneNumber.isNotEmpty) {
                await telephony.sendSms(
                  to: phoneNumber,
                  message:
                      'EMERGENCY ALERT: $userName needs immediate assistance! Please respond ASAP. This is an automated message. Sent via Serenity App.',
                );
              }
            } catch (e) {
              debugPrint('Error sending SMS to buddy $key: $e');
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error sending emergency SMS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SMS: $e')),
        );
      }
    }
  }

  void _startCooldown() {
    setState(() {
      _audioPlayedRecently = true;
    });
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _audioPlayedRecently = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCEDFCC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomePage(currentIndex: 0)),
            );
          },
        ),
        title: const Text(
          'Bell mode',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.png',
              width: 50,
              height: 50,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Shake The Device\nTo Play The Audio',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
            Container(
              width: 250,
              height: 250,
              child: Lottie.asset(
                'assets/animation/calm.json',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Now Playing',
              style: TextStyle(
                color: Color(0xFFBABABA),
                fontSize: 18,
              ),
            ),
            Text(
              _currentAudioName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (_audioPlaying)
              ElevatedButton(
                onPressed: _stopAudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Cancel Audio',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: (index) {
          Widget? nextPage;
          if (index == 0) {
            nextPage = HomePage(currentIndex: 0);
          } else if (index == 1) {
            nextPage = MessagesTab(currentIndex: 1);
          } else if (index == 2) {
            return;
          } else if (index == 3) {
            nextPage = const DoctorNotesScreen();
          }

          if (nextPage != null) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => nextPage!,
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
              ),
            );
          }
        },
      ),
    );
  }
}
