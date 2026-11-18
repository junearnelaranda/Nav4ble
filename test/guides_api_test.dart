import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navable/guides_api.dart';

Map<String, Object?> row({
  String id = 'g1',
  String feature = 'Elevator',
  String whereText = 'Beside the supermarket',
  String? floor = 'Ground floor',
  String? landmark = 'Across the pharmacy',
  Object? latitude,
  Object? longitude,
  String featurePhoto = 'https://example.com/feature.jpg',
  String nearbyPhoto = 'https://example.com/nearby.jpg',
}) => {
  'guide_id': id,
  'feature_id': 'f1',
  'feature_name': feature,
  'where_text': whereText,
  'floor': floor,
  'landmark': landmark,
  'latitude': latitude,
  'longitude': longitude,
  'feature_photo_url': featurePhoto,
  'nearby_photo_url': nearbyPhoto,
};

FeatureGuide guide({String id = 'g1', String feature = 'Elevator'}) =>
    FeatureGuide.fromRow(row(id: id, feature: feature))!;

String? check({
  String whereText = 'Beside the supermarket',
  String floor = '',
  String landmark = '',
  bool hasFeaturePhoto = true,
  bool hasNearbyPhoto = true,
  LatLng? pin,
}) => GuidesApi.validate(
  whereText: whereText,
  floor: floor,
  landmark: landmark,
  hasFeaturePhoto: hasFeaturePhoto,
  hasNearbyPhoto: hasNearbyPhoto,
  pin: pin,
  place: const LatLng(10.3, 123.9),
);

const all = [
  GuideFeature(id: '1', name: 'Wheelchair ramp'),
  GuideFeature(id: '2', name: 'Elevator'),
  GuideFeature(id: '3', name: 'Accessible entrance'),
  GuideFeature(id: '4', name: 'Accessible restroom'),
  GuideFeature(id: '5', name: 'Tactile paving'),
  GuideFeature(id: '6', name: 'Accessible parking'),
  GuideFeature(id: '7', name: 'Wheelchair seating'),
  GuideFeature(id: '8', name: 'Braille signage'),
];

void main() {
  group('FeatureGuide.fromRow', () {
    test('reads every field', () {
      final guide = FeatureGuide.fromRow(
        row(latitude: 10.29, longitude: 123.88),
      )!;
      expect(guide.id, 'g1');
      expect(guide.featureId, 'f1');
      expect(guide.featureName, 'Elevator');
      expect(guide.whereText, 'Beside the supermarket');
      expect(guide.floor, 'Ground floor');
      expect(guide.landmark, 'Across the pharmacy');
      expect(guide.hasPin, isTrue);
      expect(guide.latitude, 10.29);
      expect(guide.longitude, 123.88);
    });

    test('treats a bad pin as no pin', () {
      expect(
        FeatureGuide.fromRow(row(latitude: 0, longitude: 0))!.hasPin,
        isFalse,
      );
      expect(
        FeatureGuide.fromRow(row(latitude: 95, longitude: 123.88))!.hasPin,
        isFalse,
      );
      expect(FeatureGuide.fromRow(row())!.hasPin, isFalse);
    });

    test('empties optional text that is blank', () {
      final guide = FeatureGuide.fromRow(row(floor: ' ', landmark: null))!;
      expect(guide.floor, isNull);
      expect(guide.landmark, isNull);
    });

    test('rejects rows missing text or secure photos', () {
      expect(FeatureGuide.fromRow(row(id: '')), isNull);
      expect(FeatureGuide.fromRow(row(whereText: ' ')), isNull);
      expect(
        FeatureGuide.fromRow(row(nearbyPhoto: 'http://not-secure/x.jpg')),
        isNull,
      );
      expect(FeatureGuide.fromRow(row(featurePhoto: '')), isNull);
    });
  });

  group('guidesByFeature', () {
    test('ignores capitals and spaces in feature names', () {
      final map = guidesByFeature([guide(feature: 'Accessible Restroom')]);
      expect(map[featureKey(' accessible restroom ')], hasLength(1));
    });

    test('keeps several spots of one feature together in order', () {
      final map = guidesByFeature([
        guide(id: 'a'),
        guide(id: 'b', feature: 'Parking'),
        guide(id: 'c'),
      ]);
      expect(map[featureKey('Elevator')]!.map((g) => g.id), ['a', 'c']);
      expect(map[featureKey('Parking')], hasLength(1));
    });
  });

  group('GuidesApi.validate', () {
    test('accepts a complete guide', () => expect(check(), isNull));

    test('needs the written location', () {
      expect(check(whereText: ' '), 'Tell people where to find it.');
    });

    test('limits the text fields', () {
      expect(check(whereText: 'a' * 200), isNull);
      expect(check(whereText: 'a' * 201), isNotNull);
      expect(check(floor: 'a' * 40), isNull);
      expect(check(floor: 'a' * 41), isNotNull);
      expect(check(landmark: 'a' * 120), isNull);
      expect(check(landmark: 'a' * 121), isNotNull);
    });

    test('needs both photos', () {
      expect(check(hasFeaturePhoto: false), 'Add a photo of the feature.');
      expect(check(hasNearbyPhoto: false), 'Add a photo of what is nearby.');
    });

    test('limits the pin to 500 m from the place', () {
      expect(check(pin: const LatLng(10.3000, 123.9000)), isNull);
      expect(check(pin: const LatLng(10.3040, 123.9000)), isNull); // ~445 m
      expect(
        check(pin: const LatLng(10.3060, 123.9000)), // ~667 m
        'Pin a spot within 500 m of this place.',
      );
    });
  });

  group('GuidesApi.photoProblem', () {
    test('accepts a photo at exactly 700 KiB', () {
      expect(GuidesApi.photoProblem(Uint8List(700 * 1024)), isNull);
    });

    test('rejects a photo over 700 KiB', () {
      expect(
        GuidesApi.photoProblem(Uint8List(700 * 1024 + 1)),
        'This photo is over 700 KiB. Choose a smaller photo.',
      );
    });
  });

  group('featureForDetection', () {
    test('maps AI labels to features', () {
      expect(featureForDetection('ramp', all)?.name, 'Wheelchair ramp');
      expect(featureForDetection('Lift', all)?.name, 'Elevator');
      expect(featureForDetection('door', all)?.name, 'Accessible entrance');
      expect(featureForDetection('Toilet', all)?.name, 'Accessible restroom');
      expect(
        featureForDetection('comfort room', all)?.name,
        'Accessible restroom',
      );
      expect(
        featureForDetection('tactile_paving', all)?.name,
        'Tactile paving',
      );
      expect(
        featureForDetection('PWD parking', all)?.name,
        'Accessible parking',
      );
      expect(featureForDetection('seat', all)?.name, 'Wheelchair seating');
      expect(featureForDetection('braille', all)?.name, 'Braille signage');
    });

    test('returns null when nothing fits', () {
      expect(featureForDetection('stairs', all), isNull);
      expect(featureForDetection('ramp', const []), isNull);
    });
  });
}
