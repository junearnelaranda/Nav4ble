import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/on_device_detector.dart';

class ReportsApiException implements Exception {
  const ReportsApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class SubmittedReport {
  const SubmittedReport({
    required this.id,
    required this.aiAnalysisStatus,
    required this.detections,
  });
  final String id;
  final String aiAnalysisStatus;
  final List<Map<String, dynamic>> detections;
}

class PhotoAnalysis {
  const PhotoAnalysis({
    required this.status,
    required this.photoSuggestions,
    this.message,
  });

  factory PhotoAnalysis.failedFor(int count, {String? message}) =>
      PhotoAnalysis(
        status: 'failed',
        message: message,
        photoSuggestions: List<Map<String, dynamic>>.generate(
          count,
          (index) => {
            'photoIndex': index,
            'image': {'width': null, 'height': null},
            'detections': <Map<String, dynamic>>[],
            'error': 'analysis_failed',
          },
          growable: false,
        ),
      );

  final String status;
  final List<Map<String, dynamic>> photoSuggestions;
  final String? message;

  List<Map<String, dynamic>> get detections => photoSuggestions
      .where((suggestion) => suggestion['detections'] is List)
      .expand((suggestion) => suggestion['detections'] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

/// Where a report stands with the admins (`reports.status`).
enum ReportStatus {
  pending('Waiting for review'),
  verified('Verified'),
  resolved('Resolved'),
  rejected('Not approved');

  const ReportStatus(this.label);

  final String label;

  static ReportStatus from(String? value) => switch (value) {
    'Verified' => verified,
    'Resolved' => resolved,
    'Rejected' => rejected,
    _ => pending,
  };
}

/// One of the signed-in user's reports, as stored (so it survives restarts
/// and shows the admins' latest decision).
class MyReport {
  const MyReport({
    required this.id,
    required this.title,
    required this.detail,
    required this.category,
    required this.placeName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String detail;
  final String category;
  final String placeName;
  final ReportStatus status;
  final DateTime createdAt;

  /// Reads a `reports` row. Descriptions written by the app look like
  /// "[Category] Title: details" (see [ReportsApi.reportDescription]).
  static MyReport? fromRow(Map<String, dynamic> row) {
    final id = row['report_id'];
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (id is! String || created == null) return null;
    final text = (row['description'] as String? ?? '').trim();
    final parts = RegExp(
      r'^\[([^\]]+)\]\s*([^:]+?):\s*(.*)$',
      dotAll: true,
    ).firstMatch(text);
    final location = row['locations'];
    final place = location is Map ? location['location_name'] : null;
    return MyReport(
      id: id,
      title: parts?.group(2)?.trim() ?? text,
      detail: parts?.group(3)?.trim() ?? '',
      category:
          parts?.group(1)?.trim() ??
          (row['report_type'] as String? ?? 'Others'),
      placeName: place is String && place.trim().isNotEmpty
          ? place.trim()
          : 'a place',
      status: ReportStatus.from(row['status'] as String?),
      createdAt: created.toLocal(),
    );
  }
}

class ReportsApi {
  /// The signed-in user's reports, newest first.
  static Future<List<MyReport>> myReports() async {
    final client = Supabase.instance.client;
    final me = client.auth.currentUser?.id;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('reports')
          .select(
            'report_id, report_type, description, status, created_at, '
            'locations(location_name)',
          )
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(100);
      return [for (final row in rows) ?MyReport.fromRow(row)];
    } on PostgrestException {
      throw const ReportsApiException('Could not load your reports.');
    }
  }

  ReportsApi._();

  /// Optional Cloudflare Worker. When unset, photos are analyzed by the
  /// `roboflow-infer` Supabase Edge Function in the same project.
  static const String _workerUrl = String.fromEnvironment(
    'NAVABLE_REPORTS_API_URL',
  );
  static const _analysisFunction = 'roboflow-infer';
  static const maxPhotoBytes = 700 * 1024;
  static const _maxPhotos = 5;
  static const _bucket = 'report-photos';

  /// Saves a report into the tables the admin app reads:
  /// photos -> storage + `images`, the report -> `reports` (linked to the
  /// first photo), and each AI detection -> `ai_results` for admin review.
  static Future<SubmittedReport> submit({
    required String title,
    required String detail,
    required String category,
    required String? locationId,
    required List<Uint8List> photos,
    required PhotoAnalysis analysis,
    String? coordinates,
    String? googlePlaceId,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const ReportsApiException(
        'Sign in to submit an accessibility report.',
      );
    }
    // No NavAble place picked: suggest the pinned spot as a new Pending
    // place, which an admin approves before it shows on the map.
    final suggestedPlace = locationId == null || locationId.isEmpty
        ? suggestedPlaceRow(
            id: _uuidV4(),
            name: title,
            coordinates: coordinates,
            googlePlaceId: googlePlaceId,
          )
        : null;
    final placeId = suggestedPlace?['location_id'] as String? ?? locationId!;
    _validatePhotos(photos);
    if (analysis.photoSuggestions.length != photos.length) {
      throw const ReportsApiException(
        'Scan the current photos before submitting the report.',
      );
    }

    final reportId = _uuidV4();
    final imageIds = List<String>.generate(photos.length, (_) => _uuidV4());
    final paths = <String>[];
    var insertedImages = false;
    var insertedReport = false;
    var insertedPlace = false;
    try {
      if (suggestedPlace != null) {
        await client.from('locations').insert(suggestedPlace);
        insertedPlace = true;
      }
      final storage = client.storage.from(_bucket);
      final imageRows = <Map<String, dynamic>>[];
      for (var index = 0; index < photos.length; index++) {
        final contentType = _contentType(photos[index])!;
        final extension = switch (contentType) {
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => 'jpg',
        };
        final name = 'photo_$index.$extension';
        final path = '${user.id}/$reportId/$name';
        await storage.uploadBinary(
          path,
          photos[index],
          fileOptions: FileOptions(contentType: contentType),
        );
        paths.add(path);
        imageRows.add({
          'image_id': imageIds[index],
          'user_id': user.id,
          'location_id': placeId,
          'image_url': storage.getPublicUrl(path),
          'image_name': name,
          'image_size': (photos[index].lengthInBytes + 1023) ~/ 1024, // KiB
          'upload_status': 'Uploaded',
        });
      }
      await client.from('images').insert(imageRows);
      insertedImages = true;

      await client.from('reports').insert({
        'report_id': reportId,
        'user_id': user.id,
        'location_id': placeId,
        'image_id': imageIds.first,
        'report_type': reportTypeFor(category),
        'description': reportDescription(
          category: category,
          title: title,
          detail: detail,
        ),
        'status': 'Pending',
        'priority_level': 'Medium',
      });
      insertedReport = true;
    } on PostgrestException catch (error) {
      await _cleanupFailedSubmission(
        client,
        reportId: insertedReport ? reportId : null,
        imageIds: insertedImages ? imageIds : const [],
        paths: paths,
        placeId: insertedPlace ? placeId : null,
      );
      throw ReportsApiException('Could not save the report: ${error.message}');
    } on StorageException catch (error) {
      await _cleanupFailedSubmission(
        client,
        paths: paths,
        placeId: insertedPlace ? placeId : null,
      );
      throw ReportsApiException(
        'Could not upload the photos: ${error.message}',
      );
    } on Exception catch (error) {
      await _cleanupFailedSubmission(
        client,
        reportId: insertedReport ? reportId : null,
        imageIds: insertedImages ? imageIds : const [],
        paths: paths,
        placeId: insertedPlace ? placeId : null,
      );
      throw ReportsApiException('Could not submit the report: $error');
    }

    // The report is saved. AI suggestions are extra: if they can't be
    // stored, keep the report and let admins review the photos directly.
    var aiStatus = analysis.status;
    final aiRows = aiResultRows(analysis: analysis, imageIds: imageIds);
    if (aiRows.isNotEmpty) {
      try {
        await client.from('ai_results').insert(aiRows);
      } on Exception {
        aiStatus = 'failed';
      }
    }
    return SubmittedReport(
      id: reportId,
      aiAnalysisStatus: aiStatus,
      detections: analysis.detections,
    );
  }

  static const _aiModel =
      'Roboflow RF-DETR Small (navable-accessibility-detection v2)';

  /// Maps the app's report categories onto the database's report types.
  /// Photos of an existing feature have no matching problem type, so they
  /// are filed as "Others" with the category kept in the description.
  @visibleForTesting
  static String reportTypeFor(String category) {
    final value = category.toLowerCase();
    if (value.contains('broken') && value.contains('ramp')) {
      return 'Broken Ramp';
    }
    if (value.contains('broken') && value.contains('elevator')) {
      return 'Broken Elevator';
    }
    if (value.contains('blocked') && value.contains('entrance')) {
      return 'Blocked Entrance';
    }
    if (value.contains('construction')) return 'Construction';
    return 'Others';
  }

  /// `reports.description` holds at most 500 characters.
  @visibleForTesting
  static String reportDescription({
    required String category,
    required String title,
    required String detail,
  }) {
    final text = '[$category] ${title.trim()}: ${detail.trim()}';
    return text.length <= 500 ? text : '${text.substring(0, 499)}…';
  }

  /// One `ai_results` row per detection, confidence as a 0–100 percentage.
  @visibleForTesting
  static List<Map<String, dynamic>> aiResultRows({
    required PhotoAnalysis analysis,
    required List<String> imageIds,
  }) {
    final rows = <Map<String, dynamic>>[];
    for (final suggestion in analysis.photoSuggestions) {
      final index = suggestion['photoIndex'];
      final detections = suggestion['detections'];
      if (index is! int || index < 0 || index >= imageIds.length) continue;
      if (detections is! List) continue;
      for (final detection in detections.whereType<Map>()) {
        final label =
            detection['class'] ?? detection['label'] ?? detection['class_name'];
        final confidence = detection['confidence'];
        if (label is! String || label.trim().isEmpty) continue;
        if (confidence is! num || !confidence.isFinite) continue;
        final percent = (confidence <= 1 ? confidence * 100 : confidence)
            .clamp(0, 100)
            .toDouble();
        final feature = label.trim();
        rows.add({
          'image_id': imageIds[index],
          'detected_feature': feature.length <= 100
              ? feature
              : feature.substring(0, 100),
          'confidence_score': (percent * 100).round() / 100,
          'detection_status': 'Needs Verification',
          'ai_model': suggestion['model'] is String
              ? suggestion['model']
              : _aiModel,
          'verified': false,
        });
      }
    }
    return rows;
  }

  static Future<void> _cleanupFailedSubmission(
    SupabaseClient client, {
    String? reportId,
    List<String> imageIds = const [],
    List<String> paths = const [],
    String? placeId,
  }) async {
    if (reportId != null) {
      try {
        await client.from('reports').delete().eq('report_id', reportId);
      } on Exception {
        // Preserve the original submission error.
      }
    }
    if (imageIds.isNotEmpty) {
      try {
        await client.from('images').delete().inFilter('image_id', imageIds);
      } on Exception {
        // Preserve the original submission error.
      }
    }
    if (paths.isNotEmpty) {
      try {
        await client.storage.from(_bucket).remove(paths);
      } on Exception {
        // An interrupted cleanup may leave orphan files for administrator review.
      }
    }
    if (placeId != null) {
      try {
        await client.from('locations').delete().eq('location_id', placeId);
      } on Exception {
        // A leftover Pending place is harmless; an admin can reject it.
      }
    }
  }

  /// A new place the user pinned, saved as Pending for an admin to approve.
  /// Status, score and owner come from database defaults.
  @visibleForTesting
  static Map<String, dynamic> suggestedPlaceRow({
    required String id,
    required String name,
    required String? coordinates,
    String? googlePlaceId,
  }) {
    final match = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(coordinates ?? '');
    final latitude = double.tryParse(match?[1] ?? '');
    final longitude = double.tryParse(match?[2] ?? '');
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const ReportsApiException('Pin the place on the map first.');
    }
    final placeName = name.trim();
    if (placeName.isEmpty) {
      throw const ReportsApiException(
        'Enter the place name so an admin can add it to NavAble.',
      );
    }
    return {
      'location_id': id,
      'location_name': placeName.length <= 150
          ? placeName
          : placeName.substring(0, 150),
      'category': 'User suggested',
      'address':
          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
      'latitude': latitude,
      'longitude': longitude,
      if (googlePlaceId != null && googlePlaceId.isNotEmpty)
        'google_place_id': googlePlaceId,
    };
  }

  static Future<PhotoAnalysis> analyzePhotos({
    required List<Uint8List> photos,
  }) async {
    _validatePhotos(photos);
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw const ReportsApiException(
        'Your sign-in expired. Sign in again to scan photos.',
      );
    }
    final suggestions = <Map<String, dynamic>>[];
    var failedAnalyses = 0;
    for (var index = 0; index < photos.length; index++) {
      try {
        suggestions.add({
          'photoIndex': index,
          ...await _analyzePhoto(photos[index], session.accessToken),
        });
      } on ReportsApiException {
        failedAnalyses++;
        suggestions.add(
          PhotoAnalysis.failedFor(1).photoSuggestions.single
            ..['photoIndex'] = index,
        );
      }
    }
    final status = failedAnalyses == 0
        ? 'completed'
        : failedAnalyses == photos.length
        ? 'failed'
        : 'partial';
    return PhotoAnalysis(
      status: status,
      message: failedAnalyses == 0
          ? null
          : 'Some photos could not be scanned. You can still submit for admin review.',
      photoSuggestions: List<Map<String, dynamic>>.unmodifiable(suggestions),
    );
  }

  static void _validatePhotos(List<Uint8List> photos) {
    if (photos.isEmpty || photos.length > _maxPhotos) {
      throw const ReportsApiException('Attach between 1 and 5 photos.');
    }
    for (final photo in photos) {
      if (_contentType(photo) == null) {
        throw const ReportsApiException('Use JPEG, PNG, or WebP photos.');
      }
      if (photo.lengthInBytes > maxPhotoBytes) {
        throw const ReportsApiException(
          'Each photo must be 700 KiB or smaller.',
        );
      }
    }
  }

  static Future<Map<String, dynamic>> _analyzePhoto(
    Uint8List photo,
    String token,
  ) async {
    // The bundled YOLO model runs offline; fall back to the online service
    // on the web or before a model has been added to assets/models/.
    final onDevice = await OnDeviceDetector.detect(photo);
    if (onDevice != null) return onDevice;
    final request = {
      'inputs': {
        'image': {'type': 'base64', 'value': base64Encode(photo)},
      },
    };
    final (statusCode, body) = _workerUrl.isEmpty
        ? await _callEdgeFunction(request)
        : await _callWorker(request, token);
    return parseAnalysisResponse(statusCode, body);
  }

  static Future<(int, dynamic)> _callEdgeFunction(
    Map<String, dynamic> request,
  ) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke(_analysisFunction, body: request)
          .timeout(const Duration(seconds: 90));
      return (response.status, response.data);
    } on FunctionException catch (error) {
      return (error.status, error.details);
    } on Exception catch (error) {
      throw ReportsApiException('Could not reach photo analysis: $error');
    }
  }

