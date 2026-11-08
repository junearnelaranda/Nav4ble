part of '../home.dart';

/// Full-screen moment for reaching a new level: the badge pops in with green
/// confetti, then Continue. Plays once per level (see CelebrationStore).
class _LevelUpScreen extends StatefulWidget {
  const _LevelUpScreen({required this.level, required this.name});

  final int level;
  final String name;

  @override
  State<_LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<_LevelUpScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1; // no confetti or motion
    } else if (_intro.value == 0 && !_intro.isAnimating) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final (badgeBackground, badgeForeground) = _LevelBadge.colorsFor(
      badgeFor(widget.level),
      context.isNavAbleDark,
    );
    final textIn = _step(0.3, 0.7);
    return Scaffold(
      body: Stack(
        children: [
          if (!reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => CustomPaint(
                    painter: ConfettiPainter(progress: _intro.value),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _step(0, 0.5, Curves.easeOutBack),
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          color: badgeBackground,
                          shape: BoxShape.circle,
                          border: Border.all(color: badgeForeground, width: 3),
                        ),
                        child: Icon(
                          Icons.military_tech_rounded,
                          size: 68,
                          color: badgeForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: textIn,
                      child: Column(
                        children: [
                          Text(
                            'Level up',
                            style: TextStyle(
                              color: context.navAbleSecondaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "You're now ${widget.name}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.navAblePrimaryText,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Level ${widget.level}',
                            style: TextStyle(
                              color: context.navAbleSecondaryText,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Thanks for making Cebu more accessible.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.navAbleSecondaryText,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ScaleTransition(
                      scale: _step(0.6, 1, Curves.easeOutBack),
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
