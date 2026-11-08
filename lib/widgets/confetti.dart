import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../navable_design.dart';

/// One burst of green confetti falling from the top, driven by [progress]
/// (0..1). Pieces are placed from a fixed seed, so every burst looks the same.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.progress}) : super();

  final double progress;

  static const _colors = [
    NavAblePalette.green,
    NavAblePalette.greenDark,
    Color(0xFF97C459),
    Color(0xFFC0DD97),
    Color(0xFFFAC775),
  ];

  static final List<_Piece> _pieces = () {
    final random = math.Random(7);
    return List.generate(
      42,
      (i) => _Piece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.25,
        drift: (random.nextDouble() - 0.5) * 0.3,
        speed: 0.75 + random.nextDouble() * 0.6,
        spin: (random.nextDouble() - 0.5) * 14,
        width: 6 + random.nextDouble() * 6,
        height: 4 + random.nextDouble() * 8,
        color: _colors[i % _colors.length],
      ),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in _pieces) {
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -20 + t * piece.speed * size.height;
      final x =
          (piece.x + piece.drift * t) * size.width +
          math.sin(t * 9 + piece.x * 6) * 12;
      final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.width,
            height: piece.height,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = piece.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter old) => old.progress != progress;
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.speed,
    required this.spin,
    required this.width,
    required this.height,
    required this.color,
  });

  final double x;
  final double delay;
  final double drift;
  final double speed;
  final double spin;
  final double width;
  final double height;
  final Color color;
}
