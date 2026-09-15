import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum TravelMode { walking, driving, transit }

typedef NavigationLauncher = Future<bool> Function(Uri uri);

class NavigationService {
  const NavigationService({this.launcher});

  final NavigationLauncher? launcher;

  Uri directionsUri({
    required String destination,
    LatLng? coordinates,
    TravelMode mode = TravelMode.walking,
  }) {
    final name = destination.trim();
    if (name.isEmpty && coordinates == null) {
      throw ArgumentError('A destination is required.');
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': coordinates == null
          ? name
          : '${coordinates.latitude},${coordinates.longitude}',
      'travelmode': mode.name,
      // Omitting origin lets Google Maps use the live device location.
      if (mode != TravelMode.transit) 'dir_action': 'navigate',
    });
  }

  Future<bool> open({
    required String destination,
    LatLng? coordinates,
    TravelMode mode = TravelMode.walking,
  }) async {
    final uri = directionsUri(
      destination: destination,
      coordinates: coordinates,
      mode: mode,
    );
    try {
      return await (launcher?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      return false;
    }
  }
}
