import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'forgot.dart';
import 'home.dart';
import 'navable_design.dart';
import 'register.dart';
import 'splash.dart';

const Color kNavAbleNavy = NavAblePalette.navy;
const Color kNavAbleGreen = NavAblePalette.green;
const Color kNavAbleAccent = NavAblePalette.accent;
const Color kNavAbleText = NavAblePalette.text;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _rememberDevice = false;
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _loginError;
  bool _credentialsRejected = false;
  bool _isLoading = false;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email address.'
          : AuthService.isValidEmail(email)
          ? null
          : 'Enter a valid email address.';
      _passwordError = password.isEmpty ? 'Enter your password.' : null;
      _loginError = null;
      _credentialsRejected = false;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    AuthResult result;
    try {
      result = await AuthService.login(email: email, password: password);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loginError = 'Could not sign in. Check your connection and try again.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      final message = result.message ?? 'Login failed. Please try again.';
      final credentialsRejected =
          message.toLowerCase().contains('email or password is incorrect');
      setState(() {
        _loginError = credentialsRejected
            ? 'Email or password is incorrect. Check both fields and try again.'
            : message;
        _credentialsRejected = credentialsRejected;
      });
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      _fadeRoute(const SplashScreen(nextScreen: HomeScreen())),
      (route) => false,
    );
  }

  void _showProviderPlaceholder(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign in needs platform setup.')),
    );
  }

  Future<void> _continueAsGuest() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fadeRoute(const SplashScreen(nextScreen: HomeScreen(isGuest: true))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _PremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'lib/img/logOnly.png',
                              width: 118,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 18),
                            const Text.rich(
                              TextSpan(
                                text: 'Nav',
                                children: [
                                  TextSpan(
                                    text: 'Able',
                                    style: TextStyle(color: kNavAbleGreen),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                color: kNavAbleNavy,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Smart Navigation for Every Ability',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kNavAbleText,
                                fontSize: 14,
                                height: 1.5,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _PremiumCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_loginError != null) ...[
                                    _LoginErrorBanner(message: _loginError!),
                                    const SizedBox(height: 16),
                                  ],
                                  _LoginField(
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
                                    hintText: 'user@example.com',
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    error: _credentialsRejected ||
                                        _emailError != null,
                                    errorText: _emailError,
                                    onChanged: (_) => setState(() {
                                      _emailError = null;
                                      _loginError = null;
                                      _credentialsRejected = false;
                                    }),
                                  ),
                                  const SizedBox(height: 20),
                                  _LoginField(
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    hintText: '',
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    error: _credentialsRejected ||
                                        _passwordError != null,
                                    errorText: _passwordError,
                                    onChanged: (_) => setState(() {
                                      _passwordError = null;
                                      _loginError = null;
                                      _credentialsRejected = false;
                                    }),
                                    labelAction: TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          _fadeRoute(
                                            const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: kNavAbleGreen,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () {
                                        setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        );
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFF5F6B7A),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: Checkbox(
                                          value: _rememberDevice,
                                          onChanged: (value) {
                                            setState(
                                              () => _rememberDevice =
                                                  value ?? false,
                                            );
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFB8C2BE),
                                            width: 1.5,
                                          ),
                                          activeColor: kNavAbleGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Remember this device',
                                        style: TextStyle(
                                          color: Color(0xFF344054),
                                          fontSize: 14,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  _PrimaryButton(
                                    label: _isLoading ? 'Signing in…' : 'Login',
                                    onPressed: _login,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _DividerLabel(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: NavAbleSize.primaryButton,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _continueAsGuest,
                                icon: const Icon(Icons.person_outline_rounded),
                                label: const Text('Continue as a Guest'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kNavAbleNavy,
                                  side: const BorderSide(
                                    color: kNavAbleGreen,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _RoundIconButton(
                                  icon: Icons.fingerprint,
                                  onPressed: () =>
                                      _showProviderPlaceholder('Fingerprint'),
                                ),
                                const SizedBox(width: 18),
                                _RoundIconButton(
                                  icon: Icons.face,
                                  onPressed: () =>
                                      _showProviderPlaceholder('Face ID'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'New to NavAble? ',
                                  style: TextStyle(
                                    color: Color(0xFF344054),
                                    fontSize: 14,
                                    letterSpacing: 0,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                    ).push(_fadeRoute(const RegisterScreen()));
                                  },
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Register Account',
                                    style: TextStyle(
                                      color: kNavAbleGreen,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

PageRouteBuilder<void> _fadeRoute(Widget screen) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FFF8), Colors.white, Color(0xFFECFFF0)],
          stops: [0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: [
          const _SoftGlow(alignment: Alignment.topRight),
          const _SoftGlow(alignment: Alignment.bottomLeft),
          child,
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: alignment == Alignment.topRight
            ? const Offset(72, -64)
            : const Offset(-88, 92),
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                kNavAbleGreen.withValues(alpha: 0.08),
                kNavAbleGreen.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      color: NavAblePalette.surface,
      child: child,
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFFB42318);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDA29B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: errorColor, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.icon,
    required this.hintText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.labelAction,
    this.error = false,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final IconData icon;
  final String hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? labelAction;
  final bool error;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF344054),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            ?labelAction,
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: NavAbleSize.field,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: error ? const Color(0xFFB42318) : kNavAbleGreen,
                size: 20,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 56,
              ),
              suffixIcon: suffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 56,
              ),
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 15,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: error
                  ? const Color(0xFFFFF8F7)
                  : const Color(0xFFF7FAF8),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error
                      ? const Color(0xFFD92D20)
                      : const Color(0xFFDDE5DF),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error
                      ? const Color(0xFFD92D20)
                      : kNavAbleGreen,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFB42318),
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  errorText!,
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: NavAbleSize.primaryButton,
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: kNavAbleNavy,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: kNavAbleNavy.withValues(alpha: 0.22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NavAbleRadius.button),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD7DED9))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'OR',
            style: TextStyle(
              color: kNavAbleText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD7DED9))),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        fixedSize: const Size.square(NavAbleSize.primaryButton),
        shape: const CircleBorder(),
        side: const BorderSide(color: Color(0xFFDDE5DF), width: 1.4),
        foregroundColor: kNavAbleGreen,
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        padding: EdgeInsets.zero,
      ),
      child: Icon(icon, size: 30),
    );
  }
}
