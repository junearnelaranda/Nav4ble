import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../navable_design.dart';

/// Loading animation: a caregiver in a green shirt pushing a person in a
/// wheelchair. Simple black figures; the legs walk, the wheels turn and the
/// ground slides by, so they look like they're rolling forward.
class CaregiverLoader extends StatefulWidget {
  const CaregiverLoader({super.key, this.width = 150});

  final double width;

  @override
  State<CaregiverLoader> createState() => _CaregiverLoaderState();
}

class _CaregiverLoaderState extends State<CaregiverLoader>
    with SingleTickerProviderStateMixin {
  // One walking step.
  late final AnimationController _step = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Remove animations" on: a still picture instead.
    if (MediaQuery.of(context).disableAnimations) {
      _step.stop();
    } else if (!_step.isAnimating) {
      _step.repeat();
    }
  }

  @override
  void dispose() {
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: widget.width,
        height: widget.width * CaregiverLoaderPainter.aspect,
        child: AnimatedBuilder(
          animation: _step,
          builder: (context, _) => CustomPaint(
            painter: CaregiverLoaderPainter(progress: _step.value),
          ),
        ),
      ),
    );
  }
}

/// Draws one moment of the walk. [progress] 0..1 is one step.
class CaregiverLoaderPainter extends CustomPainter {
  const CaregiverLoaderPainter({required this.progress});

  final double progress;

  /// Height / width of the drawing.
  static const aspect = 0.46;

  static const _ink = Color(0xFF111418);
  static const _shirt = NavAblePalette.greenDark;
  static const _ground = Color(0xFFD9DEE3);

  // Drawn on a 150 x 69 grid, then scaled to the widget size.
  static const _gridWidth = 150.0;
  static const _wheel = 13.0;
  static const _thigh = 13.0;
  static const _shin = 13.0;
  static const _swing = 0.42; // radians each way
  // Ground covered by one step: both feet move one stride.
  static final _stride = 2 * (_thigh + _shin) * math.sin(_swing);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _gridWidth;
    canvas.scale(scale);
    final groundY = size.height / scale - 4;
    final phase = progress * 2 * math.pi;

    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint stroke(double width, [Color color = _ink]) => Paint.from(line)
      ..strokeWidth = width
      ..color = color;
    final fill = Paint()..color = _ink;

    // Ground with dashes sliding left at walking speed.
    canvas.drawLine(
      Offset(6, groundY + 1.5),
      Offset(_gridWidth - 6, groundY + 1.5),
      stroke(1.5, _ground),
    );
    const dashGap = 18.0;
    final shift = (progress * _stride) % dashGap;
    for (var x = 10 - shift; x < _gridWidth - 10; x += dashGap) {
      if (x < 10) continue;
      canvas.drawLine(
        Offset(x, groundY + 1.5),
        Offset(x + 6, groundY + 1.5),
        stroke(1.5, const Color(0xFFB8C0C8)),
      );
    }

    // ---- Wheelchair (facing right) ----
    const wheelX = 98.0;
    final wheelCenter = Offset(wheelX, groundY - _wheel);
    final seatY = groundY - 22;
    final turn = progress * _stride / _wheel; // rolling without slipping
    canvas.drawCircle(wheelCenter, _wheel, stroke(2.6));
    for (var i = 0; i < 3; i++) {
      final a = turn + i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a)) * (_wheel - 1.5);
      canvas.drawLine(wheelCenter - d, wheelCenter + d, stroke(1.1));
    }
    canvas.drawCircle(wheelCenter, 2, fill);
    // Frame: seat, backrest and push handle, front leg to the footrest.
    final handle = Offset(wheelX - 19, seatY - 16);
    canvas.drawPath(
      Path()
        ..moveTo(handle.dx, handle.dy)
        ..lineTo(wheelX - 12, seatY - 16)
        ..lineTo(wheelX - 10, seatY)
        ..lineTo(wheelX + 9, seatY)
        ..lineTo(wheelX + 15, groundY - 7)
        ..lineTo(wheelX + 20, groundY - 7),
      stroke(2.4),
    );
    // Front caster.
    canvas.drawCircle(Offset(wheelX + 15, groundY - 3.5), 3.2, stroke(2));

    // ---- Seated person ----
    final hip = Offset(wheelX - 4, seatY - 3);
    final shoulder = Offset(wheelX - 6, seatY - 19);
    canvas.drawLine(hip, shoulder, stroke(5));
    canvas.drawCircle(Offset(wheelX - 4, seatY - 27), 5, fill);
    final knee = Offset(wheelX + 10, seatY - 4);
    canvas.drawPath(
      Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(wheelX + 15, groundY - 9),
      stroke(4.2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx + 1, shoulder.dy + 2)
        ..lineTo(wheelX + 1, seatY - 9)
        ..lineTo(wheelX + 6, seatY - 6),
      stroke(3),
    );

    // ---- Caregiver ----
    const walkerX = 60.0;
    final bob = math.cos(phase * 2).abs() * 1.2; // body lifts mid-step
    final walkerHip = Offset(walkerX, groundY - (_thigh + _shin) + 0.5 - bob);
    final walkerShoulder = Offset(walkerX + 4, walkerHip.dy - 22);

    // Legs: opposite swings; the leg moving forward bends its knee.
    void leg(double swing, double lift) {
      final knee =
          walkerHip + Offset(math.sin(swing), math.cos(swing)) * _thigh;
      final shinAngle = swing - lift * 0.9;
      final foot =
          knee + Offset(math.sin(shinAngle), math.cos(shinAngle)) * _shin;
      canvas.drawPath(
        Path()
          ..moveTo(walkerHip.dx, walkerHip.dy)
          ..lineTo(knee.dx, knee.dy)
          ..lineTo(foot.dx, foot.dy)
          ..lineTo(foot.dx + 3.5, foot.dy),
        stroke(4.2),
      );
    }

    final swing = math.sin(phase) * _swing;
    // A leg lifts while it swings forward (its swing is increasing).
    final liftA = math.max(0.0, math.cos(phase));
    final liftB = math.max(0.0, -math.cos(phase));
    leg(-swing, liftB); // back leg drawn first
    leg(swing, liftA);

    // Green shirt torso.
    canvas.drawLine(
      walkerHip + const Offset(0, -2),
      walkerShoulder,
      stroke(9, _shirt),
    );
    // Head.
    canvas.drawCircle(walkerShoulder + const Offset(2, -9), 5.5, fill);
    // Arm reaching to the push handle.
    final elbow = Offset(
      (walkerShoulder.dx + handle.dx) / 2,
      math.max(walkerShoulder.dy, handle.dy) + 4,
    );
    canvas.drawPath(
      Path()
        ..moveTo(walkerShoulder.dx, walkerShoulder.dy + 1)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(handle.dx, handle.dy),
      stroke(3.4),
    );
  }

  @override
  bool shouldRepaint(covariant CaregiverLoaderPainter old) =>
      old.progress != progress;
}
