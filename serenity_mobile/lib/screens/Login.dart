import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/resources/common/toast.dart';
import 'package:serenity_mobile/screens/doctor_dashboard.dart';
import 'package:serenity_mobile/screens/homepage.dart'; // Main homepage screen
import 'package:serenity_mobile/screens/register.dart'; // Registration screen
import 'package:serenity_mobile/screens/user_questionnaire.dart'; // Questionnaire screen
import 'package:serenity_mobile/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false; // State to manage loading

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 130),
                Center(child: Image.asset('assets/logo.png')),
                const SizedBox(height: 40),
                const Text(
                  "Log in with your Serenity Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 30),
                _buildTextField(_identifier, "Username or Email"),
                const SizedBox(height: 30),
                _buildPasswordField(_password, "Password"),
                const SizedBox(height: 30),
                _buildLoginButton(context),
                const SizedBox(height: 40),
                _buildForgotPasswordButton(),
                _buildSignUpButton(context),
                const SizedBox(height: 170),
                _buildFooter(),
              ],
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText) {
    return Container(
      alignment: Alignment.center,
      width: 340,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          contentPadding: const EdgeInsets.all(15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField(
      TextEditingController controller, String labelText) {
    return Container(
      alignment: Alignment.center,
      width: 340,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(
          labelText: labelText,
          contentPadding: const EdgeInsets.all(15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: 340,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: () {
          _loginWithIdentifier(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightBlue,
          elevation: 0,
          minimumSize: const Size(340, 60),
        ),
        child: const Text(
          "Log in",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return ElevatedButton(
      onPressed: _forgotPassword,
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
    );
  }

  Widget _buildSignUpButton(BuildContext context) {
    return ElevatedButton(
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
    );
  }

  Widget _buildFooter() {
    return Column(
      children: const [
        Text(
          "@2024 SERENITY TERMS Privacy Policy Cookies Policy",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'Roboto',
          ),
        ),
        Text(
          "Report a Problem",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }

  void _loginWithIdentifier(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _auth.loginWithEmailOrUsernameOrPhone(
        _identifier.text,
        _password.text,
      );

      if (user != null) {
        // Retrieve the user information from Firebase Realtime Database
        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('administrator/users/${user.uid}');

        final snapshot = await userRef.get();
        if (snapshot.exists) {
          Map<String, dynamic> userData = Map<String, dynamic>.from(
              snapshot.value as Map<dynamic, dynamic>);

          bool? questionnaireCompleted = userData['questionnaire_completed'];
          bool? skipClicked = userData['skip_clicked'] ?? false;

          // Check if the questionnaire is completed or not
          if (questionnaireCompleted == null || !questionnaireCompleted) {
            // Redirect to the UserQuestionnaire if it's not completed
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserQuestionnaire()),
            );
          } else if (!skipClicked!) {
            // If skip_clicked or assigned_doctor is false, redirect to DoctorDashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DoctorDashboard()),
            );
          } else {
            // If both are true, proceed to the homepage
            showToast(message: "User logged in successfully");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'invalid-email':
          errorMessage = "The email address is badly formatted.";
          break;
        case 'user-disabled':
          errorMessage = "This user account has been disabled.";
          break;
        case 'user-not-found':
          errorMessage = "No user found with these credentials.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password. Please try again.";
          break;
        case 'too-many-requests':
          errorMessage =
              "Too many unsuccessful attempts. Please try again later.";
          break;
        case 'network-request-failed':
          errorMessage = "Network error. Please check your connection.";
          break;
        default:
          errorMessage = "An unknown error occurred. Please try again.";
      }

      print(
          "FirebaseAuthException caught: ${e.code}, displaying message: $errorMessage");

      showToast(message: errorMessage);
    } catch (e) {
      print("Exception caught: $e");

      showToast(message: "An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _forgotPassword() {
    showToast(message: "Forgot Password pressed!");
    // Add functionality for forgot password here
  }
}
