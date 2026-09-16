import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NavAbleUser {
  const NavAbleUser({
    required this.fullName,
    required this.email,
    required this.password,
    this.profileImageBytes,
  });

  final String fullName;
  final String email;
  final String password;
  final Uint8List? profileImageBytes;
}

class AuthResult {
  const AuthResult._({this.user, this.message});

  final NavAbleUser? user;
  final String? message;

  bool get isSuccess => user != null;

  factory AuthResult.success(NavAbleUser user) =>
      AuthResult._(user: user);

  factory AuthResult.failure(String message) =>
      AuthResult._(message: message);
}

class AuthService {
  AuthService._();

  static const String demoEmail = 'june@gmail.com';
  static const String demoPassword = 'june1234';

  static NavAbleUser? currentUser;

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static bool isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(email.trim());
  }

  static Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final cleanedName = fullName.trim();
    final cleanedEmail = email.trim().toLowerCase();

    if (cleanedName.length < 2) {
      return AuthResult.failure('Please enter your full name.');
    }

    if (!isValidEmail(cleanedEmail)) {
      return AuthResult.failure(
        'Please enter a valid email address.',
      );
    }

    if (password.length < 8) {
      return AuthResult.failure(
        'Password must be at least 8 characters.',
      );
    }

    if (password != confirmPassword) {
      return AuthResult.failure('Passwords do not match.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        return AuthResult.failure(
          'Unable to create your account.',
        );
      }

      await firebaseUser.updateDisplayName(cleanedName);

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'fullName': cleanedName,
        'email': cleanedEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final user = NavAbleUser(
        fullName: cleanedName,
        email: cleanedEmail,
        password: '',
      );

      currentUser = user;

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        _authErrorMessage(e.code),
      );
    } catch (_) {
      return AuthResult.failure(
        'Something went wrong while creating your account.',
      );
    }
  }

  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final cleanedEmail = email.trim().toLowerCase();

    if (!isValidEmail(cleanedEmail)) {
      return AuthResult.failure(
        'Please enter a valid email address.',
      );
    }

    if (password.isEmpty) {
      return AuthResult.failure(
        'Please enter your password.',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        return AuthResult.failure(
          'Unable to sign in.',
        );
      }

      final document = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final data = document.data();

      final fullName =
          data?['fullName'] as String? ??
          firebaseUser.displayName ??
          'NavAble User';

      final user = NavAbleUser(
        fullName: fullName,
        email: firebaseUser.email ?? cleanedEmail,
        password: '',
      );

      currentUser = user;

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        _authErrorMessage(e.code),
      );
    } catch (_) {
      return AuthResult.failure(
        'Something went wrong while signing in.',
      );
    }
  }

  static Future<String> resetPassword(String email) async {
    final cleanedEmail = email.trim().toLowerCase();

    if (!isValidEmail(cleanedEmail)) {
      return 'Please enter a valid email address.';
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: cleanedEmail,
      );

      return 'Reset link sent to $cleanedEmail.';
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (_) {
      return 'Unable to send the reset link.';
    }
  }

  static Future<AuthResult> updateProfile({
    required String fullName,
    required String email,
    required Uint8List? profileImageBytes,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return AuthResult.failure(
        'No active user to update.',
      );
    }

    final cleanedName = fullName.trim();
    final cleanedEmail = email.trim().toLowerCase();

    if (cleanedName.length < 2) {
      return AuthResult.failure(
        'Please enter your full name.',
      );
    }

    if (!isValidEmail(cleanedEmail)) {
      return AuthResult.failure(
        'Please enter a valid email address.',
      );
    }

    try {
      if (cleanedEmail != firebaseUser.email) {
        await firebaseUser.verifyBeforeUpdateEmail(
          cleanedEmail,
        );
      }

      await firebaseUser.updateDisplayName(cleanedName);

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
        'uid': firebaseUser.uid,
        'fullName': cleanedName,
        'email': cleanedEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final updatedUser = NavAbleUser(
        fullName: cleanedName,
        email: cleanedEmail,
        password: '',
        profileImageBytes: profileImageBytes,
      );

      currentUser = updatedUser;

      return AuthResult.success(updatedUser);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        _authErrorMessage(e.code),
      );
    } catch (_) {
      return AuthResult.failure(
        'Unable to update your profile.',
      );
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    currentUser = null;
  }

  static String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again before updating your email.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}