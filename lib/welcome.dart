import 'package:flutter/material.dart';

import 'legal.dart';
import 'login.dart';
import 'navable_design.dart';

/// First screen for anyone not signed in: the NavAble promise, the
/// accessibility features NavAble tracks, and Get Started.
///
/// One centered column that never grows wider than [_maxContentWidth], so it
/// reads the same on a phone, a tablet and a desktop browser. Scrolls when the
/// screen is short (small phones, landscape, large text).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const Color _navy = NavAblePalette.navy;
  static const Color _green = NavAblePalette.green;
  static const Color _text = NavAblePalette.text;

  /// The accessibility features NavAble records, with the same icons as the
  /// Home map filter chips.
  static const features = [
    (Icons.accessible_forward_rounded, 'Ramps'),
    (Icons.elevator_outlined, 'Elevators'),
    (Icons.meeting_room_outlined, 'Step-free entry'),
    (Icons.wc_rounded, 'Accessible toilet'),
    (Icons.blind_rounded, 'Tactile paving'),
    (Icons.local_parking_rounded, 'Parking'),
    (Icons.event_seat_outlined, 'Seating'),
  ];

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// Sizes for the space available: phones, tablets, then desktop browsers.
/// A short screen (landscape phone) tightens the vertical spacing.
class _WelcomeMetrics {
  factory _WelcomeMetrics.of(Size size) {
    final width = size.width;
    final short = size.height < 560;
    if (width >= 1024) {
      return _WelcomeMetrics._(
        gutter: 40,
        logo: short ? 88 : 132,
        headline: 38,
        body: 17,
        gap: short ? 0.6 : 1.15,
        buttonWidth: 400,
      );
    }
    if (width >= 600) {
      return _WelcomeMetrics._(
        gutter: 32,
        logo: short ? 84 : 124,
        headline: 34,
        body: 16,
        gap: short ? 0.6 : 1.05,
        buttonWidth: 400,
      );
    }
    return _WelcomeMetrics._(
      gutter: width < 360 ? 20 : 24,
      logo: short ? 72 : (width < 360 ? 96 : 112),
      headline: width < 360 ? 26 : 29,
      body: 15,
      gap: short ? 0.6 : 1,
      buttonWidth: double.infinity,
    );
  }

  const _WelcomeMetrics._({
    required this.gutter,
    required this.logo,
    required this.headline,
    required this.body,
    required this.gap,
    required this.buttonWidth,
  });

  final double gutter;
  final double logo;
  final double headline;
  final double body;

