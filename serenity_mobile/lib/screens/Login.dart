import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/screens/homepage.dart';
import 'package:serenity_mobile/screens/register.dart';
import 'package:serenity_mobile/screens/homepage.dart'; // Import your questionnaires.dart file
import 'package:serenity_mobile/services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 130,
            ),
            Center(
              child: Image.asset('assets/logo.png'),
            ),
            const SizedBox(
              height: 40,
            ),
            const Text(
              "Log in with your Serenity Account",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            Container(
              alignment: Alignment.center,
              width: 350,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: "Username, Phone or Email",
                  contentPadding: EdgeInsets.all(15),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            Container(
              alignment: Alignment.center,
              width: 350,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  contentPadding: EdgeInsets.all(15),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            Container(
              alignment: Alignment.center,
              width: 350,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: () => _login(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  elevation: 0,
                  minimumSize: const Size(350, 70),
                ),
                child: const Text(
                  "Log in",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 40,
            ),
            ElevatedButton(
              onPressed: () {
                _forgotPassword();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                elevation: 0,
                backgroundColor: AppColors.darkGreen,
              ),
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  color: AppColors.lightGreen,
                  fontSize: 15,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                elevation: 0,
                backgroundColor: AppColors.darkGreen,
              ),
              child: const Text(
                "Sign Up",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(
              height: 170,
            ),
            const Text(
              "@2024 SERENITY TERMS Privacy Policy Cookies Policy",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            ),
            const Text(
              "Report a Problem",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _login(BuildContext context) async {
    try {
      final user =
          await _auth.signInWithEmailAndPassword(_email.text, _password.text);

      if (user != null) {
        print("User logged in successfully");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        print("User is null after login attempt");
      }
    } catch (e) {
      print("Error logging in: $e");
      // Handle specific FirebaseAuthException codes
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          print('No user found for that email.');
        } else if (e.code == 'wrong-password') {
          print('Wrong password provided for that user.');
        }
        // Add more conditions as needed
      }
    }
  }

  void _forgotPassword() {
    print("Forgot Password pressed!");
    // Add functionality for forgot password here
  }
}
