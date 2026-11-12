import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'locations_api.dart';
import 'place_categories.dart';

class RoutePlannerException implements Exception {
  const RoutePlannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum TravelMode { walking, car, motorcycle }

extension TravelModeLabel on TravelMode {
  String get label => switch (this) {
    TravelMode.walking => 'Walking',
    TravelMode.car => 'Car',
    TravelMode.motorcycle => 'Motorcycle',
  };
}

class PlannedRoute {
  const PlannedRoute({
    required this.mode,
    required this.destinationName,
    required this.origin,
    required this.destination,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.instructions,
    this.savedLocation,
  });

  final TravelMode mode;
  final String destinationName;
  final LatLng origin;
  final LatLng destination;
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<String> instructions;
  final AccessibleLocation? savedLocation;

  String get summary =>
      '${mode.label} route to $destinationName · ${_formatDistance(distanceMeters)} · ${_formatDuration(durationSeconds)}';

  /// Short text for the route card on the map: just the distance.
  String get distanceLabel => 'Distance: ${_formatDistance(distanceMeters)}';

  static String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  static String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }
}

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.displayName,
    required this.point,
    this.accessibility,
    this.category,
  });

  final String name;
  final String displayName;
  final LatLng point;

  /// What kind of place it is ("Shopping mall"), when known; picks the
  /// pin's icon.
  final String? category;

  /// What's known about its accessibility (NavAble features, or the
  /// OpenStreetMap wheelchair tag); null when nothing is known yet.
  final String? accessibility;

  bool get isAccessible => accessibility != null;

  PlaceSearchResult withAccessibility(String? value) => PlaceSearchResult(
    name: name,
    displayName: displayName,
    point: point,
    accessibility: value,
    category: category,
  );
}

/// OpenStreetMap's wheelchair tag as a short label; null when unknown or "no".
String? wheelchairLabel(Object? tag) => switch (tag) {
  'yes' || 'designated' => 'Wheelchair accessible',
  'limited' => 'Partly wheelchair accessible',
  _ => null,
};

class RoutePlannerApi {
  RoutePlannerApi._();

  static const _nominatimEndpoint =
      'https://nominatim.openstreetmap.org/search';
  static const _overpassEndpoint = 'https://overpass-api.de/api/interpreter';
  static final Map<String, List<PlaceSearchResult>> _categoryCache = {};

