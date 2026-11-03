import 'dart:math' as math;
import 'dart:typed_data';

/// How a photo was fitted into the model's square input: scaled to fit,
/// then centered with padding ("letterbox"), the same way YOLO trains.
class Letterbox {
  const Letterbox({
    required this.inputSize,
    required this.imageWidth,
    required this.imageHeight,
  });

  final int inputSize;
  final int imageWidth;
  final int imageHeight;

  double get scale => math.min(inputSize / imageWidth, inputSize / imageHeight);
  int get scaledWidth => (imageWidth * scale).round();
  int get scaledHeight => (imageHeight * scale).round();
  int get padX => (inputSize - scaledWidth) ~/ 2;
  int get padY => (inputSize - scaledHeight) ~/ 2;
}

/// Turns a YOLO11 output tensor (shape `[1, 4 + classes, anchors]`,
/// exported without NMS) into detections shaped like Roboflow's:
/// `{class, confidence, x, y, width, height}` with the box center and size
/// in original-photo pixels.
List<Map<String, dynamic>> decodeYoloOutput({
  required Float32List output,
  required int anchors,
  required List<String> labels,
  required Letterbox letterbox,
  double confidenceThreshold = 0.25,
  double iouThreshold = 0.45,
  int maxDetections = 20,
}) {
  final classes = labels.length;
  if (output.length != (4 + classes) * anchors) {
    throw ArgumentError(
      'Output has ${output.length} values; expected '
      '${(4 + classes) * anchors} for $classes classes x $anchors anchors.',
    );
  }
  double at(int row, int anchor) => output[row * anchors + anchor];

  // TFLite exports give box values as fractions of the input size; other
  // exports give pixels. Fractions never exceed ~1.
  var normalized = true;
  for (var i = 0; i < anchors && normalized; i++) {
    if (at(2, i) > 2 || at(3, i) > 2) normalized = false;
  }
  final unit = normalized ? letterbox.inputSize.toDouble() : 1.0;

  final candidates = <_Box>[];
  for (var i = 0; i < anchors; i++) {
    var best = 0;
    for (var c = 1; c < classes; c++) {
      if (at(4 + c, i) > at(4 + best, i)) best = c;
    }
    final score = at(4 + best, i);
    if (score < confidenceThreshold) continue;
    // Undo the letterbox: remove padding, then scale back to the photo.
    final cx = (at(0, i) * unit - letterbox.padX) / letterbox.scale;
    final cy = (at(1, i) * unit - letterbox.padY) / letterbox.scale;
    final w = at(2, i) * unit / letterbox.scale;
    final h = at(3, i) * unit / letterbox.scale;
    candidates.add(_Box(best, score, cx, cy, w, h));
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  final kept = <_Box>[];
  for (final box in candidates) {
    if (kept.length >= maxDetections) break;
    final overlaps = kept.any(
      (other) => other.label == box.label && other.iou(box) > iouThreshold,
    );
    if (!overlaps) kept.add(box);
  }

  double clampX(double v) => v.clamp(0, letterbox.imageWidth).toDouble();
  double clampY(double v) => v.clamp(0, letterbox.imageHeight).toDouble();
  double round1(double v) => (v * 10).round() / 10;
  return [
    for (final box in kept)
      () {
        final left = clampX(box.cx - box.w / 2);
        final right = clampX(box.cx + box.w / 2);
        final top = clampY(box.cy - box.h / 2);
        final bottom = clampY(box.cy + box.h / 2);
        return <String, dynamic>{
          'class': labels[box.label],
          'confidence': (box.score * 1000).round() / 1000,
          'x': round1((left + right) / 2),
          'y': round1((top + bottom) / 2),
          'width': round1(right - left),
          'height': round1(bottom - top),
        };
      }(),
  ];
}

class _Box {
  _Box(this.label, this.score, this.cx, this.cy, this.w, this.h);

  final int label;
  final double score;
  final double cx;
  final double cy;
  final double w;
  final double h;

  double iou(_Box other) {
    final left = math.max(cx - w / 2, other.cx - other.w / 2);
    final right = math.min(cx + w / 2, other.cx + other.w / 2);
    final top = math.max(cy - h / 2, other.cy - other.h / 2);
    final bottom = math.min(cy + h / 2, other.cy + other.h / 2);
    final overlap = math.max(0.0, right - left) * math.max(0.0, bottom - top);
    final union = w * h + other.w * other.h - overlap;
    return union <= 0 ? 0 : overlap / union;
  }
}
