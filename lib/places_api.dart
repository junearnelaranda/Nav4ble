import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'locations_api.dart';

class PlacesApiException implements Exception {
  const PlacesApiException(this.message, {this.notConfigured = false});

  final String message;

  /// The Google key hasn't been added to Supabase yet.
  final bool notConfigured;

  @override
  String toString() => message;
}

/// A Google Places search result. Shown live only: Google's terms allow
/// NavAble to store just [id] (see `locations.google_place_id`).
class GooglePlace {
  const GooglePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.shortAddress,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.ratingCount = 0,
    this.type,
    this.openNow,
    this.accessibilityTags = const [],
    this.photo,
    this.photoAttribution,
  });

  factory GooglePlace.fromJson(Map<String, dynamic> json) {
    final access = json['accessibility'];
    final tags = <String>[
      if (access is Map) ...[
        if (access['wheelchairEntrance'] == true) 'Accessible entrance',
        if (access['wheelchairRestroom'] == true) 'Accessible restroom',
        if (access['wheelchairParking'] == true) 'Accessible parking',
        if (access['wheelchairSeating'] == true) 'Wheelchair seating',
      ],
    ];
    double? number(Object? v) => v is num ? v.toDouble() : null;
    return GooglePlace(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      shortAddress: json['shortAddress'] as String? ?? '',
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
      rating: number(json['rating']),
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      type: json['type'] as String?,
      openNow: json['openNow'] as bool?,
      accessibilityTags: tags,
      photo: json['photo'] as String?,
      photoAttribution: json['photoAttribution'] as String?,
    );
  }

  final String id;
  final String name;
  final String address;
  final String shortAddress;
  final double? latitude;
  final double? longitude;

  /// Google's general rating (not accessibility).
  final double? rating;
  final int ratingCount;
  final String? type;
  final bool? openNow;

  /// Wheelchair facts Google knows, for places NavAble hasn't rated yet.
  final List<String> accessibilityTags;

  /// Google photo name; load it with [PlacesApi.photoUrl].
  final String? photo;
  final String? photoAttribution;
}

abstract final class PlacesApi {
  static const _function = 'places-search';
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static Future<List<GooglePlace>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    dynamic data;
    try {
      final response = await Supabase.instance.client.functions
          .invoke(
            _function,
            body: {
              'query': query,
              'latitude': ?latitude,
              'longitude': ?longitude,
            },
          )
          .timeout(const Duration(seconds: 20));
      data = response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map && details['error'] is Map
          ? details['error']['code']
          : null;
      throw PlacesApiException(
        code == 'PLACES_NOT_CONFIGURED'
            ? 'Google place search is not set up yet.'
            : 'Place search is unavailable right now.',
        notConfigured: code == 'PLACES_NOT_CONFIGURED',
      );
    } on Exception {
      throw const PlacesApiException('Could not reach place search.');
    }
    final places = data is Map ? data['places'] : null;
    if (places is! List) {
      throw const PlacesApiException('Place search returned no results.');
    }
    return places
        .whereType<Map>()
        .map((p) => GooglePlace.fromJson(Map<String, dynamic>.from(p)))
        .toList(growable: false);
  }

  /// Image URL for a Google photo, served through the Supabase function so
  /// the Google key never reaches the app.
  static String photoUrl(String photo, {int width = 600}) => Uri.parse(
    '$_supabaseUrl/functions/v1/$_function',
  ).replace(queryParameters: {'photo': photo, 'w': '$width'}).toString();

  static Map<String, String> get photoHeaders => {'apikey': _supabaseKey};

  /// Straight-line distance in kilometres.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

/// The NavAble place that is the same place as Google's [place], for
/// NavAble records not linked to Google yet (no `google_place_id`).
///
/// Same place means within [maxKm] and nearly the same name: at least 60%
/// of the name words shared. So "Ayala Center Cebu" matches its Google
/// listing, but "Bo's Coffee Ayala Center Cebu" (a shop inside) does not.
AccessibleLocation? matchNavAblePlace(
  GooglePlace place,
  Iterable<AccessibleLocation> locations, {
  double maxKm = 0.3,
}) {
  final lat = place.latitude;
  final lng = place.longitude;
  if (lat == null || lng == null) return null;
  final googleWords = _nameWords(place.name);
  if (googleWords.isEmpty) return null;
  AccessibleLocation? best;
  var bestKm = double.infinity;
  for (final location in locations) {
    if (location.googlePlaceId != null) continue; // linked to its own listing
    final km = PlacesApi.distanceKm(
      lat,
      lng,
      location.latitude,
      location.longitude,
    );
    if (km > maxKm || km >= bestKm) continue;
    final words = _nameWords(location.name);
    final shared = words.intersection(googleWords).length;
    final all = words.union(googleWords).length;
    if (all == 0 || shared / all < 0.6) continue;
    best = location;
    bestKm = km;
  }
  return best;
}

Set<String> _nameWords(String name) => name
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((word) => word.isNotEmpty)
    .toSet();
