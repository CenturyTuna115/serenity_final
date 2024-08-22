import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/resources/common/toast.dart';
import 'package:serenity_mobile/screens/homepage.dart';
import 'package:serenity_mobile/screens/register.dart';
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

  String? _verificationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: SingleChildScrollView(
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
            _buildTextField(_identifier, "Username, Phone or Email"),
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
          if (_identifier.text.contains(RegExp(r'^\+63\d{10}$'))) {
            _loginWithPhoneNumber(context);
          } else {
            _loginWithIdentifier(context);
          }
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
    try {
      final user = await _auth.loginWithEmailOrUsernameOrPhone(
        _identifier.text,
        _password.text,
      );

      if (user != null) {
        showToast(message: "User logged in successfully");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        showToast(message: "Login failed, please try again.");
      }
    } catch (e) {
      showToast(message: "Error logging in: $e");
    }
  }

  void _loginWithPhoneNumber(BuildContext context) {
    _auth.signInWithPhoneNumber(
      _identifier.text,
      (verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
        _showSMSCodeDialog(context);
      },
      (verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
      },
      (User? user) {
        if (user != null) {
          showToast(message: "Phone number verified and user logged in.");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        } else {
          showToast(message: "Login failed, please try again.");
        }
      },
      (error) {
        showToast(message: "Phone verification failed: $error");
      },
    );
  }

  void _showSMSCodeDialog(BuildContext context) {
    String smsCode = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter SMS Code'),
        content: TextField(
          onChanged: (value) {
            smsCode = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_verificationId != null) {
                User? user =
                    await _auth.verifySMSCode(_verificationId!, smsCode);
                if (user != null) {
                  showToast(message: "User logged in successfully");
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomePage()),
                  );
                } else {
                  showToast(message: "Invalid SMS code, please try again.");
                }
              }
              Navigator.of(context).pop();
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _forgotPassword() {
    showToast(message: "Forgot Password pressed!");
    // Add functionality for forgot password here
  }
}
