import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'locations_api.dart';

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
  });

  final String name;
  final String displayName;
  final LatLng point;
}

class RoutePlannerApi {
  RoutePlannerApi._();

  static const _nominatimEndpoint =
      'https://nominatim.openstreetmap.org/search';
  static const _routingEndpoint = 'https://routing.openstreetmap.de';
  static const _userAgent = 'NavAble/1.0 (Flutter accessibility map app)';
  static final Map<String, ({String name, LatLng point})> _placeCache = {};
  static final Map<String, List<PlaceSearchResult>> _searchCache = {};
  static DateTime? _lastPublicRequest;

  /// Searches only when the user submits a query; Nominatim does not permit
  /// client-side autocomplete against its public service.
  static Future<List<PlaceSearchResult>> searchPlaces({
    required String query,
    required LatLng near,
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];
    final key =
        '$normalizedQuery:${near.latitude.toStringAsFixed(2)},${near.longitude.toStringAsFixed(2)}';
    final cached = _searchCache[key];
    if (cached != null) return cached;

    final uri = Uri.parse(_nominatimEndpoint).replace(
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': '5',
        'addressdetails': '1',
        'viewbox':
            '${near.longitude - 0.2},${near.latitude + 0.2},${near.longitude + 0.2},${near.latitude - 0.2}',
      },
    );
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const RoutePlannerException('The place search returned invalid results.');
    }
    final results = <PlaceSearchResult>[];
    for (final item in decoded.whereType<Map>()) {
      final place = Map<String, dynamic>.from(item);
      final latitude = double.tryParse(place['lat']?.toString() ?? '');
      final longitude = double.tryParse(place['lon']?.toString() ?? '');
      if (latitude == null || longitude == null) continue;
      final displayName = place['display_name']?.toString() ?? query;
      final name = place['name']?.toString().trim();
      results.add(
        PlaceSearchResult(
          name: name == null || name.isEmpty ? displayName.split(',').first : name,
          displayName: displayName,
          point: LatLng(latitude, longitude),
        ),
      );
    }
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
    final uri = Uri.parse(
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
