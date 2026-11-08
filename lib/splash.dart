import 'dart:async';

import 'package:flutter/material.dart';

import 'navable_design.dart';
import 'widgets/caregiver_loader.dart';

/// Opening screen: the NavAble logo, name and tagline arrive in one smooth
/// entrance, then the app fades in. Always white, in light and dark mode.
/// Tap anywhere to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextScreen});

  final Widget nextScreen;

  /// How long the splash stays before moving on.
  static const duration = Duration(milliseconds: 1800);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _continueTimer;
  bool _hasContinued = false;

  @override
  void initState() {
    super.initState();
    _continueTimer = Timer(SplashScreen.duration, _continue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "remove animations": show everything at once.
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
    } else if (!_intro.isAnimating && _intro.value == 0) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _continueTimer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  void _continue() {
    if (_hasContinued || !mounted) return;
    _hasContinued = true;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
      ),
    );
  }

  /// Part of the entrance between [start] and [end] (0..1 of the intro).
  Animation<double> _step(
    double start,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(start, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    const background = Colors.white;
    const secondary = NavAblePalette.text;

    final logoIn = _step(0, 0.5);
    final logoPop = _step(0, 0.6, Curves.easeOutBack);
    final nameIn = _step(0.3, 0.75);
    final taglineIn = _step(0.5, 0.9);
    final loaderIn = _step(0.6, 1);
    final footerIn = _step(0.65, 1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _continue,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            // Full width, so everything sits in the horizontal centre.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: double.infinity),
              const Spacer(flex: 5),
              FadeTransition(
                opacity: logoIn,
                child: ScaleTransition(
                  scale: Tween(begin: 0.86, end: 1.0).animate(logoPop),
                  child: const _LogoTile(),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: nameIn,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(nameIn),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Nav',
                          style: TextStyle(color: NavAblePalette.navy),
                        ),
                        const TextSpan(
                          text: 'Able',
                          style: TextStyle(color: NavAblePalette.green),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: taglineIn,
                child: Text(
                  'Accessible navigation for everyone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 76),
              FadeTransition(
                opacity: loaderIn,
                child: const CaregiverLoader(width: 112),
              ),
              const Spacer(flex: 5),
              FadeTransition(
                opacity: footerIn,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: secondary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cebu, Philippines',
                      style: TextStyle(
                        color: secondary.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo on a white rounded tile, like an app icon.
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE6EEF0)),
        boxShadow: [
          BoxShadow(
            color: NavAblePalette.navy.withValues(alpha: 0.07),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // The image has wide empty margins; cover crops them so the figure
      // fills the tile.
      child: Image.asset(
        'lib/img/logOnly.png',
        fit: BoxFit.cover,
        semanticLabel: 'NavAble logo',
      ),
    );
  }
}