  static Future<(int, dynamic)> _callWorker(
    Map<String, dynamic> request,
    String token,
  ) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_workerUrl/infer'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request),
          )
          .timeout(const Duration(seconds: 90));
    } on Exception catch (error) {
      throw ReportsApiException('Could not reach photo analysis: $error');
    }
    try {
      return (response.statusCode, jsonDecode(response.body));
    } on FormatException {
      throw ReportsApiException(
        'The analysis service returned an unreadable response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
  }

  /// Turns the analysis service's reply into `{image, detections}`.
  @visibleForTesting
  static Map<String, dynamic> parseAnalysisResponse(
    int statusCode,
    dynamic body,
  ) {
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        body = null;
      }
    }
    if (statusCode < 200 || statusCode >= 300) {
      final message = body is Map && body['error'] is Map
          ? body['error']['message'] as String?
          : null;
      throw ReportsApiException(
        message ?? 'Photo analysis failed (HTTP $statusCode).',
        statusCode: statusCode,
      );
    }
    if (body is! Map || body['detections'] is! List) {
      throw const ReportsApiException(
        'The analysis service returned invalid detections.',
      );
    }
    final image = body['image'];
    final detections = (body['detections'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    return {
      'image': image is Map
          ? Map<String, dynamic>.from(image)
          : {'width': null, 'height': null},
      'detections': detections,
    };
  }

  /// The app's choices for `bug_reports.area` (the admin Bug Reports page
  /// filters by these). "Website" is left out: it's for the public site.
  static const bugAreas = [
    'Map & Navigation',
    'Accessibility Reports',
    'Reviews',
    'Account & Sign-in',
    'Notifications',
    'Other',
  ];

  /// Sends a problem with the app itself to the admin Bug Reports page.
  /// The database fills in the reporter and starts it as New / Medium.
  static Future<void> submitBug({
    required String area,
    required String title,
    required String description,
    Uint8List? screenshot,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    if (cleanTitle.isEmpty || cleanDescription.isEmpty) {
      throw const ReportsApiException(
        'Add a short title and describe what happened.',
      );
    }

    String? path;
    String? screenshotUrl;
    if (screenshot != null) {
      if (user == null) {
        throw const ReportsApiException('Sign in to attach a screenshot.');
      }
      final contentType = _contentType(screenshot);
      if (contentType == null) {
        throw const ReportsApiException('Use a JPEG, PNG, or WebP screenshot.');
      }
      if (screenshot.lengthInBytes > maxPhotoBytes) {
        throw const ReportsApiException(
          'The screenshot must be 700 KiB or smaller.',
        );
      }
      final extension = switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
      path = '${user.id}/bugs/${_uuidV4()}.$extension';
      final storage = client.storage.from(_bucket);
      try {
        await storage.uploadBinary(
          path,
          screenshot,
          fileOptions: FileOptions(contentType: contentType),
        );
      } on StorageException catch (error) {
        throw ReportsApiException(
          'Could not upload the screenshot: ${error.message}',
        );
      }
      screenshotUrl = storage.getPublicUrl(path);
    }

    try {
      await client.from('bug_reports').insert({
        'title': _limit(cleanTitle, 150),
        'description': _limit(cleanDescription, 2000),
        'area': bugAreas.contains(area) ? area : 'Other',
        'source': 'App',
        'device_info': _limit(_deviceInfo(), 255),
        'screenshot_url': screenshotUrl,
        'reporter_email': user?.email,
      });
    } on PostgrestException catch (error) {
      if (path != null) {
        try {
          await client.storage.from(_bucket).remove([path]);
        } on Exception {
          // A leftover screenshot is harmless.
        }
      }
      throw ReportsApiException(
        'Could not send the bug report: ${error.message}',
      );
    }
  }

  static String _deviceInfo() => kIsWeb
      ? 'NavAble web app'
      : 'NavAble app on ${Platform.operatingSystem} '
            '${Platform.operatingSystemVersion}';

  static String _limit(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String? _contentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }
}
