import 'package:flutter/material.dart';

import 'forgot.dart';
import 'register.dart';
import 'splash.dart';

const Color kNavAbleNavy = Color(0xFF001832);
const Color kNavAbleGreen = Color(0xFF008A3D);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberDevice = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 22),
          child: Column(
            children: [
              Image.asset(
                'lib/img/logOnly.png',
                width: 96,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
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
                  color: Color(0xFF536071),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Smart Navigation for Every Ability',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF4B525E),
                  fontSize: 12,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0E4EA)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LoginField(
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      hintText: 'june@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    _LoginField(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      hintText: '********',
                      obscureText: _obscurePassword,
                      labelAction: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: kNavAbleGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF596170),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Checkbox(
                            value: _rememberDevice,
                            onChanged: (value) {
                              setState(() => _rememberDevice = value ?? false);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            side: const BorderSide(
                              color: Color(0xFF8E96A3),
                              width: 2,
                            ),
                            activeColor: kNavAbleGreen,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Remember this device',
                          style: TextStyle(
                            color: Color(0xFF303846),
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SplashScreen(),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kNavAbleNavy,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFC9CED6))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 26),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Color(0xFF4B525E),
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFC9CED6))),
                ],
              ),
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundIconButton(icon: Icons.fingerprint),
                  SizedBox(width: 22),
                  _RoundIconButton(icon: Icons.face),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'New to NavAble? ',
                    style: TextStyle(
                      color: Color(0xFF303846),
                      fontSize: 14,
                      letterSpacing: 0,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Register Account',
                      style: TextStyle(
                        color: kNavAbleGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.icon,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.labelAction,
  });

  final String label;
  final IconData icon;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? labelAction;

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
                  color: Color(0xFF303846),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            ?labelAction,
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: TextField(
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF596170), size: 18),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 54,
              ),
              suffixIcon: suffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 54,
              ),
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFFC5CAD2),
                fontSize: 15,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: const Color(0xFFF3F5F8),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 17,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF596170), width: 1),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: kNavAbleGreen, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        fixedSize: const Size(56, 56),
        shape: const CircleBorder(),
        side: const BorderSide(color: Color(0xFFC7CED8), width: 2),
        foregroundColor: kNavAbleGreen,
        padding: EdgeInsets.zero,
      ),
      child: Icon(icon, size: 30),
    );
  }
}
