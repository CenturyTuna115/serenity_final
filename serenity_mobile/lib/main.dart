import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart';
import 'package:serenity_mobile/screens/emergencymode.dart';
import 'package:serenity_mobile/screens/homepage.dart';
import 'package:serenity_mobile/screens/login.dart';
import 'package:serenity_mobile/screens/buddy.dart'; // Import the buddy list screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serenity',
      theme: ThemeData(
        primarySwatch: Colors.green, // ait
      ),
      home: LoginScreen(),
    );
  }
} 
