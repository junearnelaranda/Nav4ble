import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:navable/services/yolo_postprocess.dart';

/// Builds a `[1, 4 + classes, anchors]` tensor from per-anchor rows of
/// `[cx, cy, w, h, score per class...]`.
Float32List tensor(List<List<double>> anchors) {
  final rows = anchors.first.length;
  final out = Float32List(rows * anchors.length);
  for (var a = 0; a < anchors.length; a++) {
    for (var r = 0; r < rows; r++) {
      out[r * anchors.length + a] = anchors[a][r];
    }
  }
  return out;
}

void main() {
  // A 1280x720 photo letterboxed into 640x640: scale 0.5, 140 px bars.
  const letterbox = Letterbox(
    inputSize: 640,
    imageWidth: 1280,
    imageHeight: 720,
  );
  const labels = ['ramp', 'elevator'];

  test('letterbox geometry matches YOLO', () {
    expect(letterbox.scale, 0.5);
    expect(letterbox.scaledWidth, 640);
    expect(letterbox.scaledHeight, 360);
    expect(letterbox.padX, 0);
    expect(letterbox.padY, 140);
  });

  test('maps normalized boxes back to photo pixels and removes overlaps', () {
    final detections = decodeYoloOutput(
      anchors: 4,
      labels: labels,
      letterbox: letterbox,
      output: tensor([
        [0.5, 0.5, 0.25, 0.25, 0.9, 0.0], // ramp, kept
        [0.51, 0.5, 0.25, 0.25, 0.8, 0.0], // same ramp, lower score: dropped
        [0.5, 0.5, 0.25, 0.25, 0.0, 0.7], // elevator at same spot: kept
        [0.2, 0.3, 0.1, 0.1, 0.1, 0.05], // below threshold: dropped
      ]),
    );

    expect(detections, hasLength(2));
    expect(detections[0], {
      'class': 'ramp',
      'confidence': 0.9,
      'x': 640.0,
      'y': 360.0,
      'width': 320.0,
      'height': 320.0,
    });
    expect(detections[1]['class'], 'elevator');
    expect(detections[1]['confidence'], 0.7);
  });

  test('accepts pixel boxes and clips them to the photo', () {
    final detections = decodeYoloOutput(
      anchors: 1,
      labels: labels,
      letterbox: letterbox,
      // Box near the left edge in input pixels; half of it is off the photo.
      output: tensor([
        [10, 320, 40, 40, 0.0, 0.6],
      ]),
    );

    expect(detections.single['class'], 'elevator');
    expect(detections.single['x'], 30.0); // spans 0..60 after clipping
    expect(detections.single['width'], 60.0);
    expect(detections.single['y'], 360.0);
  });

  test('rejects an output that does not match the labels', () {
    expect(
      () => decodeYoloOutput(
        anchors: 2,
        labels: labels,
        letterbox: letterbox,
        output: Float32List(10),
      ),
      throwsArgumentError,
    );
  });
}
