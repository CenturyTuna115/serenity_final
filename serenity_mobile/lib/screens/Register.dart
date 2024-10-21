import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting date
import 'package:serenity_mobile/resources/colors.dart';
import 'package:serenity_mobile/resources/common/toast.dart';
import 'package:serenity_mobile/screens/login.dart';
import 'package:serenity_mobile/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullname = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmpass = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _birthdate =
      TextEditingController(); // New controller for birthdate
  final AuthService _auth = AuthService();
  final List<String> conditions = [
    "Insomnia",
    "Post Traumatic Stress",
    "Anxiety"
  ];
  final List<String> selectedConditions = [];
  String? _selectedSex;

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
              const SizedBox(height: 30),
              const Text(
                "Create your Serenity Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 15),
              _buildTextField(_fullname, "Full Name"),
              const SizedBox(height: 15),
              _buildTextField(_username, "Username"),
              const SizedBox(height: 15),
              _buildPasswordField(_password, "Password"),
              const SizedBox(height: 15),
              _buildPasswordField(_confirmpass, "Re-type Password"),
              const SizedBox(height: 15),
              _buildTextField(_email, "Email"),
              const SizedBox(height: 15),
              _buildTextField(_number, "Enter your Mobile Number"),
              const SizedBox(height: 15),
              _buildDateField(context), // New field for selecting birthdate
              const SizedBox(height: 15),
              _buildSexDropdown(),
              const SizedBox(height: 15),
              _buildCheckboxList(),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () => _signup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  elevation: 0,
                  minimumSize: const Size(340, 50),
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
                  fontSize: 13,
                  fontFamily: 'Roboto',
                ),
              ),
              const Text(
                "Report a Problem",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

  Widget _buildCheckboxList() {
    return Container(
      alignment: Alignment.center,
      width: 340,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.builder(
        itemCount: conditions.length,
        itemBuilder: (context, index) {
          return CheckboxListTile(
            title: Text(conditions[index]),
            value: selectedConditions.contains(conditions[index]),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  selectedConditions.add(conditions[index]);
                } else {
                  selectedConditions.remove(conditions[index]);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSexDropdown() {
    return Container(
      alignment: Alignment.center,
      width: 340,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: _selectedSex,
        hint: const Text("Select Sex"),
        isExpanded: true,
        underline: SizedBox(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedSex = newValue;
          });
        },
        items: ["Female", "Male"].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: 340,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _birthdate,
        decoration: const InputDecoration(
          labelText: "Birthdate",
          contentPadding: EdgeInsets.all(15),
          border: InputBorder.none,
        ),
        readOnly: true,
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );

          if (pickedDate != null) {
            setState(() {
              _birthdate.text = DateFormat('yyyy-MM-dd').format(pickedDate);
            });
          }
        },
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

    if (_selectedSex == null) {
      showToast(message: "Please select your sex");
      return;
    }

    if (_birthdate.text.isEmpty) {
      showToast(message: "Please select your birthdate");
      return;
    }

    if (selectedConditions.isEmpty) {
      showToast(message: "Please select at least one condition");
      return;
    }

    try {
      final user = await _auth.signUpWithEmailAndPassword(
        _email.text,
        _password.text,
        _username.text,
        _fullname.text,
        _number.text,
        selectedConditions.join(", "),
      );

      if (user != null) {
        String timestamp =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('administrator/users/${user.uid}');
        await userRef.set({
          'full_name': _fullname.text,
          'username': _username.text,
          'email': _email.text,
          'phone_number': _number.text,
          'sex': _selectedSex,
          'birthdate': _birthdate.text, // Store the birthdate
          'conditions': selectedConditions,
          'registration_time': timestamp,
          'questionnaire_completed': false,
          'assigned_doctor': false,
          'skip_clicked': false,
        });

        showToast(message: "User Created Successfully");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(),
          ),
        );
      }
    } catch (e) {
      showToast(message: "Error creating user: $e");
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
