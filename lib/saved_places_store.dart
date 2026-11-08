import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A place the user saved. Saved places stay on this device only (they are
/// not synced to other devices), kept separately for each account.
class SavedPlace {
  const SavedPlace({
    required this.name,
    required this.address,
    required this.tag,
    this.locationId,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String address;
  final String tag;

  /// The NavAble place it was saved from, when there is one.
  final String? locationId;
  final double? latitude;
  final double? longitude;

  /// Tags the saved-place editor offers.
  static const tags = ['Home', 'Work', 'Transit', 'Civic', 'Custom'];

  SavedPlace copyWith({String? name, String? address, String? tag}) =>
      SavedPlace(
        name: name ?? this.name,
        address: address ?? this.address,
        tag: tag ?? this.tag,
        locationId: locationId,
        latitude: latitude,
        longitude: longitude,
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'tag': tag,
    'locationId': ?locationId,
    'latitude': ?latitude,
    'longitude': ?longitude,
  };

  /// Null when the stored entry is unusable (no name).
  static SavedPlace? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final tag = json['tag'];
    double? number(Object? v) => v is num ? v.toDouble() : null;
    return SavedPlace(
      name: name,
      address: json['address'] is String ? json['address'] as String : '',
      tag: tag is String && tags.contains(tag) ? tag : 'Custom',
      locationId: json['locationId'] is String
          ? json['locationId'] as String
          : null,
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
    );
  }
}

/// Reads and writes saved places in this device's local storage.
abstract final class SavedPlacesStore {
  /// One list per account on this device; guests share the 'guest' list.
  static String _key(String? userId) =>
      'saved_places.${userId == null || userId.isEmpty ? 'guest' : userId}';

  static Future<List<SavedPlace>> load(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decode(prefs.getString(_key(userId)));
    } catch (_) {
      return const []; // Storage unavailable: start with an empty list.
    }
  }

  /// Returns false when the device couldn't store the list.
  static Future<bool> save(String? userId, List<SavedPlace> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_key(userId), encode(places));
    } catch (_) {
      return false;
    }
  }

  static String encode(List<SavedPlace> places) =>
      jsonEncode([for (final place in places) place.toJson()]);

  /// Skips broken entries instead of losing the whole list.
  static List<SavedPlace> decode(String? stored) {
    if (stored == null || stored.isEmpty) return const [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?SavedPlace.fromJson(item)];
    } on FormatException {
      return const [];
    }
  }
}
