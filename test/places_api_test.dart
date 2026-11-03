import 'package:flutter_test/flutter_test.dart';
import 'package:navable/locations_api.dart';
import 'package:navable/places_api.dart';
import 'package:navable/reports_api.dart';

void main() {
  test('reads a Google place, including its wheelchair facts', () {
    final place = GooglePlace.fromJson({
      'id': 'ChIJ123',
      'name': 'Figaro Coffee - Ayala Center Cebu',
      'address': '2nd Level The Terraces, Ayala Center Cebu',
      'shortAddress': 'The Terraces, Ayala Center Cebu',
      'latitude': 10.3181,
      'longitude': 123.905,
      'rating': 4.3,
      'ratingCount': 706,
      'type': 'Cafe',
      'openNow': true,
      'accessibility': {
        'wheelchairEntrance': true,
        'wheelchairRestroom': false,
        'wheelchairParking': null,
        'wheelchairSeating': true,
      },
      'photo': 'places/ChIJ123/photos/abc',
      'photoAttribution': 'Juan Dela Cruz',
    });

    expect(place.name, 'Figaro Coffee - Ayala Center Cebu');
    expect(place.rating, 4.3);
    expect(place.ratingCount, 706);
    expect(place.openNow, isTrue);
    expect(place.accessibilityTags, [
      'Accessible entrance',
      'Wheelchair seating',
    ]);
    expect(place.photo, 'places/ChIJ123/photos/abc');
  });

  test('tolerates missing optional fields', () {
    final place = GooglePlace.fromJson({'id': 'x', 'name': 'Somewhere'});
    expect(place.latitude, isNull);
    expect(place.rating, isNull);
    expect(place.ratingCount, 0);
    expect(place.accessibilityTags, isEmpty);
    expect(place.photo, isNull);
  });

  test('distanceKm matches a known short distance', () {
    // Ayala Center Cebu to SM City Cebu is roughly 1.5 km.
    final km = PlacesApi.distanceKm(10.3181, 123.9050, 10.3115, 123.9180);
    expect(km, closeTo(1.6, 0.2));
    expect(PlacesApi.distanceKm(10, 123, 10, 123), 0);
  });

  test('a suggested place keeps its Google place id', () {
    final row = ReportsApi.suggestedPlaceRow(
      id: 'p',
      name: 'Figaro Coffee',
      coordinates: '10.3181, 123.905',
      googlePlaceId: 'ChIJ123',
    );
    expect(row['google_place_id'], 'ChIJ123');
    expect(
      ReportsApi.suggestedPlaceRow(
        id: 'p',
        name: 'x',
        coordinates: '10, 123',
      ).containsKey('google_place_id'),
      isFalse,
    );
  });

  group('matchNavAblePlace', () {
    const ayala = AccessibleLocation(
      id: 'ayala',
      name: 'Ayala Center Cebu',
      address: 'Cebu Business Park',
      latitude: 10.3181,
      longitude: 123.9050,
      features: [],
    );
    GooglePlace google(
      String name, {
      double lat = 10.3185,
      double lng = 123.9052,
    }) => GooglePlace(
      id: 'g-$name',
      name: name,
      address: '',
      shortAddress: '',
      latitude: lat,
      longitude: lng,
    );

    test('matches the same place nearby', () {
      expect(matchNavAblePlace(google('Ayala Center Cebu'), [ayala]), ayala);
    });

    test('a shop inside is not the mall', () {
      expect(
        matchNavAblePlace(google("Bo's Coffee Ayala Center Cebu"), [ayala]),
        isNull,
      );
    });

    test('same name far away is not a match', () {
      expect(
        matchNavAblePlace(google('Ayala Center Cebu', lat: 10.35), [ayala]),
        isNull,
      );
    });

    test('a place already linked to Google is left alone', () {
      const linked = AccessibleLocation(
        id: 'ayala',
        name: 'Ayala Center Cebu',
        address: '',
        latitude: 10.3181,
        longitude: 123.9050,
        features: [],
        googlePlaceId: 'other',
      );
      expect(matchNavAblePlace(google('Ayala Center Cebu'), [linked]), isNull);
    });
  });
}
