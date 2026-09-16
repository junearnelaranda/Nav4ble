import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'home.dart';
import 'login.dart';
import 'navable_design.dart';
import 'splash.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
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

  Future<void> _register() async {
  FocusManager.instance.primaryFocus?.unfocus();

  final isFormValid = _formKey.currentState?.validate() ?? false;
  setState(() => _showTermsError = !_acceptedTerms);

  if (!isFormValid || !_acceptedTerms) {
    return;
  }

  final result = await AuthService.register(
    fullName: _nameController.text,
    email: _emailController.text,
    password: _passwordController.text,
    confirmPassword: _confirmPasswordController.text,
  );

  if (!mounted) return;

  if (!result.isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Sign up failed.'),
      ),
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
                                border: Border.all(
                                  color: const Color(0xFFDDE5DF),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kNavAbleNavy.withValues(alpha: 0.07),
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
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RegisterField(
                                      label: 'Full Name',
                                      icon: Icons.person_outline,
                                      hintText: 'Enter your full name',
                                      controller: _nameController,
                                      keyboardType: TextInputType.name,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.name],
                                      validator: (value) {
                                        if ((value ?? '').trim().length < 2) {
                                          return 'Enter your full name.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _RegisterField(
                                      label: 'Email Address',
                                      icon: Icons.email_outlined,
                                      hintText: 'email@example.com',
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      validator: (value) {
                                        if (!AuthService.isValidEmail(
                                          value ?? '',
                                        )) {
                                          return 'Enter a valid email address.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _RegisterField(
                                      label: 'Create Password',
                                      icon: Icons.lock_outline,
                                      hintText: 'At least 8 characters',
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      validator: (value) {
                                        if ((value ?? '').length < 8) {
                                          return 'Use at least 8 characters.';
                                        }
                                        return null;
                                      },
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
                                      obscureText: _obscureConfirmPassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      validator: (value) {
                                        if ((value ?? '').isEmpty) {
                                          return 'Confirm your password.';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Passwords do not match.';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _register(),
                                      suffixIcon: IconButton(
                                        tooltip: _obscureConfirmPassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () {
                                          setState(
                                            () => _obscureConfirmPassword =
                                                !_obscureConfirmPassword,
                                          );
                                        },
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: const Color(0xFF5F6B7A),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _TermsAgreement(
                                      value: _acceptedTerms,
                                      showError: _showTermsError,
                                      onChanged: (value) {
                                        setState(() {
                                          _acceptedTerms = value;
                                          if (value) {
                                            _showTermsError = false;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 22),
                                    _PrimaryButton(
                                      label: 'Sign Up',
                                      onPressed: _register,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _DividerLabel(),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: NavAbleSize.primaryButton,
                              child: OutlinedButton(
                                onPressed: _showGooglePlaceholder,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kNavAbleNavy,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.78,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFDDE5DF),
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      NavAbleRadius.button,
                                    ),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _GoogleLogo(),
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
        fixedSize: const Size.square(NavAbleSize.compactControl),
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
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      color: NavAblePalette.surface,
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
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final String label;
  final IconData icon;
  final String hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

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
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          enableSuggestions: !obscureText,
          autocorrect: !obscureText,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: kNavAbleGreen, size: 20),
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
            fillColor: const Color(0xFFF7FAF8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDE5DF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kNavAbleGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFB42318)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFB42318),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsAgreement extends StatelessWidget {
  const _TermsAgreement({
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Accept the Terms of Service and Privacy Policy',
      checked: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: value,
                      onChanged: (nextValue) => onChanged(nextValue ?? false),
                      activeColor: kNavAbleGreen,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: showError
                            ? const Color(0xFFB42318)
                            : const Color(0xFFB8C2BE),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        children: const [
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: kNavAbleGreen,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: kNavAbleGreen,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                      style: TextStyle(
                        color: showError
                            ? const Color(0xFFB42318)
                            : kNavAbleText,
                        fontSize: 12,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showError)
            const Padding(
              padding: EdgeInsets.only(left: 32, top: 6),
              child: Text(
                'Accept the terms to create your account.',
                style: TextStyle(
                  color: Color(0xFFB42318),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
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

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.shortestSide * 0.19;
    final radius = (size.shortestSide - strokeWidth) / 2;

    Paint segment(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final ring = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(ring, _radians(-140), _radians(95), false, segment(_red));
    canvas.drawArc(ring, _radians(140), _radians(80), false, segment(_yellow));
    canvas.drawArc(ring, _radians(45), _radians(95), false, segment(_green));
    canvas.drawArc(ring, _radians(-45), _radians(90), false, segment(_blue));

    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - strokeWidth * 0.25, center.dy),
      segment(_blue)..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
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
        borderRadius: BorderRadius.circular(NavAbleRadius.card),
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
