import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'home.dart';
import 'login.dart';
import 'splash.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _register() {
    final result = AuthService.register(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Sign up failed.')),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      _fadeRoute(const SplashScreen(nextScreen: HomeScreen())),
      (route) => false,
    );
  }

  void _showGooglePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google sign up needs Firebase or Google Sign-In setup.'),
      ),
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
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _BackButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: kNavAbleAccent,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: const Color(0xFFDDE5DF)),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        kNavAbleNavy.withValues(alpha: 0.07),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_outlined,
                                color: kNavAbleGreen,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Create Your Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kNavAbleNavy,
                                fontSize: 25,
                                height: 1.18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                'Join NavAble for smart, accessible navigation tailored to your needs.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: kNavAbleText,
                                  fontSize: 14,
                                  height: 1.55,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _PremiumCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RegisterField(
                                    label: 'Full Name',
                                    icon: Icons.person_outline,
                                    hintText: 'Enter your full name',
                                    controller: _nameController,
                                  ),
                                  const SizedBox(height: 20),
                                  _RegisterField(
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
                                    hintText: 'email@example.com',
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 20),
                                  _RegisterField(
                                    label: 'Create Password',
                                    icon: Icons.lock_outline,
                                    hintText: 'At least 8 characters',
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        );
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: const Color(0xFF5F6B7A),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _RegisterField(
                                    label: 'Confirm Password',
                                    icon: Icons.lock_reset,
                                    hintText: 'Repeat your password',
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 28),
                                  _PrimaryButton(
                                    label: 'Sign Up',
                                    onPressed: _register,
                                  ),
                                  const SizedBox(height: 18),
                                  const Center(
                                    child: Text.rich(
                                      TextSpan(
                                        text:
                                            'By signing up, you agree to our ',
                                        children: [
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(
                                              color: kNavAbleGreen,
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(
                                              color: kNavAbleGreen,
                                              decoration:
                                                  TextDecoration.underline,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          TextSpan(text: '.'),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: kNavAbleText,
                                        fontSize: 12,
                                        height: 1.45,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _DividerLabel(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton(
                                onPressed: _showGooglePlaceholder,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kNavAbleNavy,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.78),
                                  side: const BorderSide(
                                    color: Color(0xFFDDE5DF),
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'G',
                                      style: TextStyle(
                                        color: kNavAbleGreen,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Text(
                                      'Sign Up with Google',
                                      style: TextStyle(
                                        color: kNavAbleNavy,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Text(
                              'Already have an account?',
                              style: TextStyle(
                                color: Color(0xFF344054),
                                fontSize: 14,
                                letterSpacing: 0,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  _fadeRoute(const LoginScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.only(top: 5),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Sign In Here',
                                style: TextStyle(
                                  color: kNavAbleGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _HelpNotice(),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
      color: kNavAbleNavy,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        fixedSize: const Size(46, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: const Color(0xFFE0E8E2)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kNavAbleNavy.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.label,
    required this.icon,
    required this.hintText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final String label;
  final IconData icon;
  final String hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: kNavAbleGreen, size: 20),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 48, minHeight: 56),
              suffixIcon: suffixIcon,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 48, minHeight: 56),
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 15,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: const Color(0xFFF7FAF8),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE5DF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kNavAbleGreen, width: 1.5),
              ),
            ),
          ),
        ),
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
          height: 58,
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: kNavAbleNavy,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: kNavAbleNavy.withValues(alpha: 0.22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded, size: 26),
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

class _HelpNotice extends StatelessWidget {
  const _HelpNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kNavAbleAccent.withValues(alpha: 0.92),
        border: Border.all(color: const Color(0xFFDDE5DF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: kNavAbleGreen, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Need help signing up?\n',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kNavAbleNavy,
                ),
                children: [
                  TextSpan(
                    text:
                        'Tap the blue button above or call our support line at 1-800-NAV-ABLE for assistance.',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: kNavAbleText,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 12, height: 1.5, letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
  }
}
