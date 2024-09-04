import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/resources/common/toast.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  AuthService() {
    initializeFirebase();
  }

  Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
  }

  Future<User?> signUpWithEmailAndPassword(
      String email,
      String password,
      String username,
      String fullName,
      String phoneNumber,
      String condition) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = credential.user;

      if (user != null) {
        await _database.child('administrator/users').child(user.uid).set({
          'email': email,
          'username': username,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'condition': condition,
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showToast(message: 'The email address is already in use.');
      } else {
        showToast(message: 'An error occurred: ${e.code}');
      }
    }
    return null;
  }

  Future<User?> loginWithEmailOrUsernameOrPhone(
      String identifier, String password) async {
    try {
      UserCredential? userCredential;

      if (identifier.contains('@')) {
        userCredential = await _auth.signInWithEmailAndPassword(
            email: identifier, password: password);
      } else {
        final snapshot = await _database.child('administrator/users').get();

        if (snapshot.exists) {
          Map<String, dynamic>? userData;
          String? userId;

          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            final userMap = value as Map<dynamic, dynamic>;
            if (userMap['username'] == identifier) {
              userData = Map<String, dynamic>.from(userMap);
              userId = key as String;
            }
          });

          if (userData != null && userId != null) {
            userCredential = await _auth.signInWithEmailAndPassword(
                email: userData!['email'], password: password);
          } else {
            throw FirebaseAuthException(
                code: 'user-not-found',
                message: 'No user found for that identifier.');
          }
        } else {
          throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'No users found in the database.');
        }
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors with custom messages
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

      showToast(message: errorMessage);
      return null;
    } catch (e) {
      // Handle any other types of exceptions that are not Firebase-specific
      showToast(message: "An unexpected error occurred. Please try again.");
      return null;
    }
  }
}
