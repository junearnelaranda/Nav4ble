import 'package:flutter/material.dart';

import 'login.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color _navy = Color(0xFF001832);
  static const Color _green = Color(0xFF008A3D);
  static const Color _text = Color(0xFF4A4F5A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 74),
                      Image.asset(
                        'lib/img/logOnly.png',
                        width: 116,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 64),
                      const Text(
                        'Every Path Made Clear.\nEvery Destination\nReached.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _navy,
                          fontSize: 22,
                          height: 1.28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Finding accessible routes shouldn't\n"
                        'be a challenge. NavAble provides\n'
                        'real-time, peer-verified navigation for\n'
                        'wheelchair users and those with\n'
                        'limited mobility.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _text,
                          fontSize: 15,
                          height: 1.55,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FeatureChip(
                            icon: Icons.accessible,
                            label: 'Ramp Access',
                          ),
                          _FeatureChip(
                            icon: Icons.elevator,
                            label: 'Elevators',
                          ),
                          _FeatureChip(
                            icon: Icons.map_outlined,
                            label: 'Smart Routing',
                          ),
                        ],
                      ),
                      const SizedBox(height: 154),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Get Started'),
                              SizedBox(width: 14),
                              Icon(Icons.arrow_forward, size: 22),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to our ',
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: _navy,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF3F4650),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF2),
        border: Border.all(color: const Color(0xFFD8DBE0)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WelcomeScreen._green, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111722),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
