class NavAbleUser {
  const NavAbleUser({
    required this.fullName,
    required this.email,
    required this.password,
  });

  final String fullName;
  final String email;
  final String password;
}

class AuthResult {
  const AuthResult._({this.user, this.message});

  final NavAbleUser? user;
  final String? message;

  bool get isSuccess => user != null;

  factory AuthResult.success(NavAbleUser user) => AuthResult._(user: user);

  factory AuthResult.failure(String message) =>
      AuthResult._(message: message);
}

class AuthService {
  AuthService._();

  static final Map<String, NavAbleUser> _users = {
    'demo@navable.app': const NavAbleUser(
      fullName: 'Demo Rider',
      email: 'demo@navable.app',
      password: 'password123',
    ),
  };

  static NavAbleUser? currentUser;

  static bool isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  static AuthResult register({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    final cleanedName = fullName.trim();
    final cleanedEmail = email.trim().toLowerCase();

    if (cleanedName.length < 2) {
      return AuthResult.failure('Please enter your full name.');
    }
    if (!isValidEmail(cleanedEmail)) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (password.length < 8) {
      return AuthResult.failure('Password must be at least 8 characters.');
    }
    if (password != confirmPassword) {
      return AuthResult.failure('Passwords do not match.');
    }
    if (_users.containsKey(cleanedEmail)) {
      return AuthResult.failure('An account with this email already exists.');
    }

    final user = NavAbleUser(
      fullName: cleanedName,
      email: cleanedEmail,
      password: password,
    );
    _users[cleanedEmail] = user;
    currentUser = user;

    return AuthResult.success(user);
  }

  static AuthResult login({
    required String email,
    required String password,
  }) {
    final cleanedEmail = email.trim().toLowerCase();

    if (!isValidEmail(cleanedEmail)) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      return AuthResult.failure('Please enter your password.');
    }

    final user = _users[cleanedEmail];
    if (user == null || user.password != password) {
      return AuthResult.failure('Email or password is incorrect.');
    }

    currentUser = user;
    return AuthResult.success(user);
  }

  static String resetPassword(String email) {
    final cleanedEmail = email.trim().toLowerCase();

    if (!isValidEmail(cleanedEmail)) {
      return 'Please enter a valid email address.';
    }
    if (!_users.containsKey(cleanedEmail)) {
      return 'No NavAble account was found for that email.';
    }

    return 'Reset link sent to $cleanedEmail.';
  }

  static AuthResult updateProfile({
    required String fullName,
    required String email,
  }) {
    final activeUser = currentUser;
    if (activeUser == null) {
      return AuthResult.failure('No active user to update.');
    }

    final cleanedName = fullName.trim();
    final cleanedEmail = email.trim().toLowerCase();

    if (cleanedName.length < 2) {
      return AuthResult.failure('Please enter your full name.');
    }
    if (!isValidEmail(cleanedEmail)) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (cleanedEmail != activeUser.email && _users.containsKey(cleanedEmail)) {
      return AuthResult.failure('An account with this email already exists.');
    }

    _users.remove(activeUser.email);
    final updatedUser = NavAbleUser(
      fullName: cleanedName,
      email: cleanedEmail,
      password: activeUser.password,
    );
    _users[cleanedEmail] = updatedUser;
    currentUser = updatedUser;

    return AuthResult.success(updatedUser);
  }

  static void signOut() {
    currentUser = null;
  }
}
