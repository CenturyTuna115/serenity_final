import 'package:flutter/material.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/screens/login.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller for rotation
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.forward(); // Start the rotation animation

    Future.delayed(Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(006400),
      body: Center(
        child: FadeTransition(
          opacity: _rotationAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _rotationAnimation,
                child: Image.asset(
                  'assets/logo.png',
                  height: 150,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'SERENITY',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92A68A),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Stay serene with serenity.\nYour health trusted companion.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
