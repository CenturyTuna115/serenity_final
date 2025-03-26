import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthUtils {
  static Future<void> logoutWithConfirmation({
    required BuildContext context,
    required Widget loginScreen,
  }) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Log Out'),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Log Out'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  await FirebaseAuth.instance.signOut();

                  Navigator.of(context).pop(); // Remove loading dialog
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => loginScreen),
                    (route) => false,
                  );
                } catch (e) {
                  Navigator.of(context).pop(); // Remove loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
