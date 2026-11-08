import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Profile pictures are stored in `user_profiles.profile_picture` as a small
/// JPEG data URL (about 20-40 KB), so they come back on every device the
/// user signs in on without a separate storage bucket.
abstract final class ProfilePicture {
  /// Width and height of the stored square picture, in pixels.
  static const size = 256;

  /// A [size] x [size] JPEG of [bytes] as a data URL, cropped to the centre
  /// and turned upright. Null when [bytes] isn't a readable image.
  /// Runs in the background so the app stays smooth.
  static Future<String?> encode(Uint8List bytes) => compute(encodeNow, bytes);

  @visibleForTesting
  static String? encodeNow(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final square = img.copyResizeCropSquare(
      img.bakeOrientation(decoded),
      size: size,
    );
    return 'data:image/jpeg;base64,'
        '${base64Encode(img.encodeJpg(square, quality: 82))}';
  }

  /// The image bytes in a stored data URL, or null when there is none or it
  /// is unreadable.
  static Uint8List? decode(String? stored) {
    if (stored == null || !stored.startsWith('data:image/')) return null;
    final comma = stored.indexOf(',');
    if (comma == -1) return null;
    try {
      final bytes = base64Decode(stored.substring(comma + 1));
      return bytes.isEmpty ? null : bytes;
    } on FormatException {
      return null;
    }
  }
}
