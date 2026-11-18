import 'dart:math';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reports_api.dart';
import 'services/google_maps_launcher.dart';

class GuidesApiException implements Exception {
  const GuidesApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// An accessibility feature a guide can be written for.
class GuideFeature {
  const GuideFeature({required this.id, required this.name});

  final String id;
  final String name;
}

/// Where to find one accessibility feature at a place, approved by an admin.
class FeatureGuide {
  const FeatureGuide({
    required this.id,
    required this.featureId,
    required this.featureName,
    required this.whereText,
    required this.featurePhotoUrl,
    required this.nearbyPhotoUrl,
    this.floor,
    this.landmark,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String featureId;
  final String featureName;
  final String whereText;
  final String? floor;
  final String? landmark;

  /// Set together, only for spots that can be shown on the map.
  final double? latitude;
  final double? longitude;
  final String featurePhotoUrl;
  final String nearbyPhotoUrl;

  bool get hasPin => latitude != null && longitude != null;

  /// Null when the row is not a usable guide. A pin that is not a real map
  /// point is dropped; the written guide still works without it.
  static FeatureGuide? fromRow(Map<dynamic, dynamic> row) {
    String text(String key) => row[key]?.toString().trim() ?? '';
    String? optional(String key) {
      final value = text(key);
      return value.isEmpty ? null : value;
    }

    final id = text('guide_id');
    final name = text('feature_name');
    final where = text('where_text');
    final featurePhoto = text('feature_photo_url');
    final nearbyPhoto = text('nearby_photo_url');
    if (id.isEmpty || name.isEmpty || where.isEmpty) return null;
    if (!featurePhoto.startsWith('https://') ||
        !nearbyPhoto.startsWith('https://')) {
      return null;
    }
    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    final validPin = GoogleMapsLauncher.isValidCoordinate(
      latitude: latitude,
      longitude: longitude,
    );
    return FeatureGuide(
      id: id,
      featureId: text('feature_id'),
      featureName: name,
      whereText: where,
      floor: optional('floor'),
      landmark: optional('landmark'),
      latitude: validPin ? latitude : null,
      longitude: validPin ? longitude : null,
      featurePhotoUrl: featurePhoto,
      nearbyPhotoUrl: nearbyPhoto,
    );
  }
}

/// A new guide from the add-a-guide form. The feature photo is either newly
/// picked ([featurePhoto]) or one already uploaded ([featurePhotoUrl]).
class GuideSubmission {
  const GuideSubmission({
    required this.locationId,
    required this.featureId,
    required this.whereText,
    required this.nearbyPhoto,
    this.floor = '',
    this.landmark = '',
    this.pin,
    this.featurePhoto,
    this.featurePhotoUrl,
  });

  final String locationId;
  final String featureId;
  final String whereText;
  final String floor;
  final String landmark;
  final LatLng? pin;
  final Uint8List? featurePhoto;
  final String? featurePhotoUrl;
  final Uint8List nearbyPhoto;
}

/// The same feature name however it is capitalized or spaced.
String featureKey(String name) => name.trim().toLowerCase();

/// Guides grouped by [featureKey], keeping their order.
Map<String, List<FeatureGuide>> guidesByFeature(Iterable<FeatureGuide> guides) {
  final grouped = <String, List<FeatureGuide>>{};
  for (final guide in guides) {
    grouped.putIfAbsent(featureKey(guide.featureName), () => []).add(guide);
  }
  return grouped;
}

/// The feature an AI label means ("Toilet" is the accessible restroom).
GuideFeature? featureForDetection(
  String detected,
  List<GuideFeature> features,
) {
  const groups = [
    (words: ['ramp'], feature: 'ramp'),
    (words: ['elevator', 'lift'], feature: 'elevator'),
    (words: ['entrance', 'door'], feature: 'entrance'),
    (words: ['restroom', 'toilet', 'comfort room'], feature: 'restroom'),
    (words: ['tactile'], feature: 'tactile'),
    (words: ['parking'], feature: 'parking'),
    (words: ['seat'], feature: 'seat'),
    (words: ['braille'], feature: 'braille'),
  ];
  final label = detected.toLowerCase();
  for (final group in groups) {
    if (!group.words.any(label.contains)) continue;
    for (final feature in features) {
      if (feature.name.toLowerCase().contains(group.feature)) return feature;
    }
  }
  return null;
}

abstract final class GuidesApi {
  static const maxWhere = 200;
  static const maxFloor = 40;
  static const maxLandmark = 120;
  static const maxPinMeters = 500;
  static const _bucket = 'report-photos';

  static SupabaseClient get _client => Supabase.instance.client;

  /// What is wrong with a guide before it is sent, or null when it is fine.
  static String? validate({
    required String whereText,
    String floor = '',
    String landmark = '',
    required bool hasFeaturePhoto,
    required bool hasNearbyPhoto,
    LatLng? pin,
    required LatLng place,
  }) {
    final where = whereText.trim();
    if (where.isEmpty) return 'Tell people where to find it.';
    if (where.length > maxWhere) {
      return 'Keep the location to $maxWhere characters or fewer.';
    }
    if (floor.trim().length > maxFloor) {
      return 'Keep the floor to $maxFloor characters or fewer.';
    }
    if (landmark.trim().length > maxLandmark) {
      return 'Keep the landmark to $maxLandmark characters or fewer.';
    }
    if (!hasFeaturePhoto) return 'Add a photo of the feature.';
    if (!hasNearbyPhoto) return 'Add a photo of what is nearby.';
    if (pin != null && const Distance().distance(place, pin) > maxPinMeters) {
      return 'Pin a spot within $maxPinMeters m of this place.';
    }
    return null;
  }

  /// Why a picked photo cannot be used, or null when it can.
  static String? photoProblem(Uint8List bytes) =>
      bytes.lengthInBytes > ReportsApi.maxPhotoBytes
      ? 'This photo is over 700 KiB. Choose a smaller photo.'
      : null;

  /// Approved guides for a place, for everyone including guests.
  static Future<List<FeatureGuide>> forLocation(String locationId) async {
    try {
      final rows = await _client.rpc(
        'get_location_guides',
        params: {'place': locationId},
      );
      return [
        for (final row in (rows as List).whereType<Map>())
          ?FeatureGuide.fromRow(row),
      ];
    } on Exception {
      throw const GuidesApiException("Couldn't load the guides. Try again.");
    }
  }

  static Future<List<GuideFeature>> activeFeatures() async {
    try {
      final rows = await _client
          .from('accessibility_features')
          .select('feature_id, feature_name')
          .eq('status', 'Active')
          .order('feature_name');
      return [
        for (final row in rows)
          GuideFeature(
            id: row['feature_id'].toString(),
            name: row['feature_name'].toString(),
          ),
      ];
    } on Exception {
      throw const GuidesApiException("Couldn't load the features. Try again.");
    }
  }

  /// Uploads the photos and sends the guide for admin review. If anything
  /// fails, the photos uploaded for this attempt are removed again.
  static Future<void> submit(GuideSubmission submission) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const GuidesApiException('Sign in to add where to find it.');
    }
    final storage = _client.storage.from(_bucket);
    final folder = '$userId/guides/${_randomId()}';
    final uploaded = <String>[];

    Future<String> upload(Uint8List bytes, String name) async {
      final (extension, contentType) = _photoType(bytes);
      final path = '$folder/$name.$extension';
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );
      uploaded.add(path);
      return storage.getPublicUrl(path);
    }

