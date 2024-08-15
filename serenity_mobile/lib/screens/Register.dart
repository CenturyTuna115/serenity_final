import 'package:flutter/material.dart';
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/resources/common/toast.dart';
import 'package:serenity_mobile/screens/login.dart';
import 'package:serenity_mobile/services/auth_service.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({Key? key}) : super(key: key);

  final TextEditingController _fullname = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmpass = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: ListView(
        children: [
          Column(
            children: [
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              Center(
                child: Image.asset('assets/logo.png'),
              ),
              const SizedBox(height: 20),
              const Text(
                "Create your Serenity Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(_fullname, "Full Name"),
              const SizedBox(height: 20),
              _buildTextField(_username, "Username"),
              const SizedBox(height: 20),
              _buildPasswordField(_password, "Password"),
              const SizedBox(height: 20),
              _buildPasswordField(_confirmpass, "Re-type Password"),
              const SizedBox(height: 20),
              _buildTextField(_email, "Email"),
              const SizedBox(height: 20),
              _buildTextField(_number, "Enter your Mobile Number"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _signup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  elevation: 0,
                  minimumSize: const Size(370, 70),
                ),
                child: const Text(
                  "Create your Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontFamily: 'Times New Roman',
                  ),
                ),
              ),
              const SizedBox(height: 50),
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
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText) {
    return Container(
      alignment: Alignment.center,
      width: 370,
      height: 70,
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
      width: 370,
      height: 70,
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

  void _signup(BuildContext context) async {
    if (!_isValidEmail(_email.text)) {
      showToast(message: "Invalid email format");
      return;
    }

    if (_password.text != _confirmpass.text) {
      showToast(message: "Passwords do not match");
      return;
    }

    try {
      // Use AuthService to sign up the user and store data in Realtime Database
      final user = await _auth.signUpWithEmailAndPassword(
        _email.text,
        _password.text,
        _username.text,
        _fullname.text,
        _number.text,
      );

      if (user != null) {
        _showSuccessDialog(context);
        showToast(message: "User Created Successfully");
      }
    } catch (e) {
      showToast(message: "Error creating user: $e");
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Account Created Successfully"),
          content: const Text("Your account has been created successfully!"),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
