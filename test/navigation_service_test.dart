import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navable/services/navigation_service.dart';

void main() {
  test('pin coordinates are the destination and origin stays live', () {
    final uri = const NavigationService().directionsUri(
      destination: 'Pinned location',
      coordinates: const LatLng(10.33, 123.87),
    );
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['destination'], '10.33,123.87');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['origin'], isNull);
    expect(uri.queryParameters['dir_action'], 'navigate');
  });

  test('address punctuation is preserved and transit opens directions', () {
    final uri = const NavigationService().directionsUri(
      destination: '  A & B, Cebu City  ',
      mode: TravelMode.transit,
    );
    expect(uri.queryParameters['destination'], 'A & B, Cebu City');
    expect(uri.queryParameters['travelmode'], 'transit');
    expect(uri.queryParameters['dir_action'], isNull);
  });

  test('empty destination is rejected', () {
    expect(
      () => const NavigationService().directionsUri(destination: ' '),
      throwsArgumentError,
    );
  });

  test('launcher success and failure are propagated', () async {
    final success = NavigationService(launcher: (_) async => true);
    final failure = NavigationService(launcher: (_) async => false);
    final exception = NavigationService(
      launcher: (_) async => throw Exception('no activity'),
    );
    expect(await success.open(destination: 'Cebu'), isTrue);
    expect(await failure.open(destination: 'Cebu'), isFalse);
    expect(await exception.open(destination: 'Cebu'), isFalse);
  });
}
