import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService() {
    // Initialize Firebase, ensure this is done before using FirebaseAuth.instance
    Firebase.initializeApp();
  }

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error signing in: $e");
      rethrow; // Rethrow the exception for caller to handle
    }
  }

  createUserWithEmailAndPassword(String text, String text2) {}
}
