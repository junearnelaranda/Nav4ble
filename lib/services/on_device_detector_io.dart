import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'yolo_postprocess.dart';

/// Runs NavAble's YOLO11n model on the device. Produced by
/// `ai/train_yolo11n.ipynb`; drop both files into `assets/models/`.
abstract final class OnDeviceDetector {
  static const modelAsset = 'assets/models/navable_yolo11n.tflite';
  static const labelsAsset = 'assets/models/labels.txt';
  static const modelName = 'NavAble YOLO11n (on-device)';

  static Future<_LoadedModel?>? _model;

  /// `{image, detections, model}` for one photo, or `null` when no model is
  /// bundled or it can't run here (callers then use the online service).
  static Future<Map<String, dynamic>?> detect(Uint8List photo) async {
    final model = await (_model ??= _load());
    if (model == null) return null;
    final prepared = await compute(_prepareInput, (
      photo: photo,
      size: model.inputSize,
      channelsFirst: model.channelsFirst,
    ));
    if (prepared == null) return null;

    var output = Float32List(model.outputLength);
    await model.interpreter.run(prepared.input, output.buffer);
    if (model.anchorsFirst) output = _transpose(output, model.anchors);
    return {
      'image': {
        'width': prepared.letterbox.imageWidth,
        'height': prepared.letterbox.imageHeight,
      },
      'detections': decodeYoloOutput(
        output: output,
        anchors: model.anchors,
        labels: model.labels,
        letterbox: prepared.letterbox,
      ),
      'model': modelName,
    };
  }

  static Future<_LoadedModel?> _load() async {
    try {
      final labels = (await rootBundle.loadString(labelsAsset))
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      final interpreter = await Interpreter.fromAsset(modelAsset);
      // Converters differ in layout: input [1, s, s, 3] or [1, 3, s, s],
      // output [1, 4+classes, anchors] or [1, anchors, 4+classes].
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      final rows = 4 + labels.length;
      final channelsFirst = inputShape.length == 4 && inputShape[1] == 3;
      final size = channelsFirst ? inputShape[2] : inputShape[1];
      final anchorsFirst = outputShape.length == 3 && outputShape[2] == rows;
      if (inputShape.length != 4 ||
          inputShape[channelsFirst ? 3 : 2] != size ||
          inputShape[channelsFirst ? 1 : 3] != 3 ||
          outputShape.length != 3 ||
          (outputShape[1] != rows && !anchorsFirst)) {
        debugPrint(
          'On-device model ignored: input $inputShape, output $outputShape, '
          '${labels.length} labels.',
        );
        interpreter.close();
        return null;
      }
      return _LoadedModel(
        interpreter: await IsolateInterpreter.create(
          address: interpreter.address,
        ),
        labels: labels,
        inputSize: size,
        anchors: anchorsFirst ? outputShape[1] : outputShape[2],
        channelsFirst: channelsFirst,
        anchorsFirst: anchorsFirst,
      );
    } catch (error) {
      // No model bundled yet, or TFLite isn't available on this platform.
      debugPrint('On-device model unavailable: $error');
      return null;
    }
  }
}

class _LoadedModel {
  _LoadedModel({
    required this.interpreter,
    required this.labels,
    required this.inputSize,
    required this.anchors,
    required this.channelsFirst,
    required this.anchorsFirst,
  });

  final IsolateInterpreter interpreter;
  final List<String> labels;
  final int inputSize;
  final int anchors;
  final bool channelsFirst;
  final bool anchorsFirst;

  int get outputLength => (4 + labels.length) * anchors;
}

/// `[anchors, rows]` -> `[rows, anchors]`, the layout [decodeYoloOutput] reads.
Float32List _transpose(Float32List values, int anchors) {
  final rows = values.length ~/ anchors;
  final out = Float32List(values.length);
  for (var a = 0; a < anchors; a++) {
    for (var r = 0; r < rows; r++) {
      out[r * anchors + a] = values[a * rows + r];
    }
  }
  return out;
}

/// Decodes the photo, applies its camera rotation, letterboxes it onto a
/// gray square like YOLO training does, and returns float32 RGB in 0..1,
/// pixel by pixel (`[s, s, 3]`) or plane by plane (`[3, s, s]`).
/// Runs in a background isolate.
({Uint8List input, Letterbox letterbox})? _prepareInput(
  ({Uint8List photo, int size, bool channelsFirst}) request,
) {
  final decoded = img.decodeImage(request.photo);
  if (decoded == null) return null;
  final photo = img.bakeOrientation(decoded);
  final letterbox = Letterbox(
    inputSize: request.size,
    imageWidth: photo.width,
    imageHeight: photo.height,
  );
  final resized = img.copyResize(
    photo,
    width: letterbox.scaledWidth,
    height: letterbox.scaledHeight,
    interpolation: img.Interpolation.linear,
  );
  final canvas = img.Image(width: request.size, height: request.size);
  img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
  img.compositeImage(
    canvas,
    resized,
    dstX: letterbox.padX,
    dstY: letterbox.padY,
  );
  final rgb = canvas.getBytes(order: img.ChannelOrder.rgb);
  final input = Float32List(rgb.length);
  final pixels = rgb.length ~/ 3;
  for (var i = 0; i < rgb.length; i++) {
    final target = request.channelsFirst ? (i % 3) * pixels + i ~/ 3 : i;
    input[target] = rgb[i] / 255.0;
  }
  return (input: input.buffer.asUint8List(), letterbox: letterbox);
}
