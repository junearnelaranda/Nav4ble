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

  static const Color _navy = Color(0xFF071A35);
  static const Color _green = Color(0xFF148E43);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.nextScreen == null) {
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.nextScreen!),
        );
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF3FFF8),
                Color(0xFFFBFFFC),
                Color(0xFFEFFFF7),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    const Spacer(flex: 8),
                    Image.asset(
                      'lib/img/logOnly.png',
                      width: constraints.maxWidth * 0.34,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 10),
                    const Text(
                      'Accessible navigation for everyone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF2D9A55),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(flex: 9),
                    SizedBox(
                      width: 104,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 3,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFB8BDB9),
                                    ),
                                  ),
                                  AnimatedBuilder(
                                    animation: _controller,
                                    builder: (context, child) {
                                      return FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor:
                                            0.24 + (_controller.value * 0.76),
                                        child: child,
                                      );
                                    },
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFF9FD8B9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'INITIALIZING...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8A8F8B),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
