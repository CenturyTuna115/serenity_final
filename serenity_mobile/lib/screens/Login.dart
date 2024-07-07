import 'package:flutter/material.dart';
import 'package:serenity_mobile/resources/colors.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController _controller = TextEditingController();

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
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(
              height: 30,
            ),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Username, Phone or Email",
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ));
  }
}