    try {
      final featureUrl =
          submission.featurePhotoUrl ??
          await upload(submission.featurePhoto!, 'feature');
      final nearbyUrl = await upload(submission.nearbyPhoto, 'nearby');
      await _client.from('feature_guides').insert({
        'location_id': submission.locationId,
        'feature_id': submission.featureId,
        'user_id': userId,
        'where_text': submission.whereText.trim(),
        'floor': _nullIfBlank(submission.floor),
        'landmark': _nullIfBlank(submission.landmark),
        'latitude': submission.pin?.latitude,
        'longitude': submission.pin?.longitude,
        'feature_photo_url': featureUrl,
        'nearby_photo_url': nearbyUrl,
      });
    } on Exception {
      if (uploaded.isNotEmpty) {
        try {
          await storage.remove(uploaded);
        } on Exception {
          // The guide already failed; leftover photos are not linked anywhere.
        }
      }
      throw const GuidesApiException("Couldn't send your guide. Try again.");
    }
  }

  static String? _nullIfBlank(String text) {
    final value = text.trim();
    return value.isEmpty ? null : value;
  }

  static (String, String) _photoType(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return ('png', 'image/png');
    }
    if (bytes.length > 11 && bytes[8] == 0x57 && bytes[9] == 0x45) {
      return ('webp', 'image/webp');
    }
    return ('jpg', 'image/jpeg');
  }

  static String _randomId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
