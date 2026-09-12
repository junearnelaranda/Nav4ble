import 'package:flutter/material.dart';

import 'login.dart';
import 'navable_design.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const Color _navy = NavAblePalette.navy;
  static const Color _green = NavAblePalette.green;
  static const Color _text = NavAblePalette.text;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
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
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'lib/img/logOnly.png',
                                  width: 152,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 48),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 330,
                                  ),
                                  child: Text(
                                    'Every Path Made Clear.\nEvery Destination Reached.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: WelcomeScreen._navy,
                                      fontSize: 29,
                                      height: 1.18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 322,
                                  ),
                                  child: Text(
                                    "Finding accessible routes shouldn't be a challenge. NavAble provides real-time, peer-verified navigation for wheelchair users and those with limited mobility.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: WelcomeScreen._text,
                                      fontSize: 15,
                                      height: 1.68,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const _FeatureChips(),
                                const SizedBox(height: 34),
                                _PrimaryCtaButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder<void>(
                                        transitionDuration: const Duration(
                                          milliseconds: 360,
                                        ),
                                        reverseTransitionDuration:
                                            const Duration(milliseconds: 260),
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => const LoginScreen(),
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              final curved = CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutCubic,
                                              );

                                              return FadeTransition(
                                                opacity: curved,
                                                child: SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: const Offset(
                                                      0.04,
                                                      0,
                                                    ),
                                                    end: Offset.zero,
                                                  ).animate(curved),
                                                  child: child,
                                                ),
                                              );
                                            },
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                Text.rich(
                                  TextSpan(
                                    text: 'By continuing, you agree to our ',
                                    children: [
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: TextStyle(
                                          color: WelcomeScreen._navy,
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
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
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
          ],
        ),
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
            ? const Offset(70, -60)
            : const Offset(-80, 84),
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                WelcomeScreen._green.withValues(alpha: 0.09),
                WelcomeScreen._green.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChips extends StatelessWidget {
  const _FeatureChips();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _FeatureChip(icon: Icons.accessible, label: 'Ramp Access'),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _FeatureChip(icon: Icons.elevator, label: 'Elevators'),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _FeatureChip(icon: Icons.map_outlined, label: 'Smart Routing'),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NavAbleSize.control,
      child: NavAbleSurface(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        borderRadius: 28,
        color: const Color(0xFFF5F9F5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: WelcomeScreen._green, size: 20),
            const SizedBox(width: 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: WelcomeScreen._navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryCtaButton extends StatefulWidget {
  const _PrimaryCtaButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PrimaryCtaButton> createState() => _PrimaryCtaButtonState();
}

class _PrimaryCtaButtonState extends State<_PrimaryCtaButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }

    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _isPressed ? 0.975 : (_isHovered ? 1.01 : 1),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            width: double.infinity,
            height: NavAbleSize.primaryButton,
            child: FilledButton(
              onPressed: widget.onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: WelcomeScreen._navy,
                foregroundColor: Colors.white,
                elevation: _isHovered ? 10 : 8,
                shadowColor: WelcomeScreen._navy.withValues(alpha: 0.22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NavAbleRadius.button),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Get Started'),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward_rounded, size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
