import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navable/route_planner_api.dart';

void main() {
  test('reads the OpenStreetMap wheelchair tag', () {
    expect(wheelchairLabel('yes'), 'Wheelchair accessible');
    expect(wheelchairLabel('designated'), 'Wheelchair accessible');
    expect(wheelchairLabel('limited'), 'Partly wheelchair accessible');
    expect(wheelchairLabel('no'), isNull);
    expect(wheelchairLabel(null), isNull);
  });

  test('a result is accessible only when something is known', () {
    const place = PlaceSearchResult(
      name: 'Bo\'s Coffee',
      displayName: 'Ayala Center Cebu',
      point: LatLng(10.318, 123.905),
    );
    expect(place.isAccessible, isFalse);
    final marked = place.withAccessibility('Ramp, Elevator');
    expect(marked.isAccessible, isTrue);
    expect(marked.accessibility, 'Ramp, Elevator');
    expect(marked.name, place.name);
    expect(marked.point, place.point);
  });

  test('reads Photon suggestions, real places before land-use areas', () {
    const body = """
{"type":"FeatureCollection","features":[
 {"geometry":{"coordinates":[123.905,10.318]},
  "properties":{"name":"Ayala Center Cebu","osm_key":"landuse","city":"Cebu City"}},
 {"geometry":{"coordinates":[123.9049,10.3187]},
  "properties":{"name":"Ayala Center Cebu","osm_key":"shop",
   "street":"Cardinal Rosales Avenue","district":"Lahug","city":"Cebu City"}},
 {"geometry":{"coordinates":[123.9]},"properties":{"name":"Broken"}},
 {"geometry":{"coordinates":[123.9,10.3]},"properties":{}}
]}""";
    final results = RoutePlannerApi.parsePhotonResults(body);
    expect(results, hasLength(2));
    expect(
      results.first.displayName,
      'Cardinal Rosales Avenue, Lahug, Cebu City',
    );
    expect(results.first.point, const LatLng(10.3187, 123.9049));
    expect(results.last.displayName, 'Cebu City');
    expect(results.first.isAccessible, isFalse);
  });
}
