import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthResult {
  const AuthResult({
    required this.isSuccess,
    this.message,
    this.needsConfirmation = false,
  });

  final bool isSuccess;
  final String? message;
  final bool needsConfirmation;
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

/// Supabase authentication and account operations shared by NavAble screens.
class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  GoTrueClient get _auth => supabase.auth;
  static Uint8List? _profileImageBytes;

  // SIGN UP
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'first_name': firstName.trim(), 'last_name': lastName.trim()},
    );
  }

  // LOGIN
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // LOGOUT
  Future<void> logout() async {
    await supabase.auth.signOut();
    _profileImageBytes = null;
  }

  // GET CURRENT USER
  User? getCurrentUser() => supabase.auth.currentUser;

  // CHECK IF LOGGED IN
  bool isLoggedIn() => supabase.auth.currentSession != null;

  NavAbleUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata ?? {};
    final fullName = [metadata['first_name'], metadata['last_name']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    final legacyName = (metadata['full_name'] as String?)?.trim() ?? '';
    return NavAbleUser(
      fullName: fullName.isNotEmpty
          ? fullName
          : legacyName.isNotEmpty
          ? legacyName
          : user.email?.split('@').first ?? 'NavAble user',
      email: user.email ?? '',
      profileImageBytes: _profileImageBytes,
    );
  }

  static bool isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());

  Future<AuthResult> register({
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
      final nameParts = fullName.trim().split(RegExp(r'\s+'));
      final response = await signUp(
        email: email,
        password: password,
        firstName: nameParts.first,
        lastName: nameParts.skip(1).join(' '),
      );
      if (response.session == null) {
        return const AuthResult(
          isSuccess: true,
          needsConfirmation: true,
          message: 'Check your email to confirm your account, then sign in.',
        );
      }
      return const AuthResult(isSuccess: true);
    } on AuthException catch (error) {
      return AuthResult(isSuccess: false, message: messageFor(error));
    }
  }

  Future<String> resetPassword(String email) async {
    if (!isValidEmail(email)) return 'Enter a valid email address.';
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? Uri.base.origin : 'navable://auth-callback/',
      );
      return 'If an account exists for that email, a reset link has been sent.';
    } on AuthException catch (error) {
      return messageFor(error);
    }
  }

  Future<AuthResult> updateProfile({
    required String fullName,
    required String email,
    required Uint8List? profileImageBytes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult(isSuccess: false, message: 'Sign in first.');
    }
    try {
      final nameParts = fullName.trim().split(RegExp(r'\s+'));
      await _auth.updateUser(
        UserAttributes(
          email: email.trim().toLowerCase() == user.email?.toLowerCase()
              ? null
              : email.trim(),
          data: {
            'first_name': nameParts.first,
            'last_name': nameParts.skip(1).join(' '),
            'full_name': fullName.trim(),
          },
        ),
      );
      _profileImageBytes = profileImageBytes;
      return const AuthResult(isSuccess: true);
    } on AuthException catch (error) {
      return AuthResult(isSuccess: false, message: messageFor(error));
    }
  }

  static String messageFor(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirm your email address before signing in.';
    }
    if (message.contains('already registered')) {
      return 'An account already uses this email.';
    }
    return error.message;
  }
}
