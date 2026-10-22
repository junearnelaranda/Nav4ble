import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> features;
  final double? rating;
}

class LocationsApi {
  LocationsApi._();

  static const _projectId = 'nav4ble-22f2d';
  static const _documentsUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  static Future<List<AccessibleLocation>> getAccessibleLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    final locations = await _listCollection('locations', token);
    if (locations.isEmpty) return const [];

    var relatedFeatures = const <List<Map<String, dynamic>>>[];
    try {
      relatedFeatures = await Future.wait([
        _listCollection('accessibility_features', token),
        _listCollection('location_features', token),
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

    final result = <AccessibleLocation>[];
    for (final document in locations) {
      final status = (_text(document['status']) ?? '').toLowerCase();
      if (_isInactive(status)) continue;
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
          id: document['id']!,
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
              _number(document['average_rating']) ??
              _number(document['averageRating']),
        ),
      );
    }
    return List<AccessibleLocation>.unmodifiable(result);
  }

  static Future<List<Map<String, dynamic>>> _listCollection(
    String collection,
    String? token,
  ) async {
    final documents = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final uri = Uri.parse(
        '$_documentsUrl/$collection',
      ).replace(queryParameters: {'pageSize': '100', 'pageToken': ?pageToken});
      http.Response response;
      try {
        response = await http
            .get(uri, headers: _authHeaders(token))
            .timeout(const Duration(seconds: 20));
      } on Exception catch (error) {
        throw LocationsApiException('Could not load map locations: $error');
      }
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        throw LocationsApiException(
          'Firestore returned an unreadable response (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = body is Map ? body['error'] : null;
        final message = error is Map ? error['message'] as String? : null;
        throw LocationsApiException(
          message ?? 'Could not read the locations collection from Firestore.',
          statusCode: response.statusCode,
        );
      }
      final page = body is Map ? body : const <String, dynamic>{};
      final rawDocuments = page['documents'];
      if (rawDocuments is List) {
        documents.addAll(
          rawDocuments.whereType<Map>().map((document) {
            final path = document['name'] as String? ?? '';
            final fields = document['fields'];
            final decodedFields = fields is Map
                ? Map<String, dynamic>.from(
                    fields.map(
                      (key, value) => MapEntry(key.toString(), _decode(value)),
                    ),
                  )
                : null;
            return {'id': path.split('/').last, ...?decodedFields};
          }),
        );
      }
      pageToken = page['nextPageToken'] as String?;
    } while (pageToken != null && documents.length < 500);
    return documents;
  }

  static dynamic _decode(dynamic value) {
    if (value is! Map) return value;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) {
      return num.tryParse(value['integerValue'].toString());
    }
    if (value.containsKey('doubleValue')) return value['doubleValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('geoPointValue')) {
      final point = value['geoPointValue'];
      return point is Map
          ? {'latitude': point['latitude'], 'longitude': point['longitude']}
          : null;
    }
    if (value.containsKey('mapValue')) {
      final fields = value['mapValue'] is Map
          ? value['mapValue']['fields']
          : null;
      if (fields is! Map) return <String, dynamic>{};
      return fields.map((key, item) => MapEntry(key.toString(), _decode(item)));
    }
    if (value.containsKey('arrayValue')) {
      final values = value['arrayValue'] is Map
          ? value['arrayValue']['values']
          : null;
      return values is List ? values.map(_decode).toList() : <dynamic>[];
    }
    if (value.containsKey('referenceValue')) return value['referenceValue'];
    return null;
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

  static Map<String, String> _authHeaders(String? token) {
    if (token == null) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  static String? _referenceId(String? value) => value?.split('/').last;

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
