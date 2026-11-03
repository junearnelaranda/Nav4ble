import 'package:supabase_flutter/supabase_flutter.dart';

class LocationsApiException implements Exception {
  const LocationsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AccessibleLocation {
  const AccessibleLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.features,
    this.rating,
    this.googlePlaceId,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> features;
  final double? rating;

  /// Google place this NavAble place describes, if linked.
  final String? googlePlaceId;

  /// Cover photo an admin uploaded for this place, if any.
  final String? photoUrl;
}

class LocationsApi {
  LocationsApi._();

  static Future<List<AccessibleLocation>> getAccessibleLocations() async {
    final locations = await _listCollection('locations');
    if (locations.isEmpty) return const [];

    var relatedFeatures = const <List<Map<String, dynamic>>>[];
    try {
      relatedFeatures = await Future.wait([
        _listCollection('accessibility_features'),
        _listCollection('location_features'),
      ]);
    } on LocationsApiException {
      // Location pins remain useful when optional feature collections are private.
    }
    final featureNames = <String, String>{};
    for (final feature
        in relatedFeatures.isEmpty ? const [] : relatedFeatures[0]) {
      final id = _referenceId(_text(feature['feature_id']) ?? feature['id']);
      final name = _firstText(feature, const [
        'feature_name',
        'featureName',
        'name',
        'title',
      ]);
      final status = (_text(feature['status']) ?? '').toLowerCase();
      if (id != null && name != null && !_isInactive(status)) {
        featureNames[id] = name;
      }
    }

    final featuresByLocation = <String, Set<String>>{};
    for (final relation
        in relatedFeatures.length < 2 ? const [] : relatedFeatures[1]) {
      // A feature marked unavailable (e.g. broken elevator) isn't shown.
      if (relation['availability'] == false) continue;
      final locationId = _referenceId(
        _firstText(relation, const [
          'location_id',
          'locationId',
          'location_ref',
          'location',
        ]),
      );
      final featureId = _referenceId(
        _firstText(relation, const [
          'feature_id',
          'featureId',
          'feature_ref',
          'accessibility_feature_id',
        ]),
      );
      final featureName = featureId == null ? null : featureNames[featureId];
      if (locationId != null && featureName != null) {
        featuresByLocation
            .putIfAbsent(locationId, () => <String>{})
            .add(featureName);
      }
    }

    final covers = await _coverPhotos();
    final result = <AccessibleLocation>[];
    for (final document in locations) {
      final status =
          (_text(document['verification_status']) ??
                  _text(document['status']) ??
                  '')
              .toLowerCase();
      if (_isInactive(status)) continue;
      final id = document['location_id'] ?? document['id'];
      if (id == null) continue;
      final latitude = _coordinate(
        document,
        const ['latitude', 'lat'],
        nested: const ['coordinates', 'location', 'position'],
      );
      final longitude = _coordinate(
        document,
        const ['longitude', 'lng', 'lon'],
        nested: const ['coordinates', 'location', 'position'],
      );
      if (latitude == null || longitude == null) continue;
      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }

      final name = _firstText(document, const [
        'location_name',
        'locationName',
        'establishment_name',
        'establishmentName',
        'name',
        'title',
      ]);
      if (name == null) continue;
      final features = <String>{
        ..._featureLabels(document['accessibility_features']),
        ..._featureLabels(document['accessibilityFeatures']),
        ..._featureLabels(document['features']),
        ...?featuresByLocation[_referenceId(
              _firstText(document, const ['location_id', 'locationId']),
            ) ??
            document['id']],
        ...?featuresByLocation[document['id']],
      }.toList(growable: false);
      result.add(
        AccessibleLocation(
          id: id.toString(),
          name: name,
          address:
              _firstText(document, const [
                'address',
                'formatted_address',
                'formattedAddress',
                'description',
              ]) ??
              '',
          latitude: latitude,
          longitude: longitude,
          features: features,
          rating:
              _number(document['rating']) ??
              // 0 is the database default, meaning "not rated yet".
              _rated(_number(document['accessibility_score'])) ??
              _number(document['average_rating']) ??
              _number(document['averageRating']),
          googlePlaceId: _text(document['google_place_id']),
          photoUrl: covers[id.toString()],
        ),
      );
    }
    return List<AccessibleLocation>.unmodifiable(result);
  }

  static Future<List<Map<String, dynamic>>> _listCollection(
    String table,
  ) async {
    try {
      final rows = await Supabase.instance.client
          .from(table)
          .select()
          .limit(500);
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } on PostgrestException catch (error) {
      throw LocationsApiException('Could not load $table: ${error.message}');
    } on Exception catch (error) {
      throw LocationsApiException('Could not load $table: $error');
    }
  }

  static double? _coordinate(
    Map<String, dynamic> document,
    List<String> keys, {
    required List<String> nested,
  }) {
    for (final key in keys) {
      final value = _number(document[key]);
      if (value != null) return value;
    }
    for (final key in nested) {
      final value = document[key];
      if (value is Map) {
        for (final coordinateKey in keys) {
          final coordinate = _number(value[coordinateKey]);
          if (coordinate != null) return coordinate;
        }
        final text = _text(value['coordinates']);
        final parsed = _coordinatePair(text, keys.first);
        if (parsed != null) return parsed;
      } else {
        final parsed = _coordinatePair(_text(value), keys.first);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static double? _coordinatePair(String? value, String wanted) {
    if (value == null) return null;
    final match = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(value);
    if (match == null) return null;
    return double.tryParse(
      match[wanted == 'latitude' || wanted == 'lat' ? 1 : 2]!,
    );
  }

  static List<String> _featureLabels(dynamic value) {
    if (value is String) return [value];
    if (value is Map) {
      final name = _firstText(value, const [
        'feature_name',
        'featureName',
        'name',
        'label',
      ]);
      return name == null ? const [] : [name];
    }
    if (value is! Iterable) return const [];
    return value
        .map((item) {
          if (item is String) return item;
          if (item is Map) {
            return _firstText(item.cast<String, dynamic>(), const [
              'feature_name',
              'featureName',
              'name',
              'label',
            ]);
          }
          return null;
        })
        .whereType<String>()
        .toList(growable: false);
  }

  static String? _firstText(Map<dynamic, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = _text(values[key]);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _text(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static String? _referenceId(Object? value) =>
      value?.toString().split('/').last;

  /// First admin photo per place (oldest first, like the admin page's
  /// "Cover"). The database only shows other people's photos when an admin
  /// uploaded them for a verified place; the user's own report photos are
  /// skipped so they don't become a cover for them.
  static Future<Map<String, String>> _coverPhotos() async {
    try {
      final client = Supabase.instance.client;
      final me = client.auth.currentUser?.id;
      final rows = await client
          .from('images')
          .select('location_id, image_url, user_id')
          .eq('upload_status', 'Uploaded')
          .order('upload_date')
          .order('image_id')
          .limit(1000);
      final covers = <String, String>{};
      for (final row in rows) {
        final url = _text(row['image_url']);
        final location = row['location_id']?.toString();
        if (url == null || location == null || row['user_id'] == me) continue;
        if (!url.startsWith('https://')) continue;
        covers.putIfAbsent(location, () => url);
      }
      return covers;
    } on Exception {
      return const {}; // Photos are optional; places still load.
    }
  }

  static double? _rated(double? score) =>
      score != null && score > 0 ? score : null;

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static bool _isInactive(String status) =>
      status.contains('pending') ||
      status.contains('reject') ||
      status.contains('inactive') ||
      status.contains('deleted') ||
      status.contains('draft');
}
