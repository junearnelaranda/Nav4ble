import 'package:url_launcher/url_launcher.dart';

/// Hands a destination picked in NavAble over to Google Maps, which then
/// handles directions, route choices, travel modes and turn-by-turn.
abstract final class GoogleMapsLauncher {
  /// Google Maps directions link with the given coordinates as destination,
  /// or `null` when the coordinates are missing or not a real map point.
  ///
  /// Uses the cross-platform Maps URL, so it opens the Google Maps app when
  /// installed and the website otherwise. Starts in driving mode; the user
  /// can switch modes in Google Maps.
  static Uri? directionsUri({
    required double? latitude,
    required double? longitude,
  }) {
    if (!isValidCoordinate(latitude: latitude, longitude: longitude)) {
      return null;
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
    });
  }

  static bool isValidCoordinate({
    required double? latitude,
    required double? longitude,
  }) {
    if (latitude == null || longitude == null) return false;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    // 0,0 is open ocean and almost always means the coordinates were unset.
    return latitude != 0 || longitude != 0;
  }

  /// Opens Google Maps with directions to the destination.
  /// Returns `false` instead of throwing when it cannot be opened.
  static Future<bool> openDirections({
    required double? latitude,
    required double? longitude,
  }) async {
    final uri = directionsUri(latitude: latitude, longitude: longitude);
    if (uri == null) return false;
    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (_) {
        // Try the next launch mode.
      }
    }
    return false;
  }
}