  /// Multiplies the vertical spacing.
  final double gap;
  final double buttonWidth;
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _maxContentWidth = 600.0;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

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
    _intro.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Fades [child] in and lifts it slightly, between [start] and [end] of the
  /// intro (0 to 1), so the parts arrive one after another.
  Widget _enter(double start, double end, Widget child, {double lift = 14}) {
    final progress = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) => Opacity(
        opacity: progress.value,
        child: Transform.translate(
          offset: Offset(0, lift * (1 - progress.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavAbleLightTheme(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const Positioned.fill(child: _WelcomeBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final m = _WelcomeMetrics.of(constraints.biggest);
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _maxContentWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: m.gutter,
                              vertical: 32 * m.gap,
                            ),
                            child: _content(m),
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

  Widget _content(_WelcomeMetrics m) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _enter(
          0,
          0.55,
          lift: 0,
          Semantics(
            label: 'NavAble',
            image: true,
            child: Image.asset(
              'lib/img/logOnly.png',
              width: m.logo,
              height: m.logo,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
        // The logo image has its own empty margin, so less space here.
        SizedBox(height: 24 * m.gap),
        _enter(
          0.15,
          0.7,
          Semantics(
            header: true,
            child: Text(
              'Every Path Made Clear.\nEvery Destination Reached.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WelcomeScreen._navy,
                fontSize: m.headline,
                height: 1.16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
        SizedBox(height: 16 * m.gap),
        _enter(
          0.25,
          0.8,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              "Finding accessible routes shouldn't be a challenge. NavAble "
              'provides real-time, peer-verified navigation for wheelchair '
              'users and those with limited mobility.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WelcomeScreen._text,
                fontSize: m.body,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        SizedBox(height: 32 * m.gap),
        _enter(0.35, 0.9, const _FeatureList()),
        SizedBox(height: 36 * m.gap),
        _enter(
          0.45,
          1,
          SizedBox(
            width: m.buttonWidth,
            child: _PrimaryCtaButton(onPressed: _getStarted),
          ),
        ),
        SizedBox(height: 20 * m.gap),
        _enter(0.5, 1, const _LegalNote()),
      ],
    );
  }
}

/// White with a soft NavAble-green wash at the top and bottom corners.
class _WelcomeBackground extends StatelessWidget {
  const _WelcomeBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3FBF5), Colors.white, Colors.white, Color(0xFFF1FAF3)],
          stops: [0, 0.38, 0.72, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 0.9,
            colors: [Color(0x1A1EA54A), Color(0x001EA54A)],
          ),
        ),
      ),
    );
  }
}

/// "Accessibility features" and every feature NavAble records, as an even
/// grid of equal tiles: one row of 7 when there's room (tablets, desktops),
/// otherwise rows of 4 (phones) or 3 (very narrow or very large text), with
/// the last row centered.
class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            'ACCESSIBILITY FEATURES',
            textAlign: TextAlign.center,
            style: TextStyle(
              // The darker brand green: readable at this small size.
              color: NavAblePalette.greenDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Narrowest a tile can be and still fit "Accessible" on a line.
            final minTile = 64 * textScale;
            final columns = [7, 4, 3].firstWhere(
              (n) => n * minTile + (n - 1) * _gap <= width,
              orElse: () => 3,
            );
            final tile = ((width - (columns - 1) * _gap) / columns).clamp(
              0.0,
              96.0,
            );
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: _gap,
              runSpacing: 18,
              children: [
                for (final (icon, label) in WelcomeScreen.features)
                  SizedBox(
                    width: tile,
                    child: _FeatureTile(icon: icon, label: label),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A feature's icon in a soft green circle, with its name underneath.
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDCE8DF)),
              boxShadow: [
                BoxShadow(
                  color: WelcomeScreen._navy.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ExcludeSemantics(
              child: Icon(icon, color: WelcomeScreen._green, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: WelcomeScreen._navy,
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: WelcomeScreen._navy,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      height: 1.5,
    );
    return Text.rich(
      TextSpan(
        text: 'By continuing, you agree to our ',
        children: [
          legalLink(context, 'Terms of Service', LegalDoc.terms, linkStyle),
          const TextSpan(text: ' and '),
          legalLink(context, 'Privacy Policy', LegalDoc.privacy, linkStyle),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF59616B),
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Navy Get Started button: lifts on hover, presses in on tap, and shows a
/// green focus ring for keyboard users.
class _PrimaryCtaButton extends StatefulWidget {
  const _PrimaryCtaButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PrimaryCtaButton> createState() => _PrimaryCtaButtonState();
}

class _PrimaryCtaButtonState extends State<_PrimaryCtaButton> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: reduceMotion ? 1 : (_pressed ? 0.98 : 1),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            width: double.infinity,
            height: NavAbleSize.primaryButton,
            child: FilledButton(
              onPressed: widget.onPressed,
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(WelcomeScreen._navy),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                overlayColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.pressed)
                      ? Colors.white.withValues(alpha: 0.12)
                      : states.contains(WidgetState.hovered)
                      ? Colors.white.withValues(alpha: 0.07)
                      : null,
                ),
                elevation: WidgetStatePropertyAll(_hovered ? 10 : 6),
                shadowColor: WidgetStatePropertyAll(
                  WelcomeScreen._navy.withValues(alpha: 0.28),
                ),
                mouseCursor: const WidgetStatePropertyAll(
                  SystemMouseCursors.click,
                ),
                shape: WidgetStateProperty.resolveWith(
                  (states) => RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NavAbleRadius.button),
                    side: states.contains(WidgetState.focused)
                        ? const BorderSide(
                            color: WelcomeScreen._green,
                            width: 3,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          )
                        : BorderSide.none,
                  ),
                ),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              // Shrinks rather than overflows on a narrow phone with large
              // text.
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Get Started'),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
