import 'dart:typed_data';

abstract final class OnDeviceDetector {
  /// Web builds can't run TFLite, so scanning uses the online service.
  static Future<Map<String, dynamic>?> detect(Uint8List photo) async => null;
}