  /// Every place of [category] within [radiusMeters] of [near] (at most
  /// [limit]), from OpenStreetMap through the Overpass API. Used when a
  /// search is just a type of place ("mall"), so all of them show as pins.
  static Future<List<PlaceSearchResult>> categoryPlaces(
    PlaceCategory category, {
    required LatLng near,
    int radiusMeters = 5000,
    int limit = 80,
  }) async {
    final key =
        '${category.key}:${near.latitude.toStringAsFixed(2)},${near.longitude.toStringAsFixed(2)}:$radiusMeters';
    final cached = _categoryCache[key];
    if (cached != null) return cached;
    final [tagKey, tagValue] = category.osmTag.split('=');
    final query =
        '[out:json][timeout:25];'
        'nwr["$tagKey"="$tagValue"](around:$radiusMeters,${near.latitude},${near.longitude});'
        'out center tags $limit;';
    try {
      final response = await http
          .post(
            Uri.parse(_overpassEndpoint),
            headers: const {'User-Agent': _userAgent},
            body: {'data': query},
          )
          // Public servers are sometimes down; the caller falls back to the
          // regular search, so don't keep people waiting long.
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RoutePlannerException(
          'Place search returned HTTP ${response.statusCode}. Try again later.',
        );
      }
      final results = parseOverpass(
        response.body,
        categoryLabel: category.label,
      );
      _categoryCache[key] = results;
      return results;
    } on RoutePlannerException {
      rethrow;
    } on Exception catch (error) {
      throw RoutePlannerException('Could not reach place search: $error');
    }
  }

  /// Reads an Overpass JSON answer: named places only, at their point (or
  /// the centre of a building or area), with the OpenStreetMap wheelchair
  /// tag as their accessibility.
  static List<PlaceSearchResult> parseOverpass(
    String body, {
    required String categoryLabel,
  }) {
    final decoded = jsonDecode(body);
    final elements = decoded is Map ? decoded['elements'] : null;
    if (elements is! List) return const [];
    final results = <PlaceSearchResult>[];
    for (final element in elements.whereType<Map>()) {
      final tags = element['tags'];
      if (tags is! Map) continue;
      final name = tags['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final center = element['center'];
      final lat =
          ((center is Map ? center['lat'] : null) ?? element['lat']) as num?;
      final lon =
          ((center is Map ? center['lon'] : null) ?? element['lon']) as num?;
      if (lat == null || lon == null) continue;
      final address = [tags['addr:street'], tags['addr:city']]
          .whereType<Object>()
          .map((part) => part.toString().trim())
          .where((part) => part.isNotEmpty)
          .join(', ');
      results.add(
        PlaceSearchResult(
          name: name,
          displayName: address.isEmpty ? categoryLabel : address,
          point: LatLng(lat.toDouble(), lon.toDouble()),
          accessibility: wheelchairLabel(tags['wheelchair']),
          category: categoryLabel,
        ),
      );
    }
    return List.unmodifiable(results);
  }

  static const _routingEndpoint = 'https://routing.openstreetmap.de';
  static const _userAgent = 'NavAble/1.0 (Flutter accessibility map app)';
  static final Map<String, ({String name, LatLng point})> _placeCache = {};
  static final Map<String, List<PlaceSearchResult>> _searchCache = {};
  static DateTime? _lastPublicRequest;

  static const _photonEndpoint = 'https://photon.komoot.io/api/';
  static final Map<String, List<PlaceSearchResult>> _suggestCache = {};

  /// Category words mapped to OpenStreetMap tags, so typing "mall" suggests
  /// malls rather than streets that happen to be named "Mall...".
  static const _categoryTags = {
    'mall': 'shop:mall',
    'malls': 'shop:mall',
    'cafe': 'amenity:cafe',
    'cafes': 'amenity:cafe',
    'coffee': 'amenity:cafe',
    'restaurant': 'amenity:restaurant',
    'restaurants': 'amenity:restaurant',
    'hospital': 'amenity:hospital',
    'hospitals': 'amenity:hospital',
    'pharmacy': 'amenity:pharmacy',
    'pharmacies': 'amenity:pharmacy',
    'bank': 'amenity:bank',
    'banks': 'amenity:bank',
    'school': 'amenity:school',
    'schools': 'amenity:school',
    'hotel': 'tourism:hotel',
    'hotels': 'tourism:hotel',
    'church': 'amenity:place_of_worship',
    'churches': 'amenity:place_of_worship',
    'supermarket': 'shop:supermarket',
    'supermarkets': 'shop:supermarket',
  };

  /// Suggestions while the user types, within [reach] degrees of [near]
  /// (0.1 is about 11 km). Uses Photon, OpenStreetMap search built for
  /// search-as-you-type; Nominatim's usage policy forbids autocomplete.
  static Future<List<PlaceSearchResult>> suggestPlaces({
    required String query,
    required LatLng near,
    double reach = 0.1,
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.length < 2) return const [];
    final key =
        '$normalizedQuery:${near.latitude.toStringAsFixed(2)},${near.longitude.toStringAsFixed(2)}:$reach';
    final cached = _suggestCache[key];
    if (cached != null) return cached;

    final tag = _categoryTags[normalizedQuery];
    final uri = Uri.parse(_photonEndpoint).replace(
      queryParameters: {
        'q': query.trim(),
        'lat': '${near.latitude}',
        'lon': '${near.longitude}',
        'bbox':
            '${near.longitude - reach},${near.latitude - reach},${near.longitude + reach},${near.latitude + reach}',
        'limit': '10',
        'lang': 'en',
        'osm_tag': ?tag,
      },
    );
    try {
      final response = await http
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RoutePlannerException(
          'Place suggestions returned HTTP ${response.statusCode}.',
        );
      }
      final results = parsePhotonResults(response.body);
      _suggestCache[key] = results;
      return results;
    } on RoutePlannerException {
      rethrow;
    } on Exception catch (error) {
      throw RoutePlannerException('Could not load place suggestions: $error');
    }
  }

  /// Reads a Photon GeoJSON response. Land-use areas go last, as in
  /// [searchPlaces], so the real place wins when names repeat.
  static List<PlaceSearchResult> parsePhotonResults(String body) {
    final decoded = jsonDecode(body);
    final features = decoded is Map ? decoded['features'] : null;
    if (features is! List) return const [];
    final results = <PlaceSearchResult>[];
    final areaResults = <PlaceSearchResult>[];
    for (final feature in features.whereType<Map>()) {
      final properties = feature['properties'];
      final coordinates = (feature['geometry'] as Map?)?['coordinates'];
      if (properties is! Map ||
          coordinates is! List ||
          coordinates.length < 2) {
        continue;
      }
      final longitude = (coordinates[0] as num?)?.toDouble();
      final latitude = (coordinates[1] as num?)?.toDouble();
      final name = properties['name']?.toString().trim() ?? '';
      if (latitude == null || longitude == null || name.isEmpty) continue;
      final street = [
        properties['housenumber'],
        properties['street'],
      ].whereType<Object>().join(' ');
      final address = <String>[
        if (street.isNotEmpty) street,
        for (final part in [
          properties['district'] ?? properties['locality'],
          properties['city'],
        ])
          if (part != null && part.toString().isNotEmpty) part.toString(),
      ].join(', ');
      final key = properties['osm_key'];
      (key == 'landuse' || key == 'boundary' ? areaResults : results).add(
        PlaceSearchResult(
          name: name,
          displayName: address.isEmpty ? name : address,
          point: LatLng(latitude, longitude),
        ),
      );
    }
    return List.unmodifiable([...results, ...areaResults]);
  }

  /// Searches only when the user submits a query; Nominatim does not permit
  /// client-side autocomplete against its public service.
  ///
  /// [reach] is the search box's half-size in degrees (0.05 is about
  /// 5 km); [bounded] drops results outside it instead of just preferring it.
  static Future<List<PlaceSearchResult>> searchPlaces({
    required String query,
    required LatLng near,
    double reach = 0.2,
    bool bounded = false,
    int limit = 15,
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];
    final key =
        '$normalizedQuery:${near.latitude.toStringAsFixed(2)},${near.longitude.toStringAsFixed(2)}:$reach:$bounded:$limit';
    final cached = _searchCache[key];
    if (cached != null) return cached;

    final uri = Uri.parse(_nominatimEndpoint).replace(
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': '$limit',
        'addressdetails': '1',
        'extratags': '1', // includes the wheelchair tag
        'viewbox':
            '${near.longitude - reach},${near.latitude + reach},${near.longitude + reach},${near.latitude - reach}',
        if (bounded) 'bounded': '1',
      },
    );
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const RoutePlannerException(
        'The place search returned invalid results.',
      );
    }
    final results = <PlaceSearchResult>[];
    // Land-use areas and boundaries often share the name of the real place
    // (e.g. a mall's whole lot), but their center can be far from it. Listing
    // them last means "first result" and duplicate-name filtering keep the place.
    final areaResults = <PlaceSearchResult>[];
    for (final item in decoded.whereType<Map>()) {
      final place = Map<String, dynamic>.from(item);
      final latitude = double.tryParse(place['lat']?.toString() ?? '');
      final longitude = double.tryParse(place['lon']?.toString() ?? '');
      if (latitude == null || longitude == null) continue;
      final displayName = place['display_name']?.toString() ?? query;
      final name = place['name']?.toString().trim();
      final category = place['category']?.toString();
      (category == 'landuse' || category == 'boundary' ? areaResults : results)
          .add(
            PlaceSearchResult(
              name: name == null || name.isEmpty
                  ? displayName.split(',').first
                  : name,
              displayName: displayName,
              point: LatLng(latitude, longitude),
              accessibility: wheelchairLabel(
                (place['extratags'] as Map?)?['wheelchair'],
              ),
              // OpenStreetMap's place type ("mall", "hospital") for the icon.
              category: place['type']?.toString().replaceAll('_', ' '),
            ),
          );
    }
    results.addAll(areaResults);
    _searchCache[key] = List.unmodifiable(results);
    return _searchCache[key]!;
  }

  static Future<PlannedRoute> planRoute({
    required String query,
    required LatLng origin,
    required List<AccessibleLocation> savedLocations,
    required TravelMode mode,
    PlaceSearchResult? selectedPlace,
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      throw const RoutePlannerException(
        'Enter a destination to start routing.',
      );
    }

    final savedLocation = _matchSavedLocation(normalizedQuery, savedLocations);
    final destination = savedLocation == null
        ? selectedPlace != null &&
                  _normalize(selectedPlace.name) == normalizedQuery
              ? (name: selectedPlace.name, point: selectedPlace.point)
              : await _searchPlace(query, origin)
        : (
            name: savedLocation.name,
            point: LatLng(savedLocation.latitude, savedLocation.longitude),
          );

    final coordinates =
        '${origin.longitude},${origin.latitude};${destination.point.longitude},${destination.point.latitude}';
    // FOSSGIS provides foot, bicycle, and car profiles, but no motorcycle
    // profile. Motorcycle routes therefore use the car road network.
    final profile = switch (mode) {
      TravelMode.walking => 'routed-foot',
      TravelMode.car || TravelMode.motorcycle => 'routed-car',
    };
    final uri =
        Uri.parse(
          '$_routingEndpoint/$profile/route/v1/driving/$coordinates',
        ).replace(
          queryParameters: const {
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'true',
          },
        );
    final response = await _get(uri);
    final body = _decodeObject(
      response,
      'Could not calculate a ${mode.label.toLowerCase()} route.',
    );
    if (body['code'] != 'Ok') {
      throw RoutePlannerException(
        body['message'] as String? ??
            'No ${mode.label.toLowerCase()} route was found. Try another destination.',
      );
    }

    final routes = body['routes'];
    final route = routes is List && routes.isNotEmpty && routes.first is Map
        ? Map<String, dynamic>.from(routes.first as Map)
        : null;
    if (route == null) {
      throw const RoutePlannerException(
        'The routing service returned no route.',
      );
    }

    final geometry = route['geometry'];
    final rawCoordinates = geometry is Map ? geometry['coordinates'] : null;
    final points = rawCoordinates is List
        ? rawCoordinates
              .whereType<List>()
              .where((point) => point.length >= 2)
              .map(
                (point) => LatLng(
                  (point[1] as num).toDouble(),
                  (point[0] as num).toDouble(),
                ),
              )
              .toList(growable: false)
        : const <LatLng>[];
    if (points.length < 2) {
      throw const RoutePlannerException(
        'The routing service returned an invalid route geometry.',
      );
    }

    final legs = route['legs'];
    final instructions = <String>[];
    if (legs is List) {
      for (final leg in legs.whereType<Map>()) {
        final steps = leg['steps'];
        if (steps is! List) continue;
        for (final step in steps.whereType<Map>()) {
          final instruction = _instruction(step, mode);
          if (instruction != null) instructions.add(instruction);
        }
      }
    }

    return PlannedRoute(
      mode: mode,
      destinationName: destination.name,
      origin: origin,
      destination: destination.point,
      points: points,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
      instructions: instructions,
      savedLocation: savedLocation,
    );
  }

  static AccessibleLocation? _matchSavedLocation(
    String query,
    List<AccessibleLocation> locations,
  ) {
    for (final location in locations) {
      if (_normalize(location.name) == query) return location;
    }
    for (final location in locations) {
      final name = _normalize(location.name);
      final address = _normalize(location.address);
      if (name.contains(query) ||
          query.contains(name) ||
          address.contains(query)) {
        return location;
      }
    }
    return null;
  }

  static Future<({String name, LatLng point})> _searchPlace(
    String query,
    LatLng origin,
  ) async {
    final key =
        '${_normalize(query)}:${origin.latitude.toStringAsFixed(2)},${origin.longitude.toStringAsFixed(2)}';
    final cached = _placeCache[key];
    if (cached != null) return cached;

    final searchedPlaces = await searchPlaces(query: query, near: origin);
    if (searchedPlaces.isNotEmpty) {
      final first = searchedPlaces.first;
      final result = (name: first.name, point: first.point);
      _placeCache[key] = result;
      return result;
    }

    throw const RoutePlannerException(
      'No matching place was found. Check the spelling or choose a saved location.',
    );
  }

  static Future<http.Response> _get(Uri uri) async {
    final lastRequest = _lastPublicRequest;
    if (lastRequest != null) {
      final wait =
          const Duration(seconds: 1) - DateTime.now().difference(lastRequest);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastPublicRequest = DateTime.now();

    try {
      final response = await http
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RoutePlannerException(
          'Map search/routing service returned HTTP ${response.statusCode}. Try again later.',
        );
      }
      return response;
    } on RoutePlannerException {
      rethrow;
    } on Exception catch (error) {
      throw RoutePlannerException(
        'Could not reach the map search/routing service: $error',
      );
    }
  }

  static Map<String, dynamic> _decodeObject(
    http.Response response,
    String fallback,
  ) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw RoutePlannerException(fallback);
    }
    throw RoutePlannerException(fallback);
  }

  static String? _instruction(Map step, TravelMode mode) {
    final maneuver = step['maneuver'];
    if (maneuver is! Map) return null;
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String?;
    final name = (step['name'] as String?)?.trim();
    final road = name == null || name.isEmpty ? '' : ' onto $name';
    switch (type) {
      case 'depart':
        final verb = switch (mode) {
          TravelMode.walking => 'walking',
          TravelMode.car => 'driving',
          TravelMode.motorcycle => 'riding',
        };
        return 'Start $verb$road.';
      case 'arrive':
        return 'Arrive at your destination.';
      case 'turn':
      case 'end of road':
        return 'Turn ${modifier ?? 'ahead'}$road.';
      case 'continue':
        return 'Continue${modifier == null ? '' : ' $modifier'}$road.';
      case 'new name':
        return 'Continue$road.';
      case 'roundabout':
      case 'rotary':
        return 'Enter the roundabout and continue$road.';
      case 'fork':
        return 'Keep ${modifier ?? 'straight'}$road.';
      default:
        return name == null || name.isEmpty ? null : 'Continue on $name.';
    }
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
