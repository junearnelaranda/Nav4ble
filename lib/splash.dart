import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.nextScreen});

  final Widget? nextScreen;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasContinued = false;

  static const Color _navy = Color(0xFF0F2B4D);
  static const Color _green = Color(0xFF5BC66B);
  static const Color _text = Color(0xFF4A5563);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _continueIfPossible();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continueIfPossible() {
    if (widget.nextScreen == null || _hasContinued) {
      return;
    }

    _hasContinued = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen!,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _continueIfPossible,
      child: Scaffold(
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
                    return SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Column(
                        children: [
                          const Spacer(flex: 7),
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Opacity(
                                opacity: 0.92 + (_controller.value * 0.08),
                                child: Transform.scale(
                                  scale: 0.985 + (_controller.value * 0.015),
                                  child: child,
                                ),
                              );
                            },
                            child: SizedBox(
                              width: constraints.maxWidth * 0.38,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 132,
                                  maxWidth: 168,
                                ),
                                child: Image.asset(
                                  'lib/img/logOnly.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 32,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Nav',
                                  style: TextStyle(color: _navy),
                                ),
                                TextSpan(
                                  text: 'Able',
                                  style: TextStyle(color: _green),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Accessible navigation for everyone',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _text,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                          const Spacer(flex: 7),
                          SizedBox(
                            width: 136,
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: SizedBox(
                                    height: 5,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: _green.withValues(
                                              alpha: 0.16,
                                            ),
                                          ),
                                        ),
                                        AnimatedBuilder(
                                          animation: _controller,
                                          builder: (context, child) {
                                            return FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: 0.26 +
                                                  (_controller.value * 0.74),
                                              child: child,
                                            );
                                          },
                                          child: const DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: _green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'INITIALIZING',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
            ? const Offset(74, -62)
            : const Offset(-88, 92),
        child: Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _SplashScreenState._green.withValues(alpha: 0.08),
                _SplashScreenState._green.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
