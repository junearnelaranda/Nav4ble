import 'package:flutter_test/flutter_test.dart';
import 'package:navable/services/google_maps_launcher.dart';

void main() {
  group('GoogleMapsLauncher.directionsUri', () {
    test('uses the selected coordinates as the destination', () {
      final uri = GoogleMapsLauncher.directionsUri(
        latitude: 10.3181,
        longitude: 123.9050,
      );

      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '10.3181,123.905');
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('changes when a different place is selected', () {
      final first = GoogleMapsLauncher.directionsUri(
        latitude: 10.3181,
        longitude: 123.9050,
      );
      final second = GoogleMapsLauncher.directionsUri(
        latitude: 10.3115,
        longitude: 123.9180,
      );

      expect(second!.queryParameters['destination'], '10.3115,123.918');
      expect(second, isNot(first));
    });

    test('rejects missing or invalid coordinates', () {
      const invalid = <(double?, double?)>[
        (null, 123.9),
        (10.3, null),
        (null, null),
        (double.nan, 123.9),
        (10.3, double.infinity),
        (91, 123.9),
        (-91, 123.9),
        (10.3, 181),
        (10.3, -181),
        (0, 0),
      ];
      for (final (latitude, longitude) in invalid) {
        expect(
          GoogleMapsLauncher.directionsUri(
            latitude: latitude,
            longitude: longitude,
          ),
          isNull,
          reason: '($latitude, $longitude) should be rejected',
        );
      }
    });

    test('openDirections returns false instead of throwing', () async {
      expect(
        await GoogleMapsLauncher.openDirections(
          latitude: null,
          longitude: 123.9,
        ),
        isFalse,
      );
    });
  });
}
