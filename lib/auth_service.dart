import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

class AuthResult {
  const AuthResult({required this.isSuccess, this.message});

  final bool isSuccess;
  final String? message;
}

class NavAbleUser {
  const NavAbleUser({
    required this.fullName,
    required this.email,
    this.profileImageBytes,
  });

  final String fullName;
  final String email;
  final Uint8List? profileImageBytes;
}

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static Uint8List? _profileImageBytes;

  static NavAbleUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return NavAbleUser(
      fullName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email?.split('@').first ?? 'NavAble user',
      email: user.email ?? '',
      profileImageBytes: _profileImageBytes,
    );
  }

  static bool isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());

  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthResult(isSuccess: true);
    } on FirebaseAuthException catch (error) {
      return AuthResult(isSuccess: false, message: _messageFor(error));
    }
  }

  static Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (password != confirmPassword) {
      return const AuthResult(
        isSuccess: false,
        message: 'The passwords do not match.',
      );
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(fullName.trim());
      await credential.user?.reload();
      return const AuthResult(isSuccess: true);
    } on FirebaseAuthException catch (error) {
      return AuthResult(isSuccess: false, message: _messageFor(error));
    }
  }

  static Future<String> resetPassword(String email) async {
    if (!isValidEmail(email)) return 'Enter a valid email address.';
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return 'If an account exists for that email, a reset link has been sent.';
    } on FirebaseAuthException catch (error) {
      return _messageFor(error);
    }
  }

  static Future<AuthResult> updateProfile({
    required String fullName,
    required String email,
    required Uint8List? profileImageBytes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult(isSuccess: false, message: 'Sign in first.');
    }
    try {
      if (email.trim().toLowerCase() != user.email?.toLowerCase()) {
        await user.verifyBeforeUpdateEmail(email.trim());
      }
      await user.updateDisplayName(fullName.trim());
      await user.reload();
      _profileImageBytes = profileImageBytes;
      return const AuthResult(isSuccess: true);
    } on FirebaseAuthException catch (error) {
      return AuthResult(isSuccess: false, message: _messageFor(error));
    }
  }

  static Future<void> signOut() async {
    _profileImageBytes = null;
    await _auth.signOut();
  }

  static String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' =>
      'Email or password is incorrect.',
    'email-already-in-use' => 'An account already uses this email.',
    'weak-password' => 'Choose a stronger password (at least 6 characters).',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'requires-recent-login' => 'Sign in again before changing your email.',
    'operation-not-allowed' =>
      'Enable Email/Password sign-in in Firebase Authentication settings.',
    _ => error.message ?? 'Firebase Authentication could not complete the request.',
  };
}
