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

  Future<void> signInWithPhoneNumber(
      String phoneNumber,
      Function onCodeSent,
      Function onCodeAutoRetrievalTimeout,
      Function onVerificationCompleted,
      Function onVerificationFailed) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          onVerificationCompleted(userCredential.user);
        },
        verificationFailed: (FirebaseAuthException e) {
          onVerificationFailed(e);
          showToast(message: "Verification failed: ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
          showToast(message: "Code sent to $phoneNumber");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onCodeAutoRetrievalTimeout(verificationId);
        },
      );
    } catch (e) {
      showToast(message: "Error during phone sign-in: $e");
    }
  }

  Future<User?> verifySMSCode(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      showToast(message: "Error verifying SMS code: $e");
      return null;
    }
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

          // Safely access and cast the snapshot data
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

      if (userCredential != null) {
        return userCredential.user;
      } else {
        throw FirebaseAuthException(
            code: 'login-failed', message: 'Login failed for unknown reasons.');
      }
    } catch (e) {
      showToast(message: "Error logging in: $e");
      return null;
    }
  }
}
