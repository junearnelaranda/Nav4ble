part of '../home.dart';

/// What the scanning screen hands back: the scan, and the choice the user
/// makes on the result screen that replaced it ([action]); or the [error].
typedef _ScanOutcome = ({
  PhotoAnalysis? analysis,
  Future<_DetectionAction?>? action,
  Object? error,
});

/// Shown while NavAble AI scans the photos: the photo under a sweeping green
/// scan beam, viewfinder corners and detection points, with status lines for
/// what the model looks for. When the scan is done it shows a short check,
/// then fades into the result screen, which takes its place.
class _AiScanningScreen extends StatefulWidget {
  const _AiScanningScreen({
    required this.photos,
    required this.analysis,
    required this.resultScreen,
  });

  final List<Uint8List> photos;
  final Future<PhotoAnalysis> analysis;
  final Widget Function(PhotoAnalysis analysis) resultScreen;

  @override
  State<_AiScanningScreen> createState() => _AiScanningScreenState();
}

class _AiScanningScreenState extends State<_AiScanningScreen>
    with TickerProviderStateMixin {
  /// Long enough for one full sweep, so a fast on-device scan still reads.
  static const _minimumScan = Duration(milliseconds: 2400);
  static const _statusLines = [
    'Looking for ramps…',
    'Checking entrances…',
    'Spotting elevators…',
    'Finding accessible restrooms…',
    'Checking tactile paving…',
  ];

  late final AnimationController _beam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final AnimationController _done = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Timer? _ticker;
  int _tick = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Status line and (with several photos) the photo change every 1.1 s.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 1100),
      (_) => setState(() => _tick++),
    );
    _run();
  }

  Future<void> _run() async {
    final PhotoAnalysis analysis;
    try {
      final results = await Future.wait<Object>([
        widget.analysis,
        Future<void>.delayed(_minimumScan).then((_) => 0),
      ]);
      analysis = results.first as PhotoAnalysis;
    } catch (error) {
      if (mounted) {
        Navigator.of(
          context,
        ).pop<_ScanOutcome>((analysis: null, action: null, error: error));
      }
      return;
    }
    if (!mounted) return;
    _ticker?.cancel();
    _beam.stop();
    setState(() => _finished = true);
    await _done.forward();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final result = PageRouteBuilder<_DetectionAction>(
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, _, _) => widget.resultScreen(analysis),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    // The result screen replaces this one; its choice comes back through
    // `result.popped`, so closing it returns straight to the form.
    Navigator.of(context).pushReplacement<_DetectionAction, _ScanOutcome>(
      result,
      result: (analysis: analysis, action: result.popped, error: null),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _beam.dispose();
    _done.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final photoCount = widget.photos.length;
    final photoIndex = photoCount == 0 ? 0 : _tick % photoCount;
    final status = _finished
        ? 'Scan complete'
        : _statusLines[_tick % _statusLines.length];

    return Scaffold(
      backgroundColor: NavAblePalette.darkCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Cancel scan',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (photoCount > 0)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Image.memory(
                                widget.photos[photoIndex],
                                key: ValueKey(photoIndex),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            )
                          else
                            const ColoredBox(color: NavAblePalette.darkSurface),
                          // Darken the photo so the beam and marks stand out.
                          const ColoredBox(color: Color(0x66101820)),
                          AnimatedBuilder(
                            animation: Listenable.merge([_beam, _done]),
                            builder: (context, _) => CustomPaint(
                              painter: _ScanPainter(
                                beam: reduceMotion
                                    ? 0.5
                                    : Curves.easeInOut.transform(_beam.value),
                                done: _done.value,
                                showBeam: !_finished && !reduceMotion,
                              ),
                            ),
                          ),
                          if (_finished)
                            Center(
                              child: ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: _done,
                                  curve: Curves.easeOutBack,
                                ),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: const BoxDecoration(
                                    color: NavAblePalette.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: NavAblePalette.darkCanvas,
                                    size: 44,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _finished
                        ? Icons.verified_rounded
                        : Icons.auto_awesome_rounded,
                    color: NavAblePalette.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'NavAble AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 22,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    status,
                    key: ValueKey(status),
                    // Screen readers hear each step.
                    semanticsLabel: status,
                    style: const TextStyle(
                      color: Color(0xFFB8C6D1),
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (photoCount > 1) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photoCount; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == photoIndex ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == photoIndex
                              ? NavAblePalette.green
                              : NavAblePalette.darkBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid, viewfinder corners, detection points and the scan beam.
/// [beam] is the beam's height (0 top, 1 bottom); [done] 0..1 is the finish.
class _ScanPainter extends CustomPainter {
  const _ScanPainter({
    required this.beam,
    required this.done,
    required this.showBeam,
  });

  final double beam;
  final double done;
  final bool showBeam;

  // Where detection points appear, as fractions of the photo.
  static const _points = [
    Offset(0.28, 0.32),
    Offset(0.70, 0.24),
    Offset(0.42, 0.58),
    Offset(0.76, 0.66),
    Offset(0.22, 0.80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const green = NavAblePalette.green;

    // Faint grid.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      final y = size.height * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Viewfinder corners.
    const inset = 18.0;
    const arm = 30.0;
    final corner = Paint()
      ..color = green
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
      final x = dx == 0 ? inset : size.width - inset;
      final y = dy == 0 ? inset : size.height - inset;
      final sx = dx == 0 ? 1.0 : -1.0;
      final sy = dy == 0 ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, y + sy * arm)
          ..lineTo(x, y)
          ..lineTo(x + sx * arm, y),
        corner,
      );
    }

    // Detection points light up once the beam has passed them, then fade
    // when the scan finishes.
    final beamY = beam * size.height;
    for (final point in _points) {
      final center = Offset(point.dx * size.width, point.dy * size.height);
      final passed = (beamY - center.dy).abs() < size.height * 0.18;
      final glow = showBeam ? (passed ? 1.0 : 0.25) : 1.0 - done;
      if (glow <= 0) continue;
      canvas.drawCircle(
        center,
        14,
        Paint()..color = green.withValues(alpha: 0.18 * glow),
      );
      canvas.drawCircle(
        center,
        4,
        Paint()..color = green.withValues(alpha: 0.9 * glow),
      );
    }

    if (!showBeam) return;
    // Beam: a soft glow band with a bright line in the middle.
    final band = Rect.fromLTWH(0, beamY - 60, size.width, 120);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            green.withValues(alpha: 0),
            green.withValues(alpha: 0.28),
            green.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(0, beamY),
      Offset(size.width, beamY),
      Paint()
        ..color = green
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanPainter old) =>
      old.beam != beam || old.done != done || old.showBeam != showBeam;
}
