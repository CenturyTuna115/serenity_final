import 'package:flutter/material.dart';
import 'package:serenity_mobile/resources/colors.dart';
<<<<<<< HEAD
import 'package:serenity_mobile/screens/Register.dart';
=======
>>>>>>> 0fd9acee0db2b1ab12fdd516850627291b2ec452

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

<<<<<<< HEAD
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
=======
  final TextEditingController _controller = TextEditingController();
>>>>>>> 0fd9acee0db2b1ab12fdd516850627291b2ec452

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.darkGreen,
        body: Column(
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
            const Text("Log in with your Serenity Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
<<<<<<< HEAD
                  fontWeight: FontWeight.w300,
=======
                  fontWeight: FontWeight.w500,
>>>>>>> 0fd9acee0db2b1ab12fdd516850627291b2ec452
                )),
            const SizedBox(
              height: 30,
            ),
            Container(
              alignment: Alignment.center,
<<<<<<< HEAD
              width: 350,
              height: 70,
=======
              padding: const EdgeInsets.all(20),
>>>>>>> 0fd9acee0db2b1ab12fdd516850627291b2ec452
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
<<<<<<< HEAD
                controller: _username,
                decoration: const InputDecoration(
                  labelText: "Username, Phone or Email",
                  contentPadding: EdgeInsets.all(15),
=======
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Username, Phone or Email",
>>>>>>> 0fd9acee0db2b1ab12fdd516850627291b2ec452
                  border: InputBorder.none,
                ),
              ),
            ),
<<<<<<< HEAD
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
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  elevation: 0,
                  minimumSize: const Size(350, 70),
                ),
                child: Text(
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
                print("button Pressed!");
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                elevation: 0,
                backgroundColor: AppColors.darkGreen,
              ),
              child: Text("Forgot Password?",
                  style: TextStyle(
                    color: AppColors.lightGreen,
                    fontSize: 15,
                  )),
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
              child: Text("Sign Up",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  )),
            ),
            const SizedBox(
              height: 170,
            ),
            Text(
              "@2024 SERENITY TERMS Privacy Policy Cookies Policy",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            ),
            Text(
              "Report a Problem",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Roboto',
              ),
            ),
=======
>>>>>>> 0fd9acee0db2b1ab12fdd516850627291b2ec452
          ],
        ));
  }
}
