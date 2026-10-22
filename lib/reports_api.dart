import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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

class ReportsApi {
  ReportsApi._();

  static const String _workerUrl = String.fromEnvironment(
    'NAVABLE_REPORTS_API_URL',
  );
  static const _projectId = 'nav4ble-22f2d';
  static const _firestoreCommitUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:commit';
  static const maxPhotoBytes = 700 * 1024;
  static const _maxPhotos = 5;

  static Future<SubmittedReport> submit({
    required String title,
    required String detail,
    required String category,
    required String location,
    String? locationId,
    required List<Uint8List> photos,
    required PhotoAnalysis analysis,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ReportsApiException(
        'Sign in to submit an accessibility report.',
      );
    }
    _validatePhotos(photos);
    if (analysis.photoSuggestions.length != photos.length) {
      throw const ReportsApiException(
        'Scan the current photos before submitting the report.',
      );
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ReportsApiException(
        'Could not obtain a Firebase sign-in token.',
      );
    }

    final reportId = _newDocumentId();
    await _saveReport(
      reportId: reportId,
      userId: user.uid,
      token: token,
      title: title,
      detail: detail,
      category: category,
      location: location,
      locationId: locationId,
      photos: photos,
      suggestions: analysis.photoSuggestions,
      status: analysis.status,
    );

    return SubmittedReport(
      id: reportId,
      aiAnalysisStatus: analysis.status,
      detections: analysis.detections,
    );
  }

  static Future<PhotoAnalysis> analyzePhotos({
    required List<Uint8List> photos,
  }) async {
    _validatePhotos(photos);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ReportsApiException('Sign in to scan accessibility photos.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ReportsApiException(
        'Could not obtain a Firebase sign-in token.',
      );
    }
    if (_workerUrl.isEmpty) {
      return PhotoAnalysis.failedFor(
        photos.length,
        message:
            'AI scanning is not configured. You can still submit for admin review.',
      );
    }

    final suggestions = <Map<String, dynamic>>[];
    var failedAnalyses = 0;
    for (var index = 0; index < photos.length; index += 1) {
      try {
        suggestions.add({
          'photoIndex': index,
          ...await _analyzePhoto(photos[index], token),
        });
      } on ReportsApiException {
        failedAnalyses += 1;
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
          'Each photo must be 700 KiB or smaller to fit the Spark Firestore limit.',
        );
      }
    }
  }

  static Future<Map<String, dynamic>> _analyzePhoto(
    Uint8List photo,
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
            body: jsonEncode({
              'inputs': {
                'image': {'type': 'base64', 'value': base64Encode(photo)},
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
    } on Exception catch (error) {
      throw ReportsApiException('Could not reach Roboflow analysis: $error');
    }

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw ReportsApiException(
        'The analysis service returned an unreadable response (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map && body['error'] is Map
          ? body['error']['message'] as String?
          : null;
      throw ReportsApiException(
        message ?? 'Photo analysis failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
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

  static Future<void> _saveReport({
    required String reportId,
    required String userId,
    required String token,
    required String title,
    required String detail,
    required String category,
    required String location,
    required String? locationId,
    required List<Uint8List> photos,
    required List<Map<String, dynamic>> suggestions,
    required String status,
  }) async {
    final locationMatch = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(location);
    final latitude = locationMatch == null
        ? null
        : double.tryParse(locationMatch[1]!);
    final longitude = locationMatch == null
        ? null
        : double.tryParse(locationMatch[2]!);
    final now = DateTime.now().toUtc();
    final writes = <Map<String, dynamic>>[
      _createDocumentWrite('reports/$reportId', {
        'title': title,
        'detail': detail,
        'category': category,
        'location': location,
        'locationId': locationId,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'pending',
        'aiAnalysisStatus': status,
        'aiSuggestions': suggestions,
        'photoCount': photos.length,
        'photoIds': List<String>.generate(
          photos.length,
          (index) => 'photo_$index',
        ),
        'submittedBy': userId,
        'createdAt': now,
        'reviewedAt': null,
        'reviewedBy': null,
        'reviewNote': null,
      }),
    ];
    for (var index = 0; index < photos.length; index += 1) {
      writes.add(
        _createDocumentWrite('reports/$reportId/photos/photo_$index', {
          'photoBytes': photos[index],
          'contentType': _contentType(photos[index]),
          'detections': suggestions[index]['detections'],
          'image': suggestions[index]['image'],
          'photoIndex': index,
          'submittedBy': userId,
        }),
      );
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_firestoreCommitUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'writes': writes}),
          )
          .timeout(const Duration(seconds: 45));
    } on Exception catch (error) {
      throw ReportsApiException(
        'Could not save the report to Firestore: $error',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? message;
      try {
        final decoded = jsonDecode(response.body);
        final error = decoded is Map ? decoded['error'] : null;
        message = error is Map ? error['message'] as String? : null;
      } on Object {
        message = null;
      }
      throw ReportsApiException(
        message ??
            'Firestore could not save the report (HTTP ${response.statusCode}). Check your Firestore rules.',
        statusCode: response.statusCode,
      );
    }
  }

  static Map<String, dynamic> _createDocumentWrite(
    String documentPath,
    Map<String, dynamic> values,
  ) {
    return {
      'update': {
        'name':
            'projects/$_projectId/databases/(default)/documents/$documentPath',
        'fields': _firestoreFields(values),
      },
      'currentDocument': {'exists': false},
    };
  }

  static Map<String, dynamic> _firestoreFields(Map<String, dynamic> values) =>
      values.map((key, value) => MapEntry(key, _firestoreValue(value)));

  static Map<String, dynamic> _firestoreValue(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is Uint8List) return {'bytesValue': base64Encode(value)};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is num) return {'doubleValue': value.toDouble()};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is Map) {
      return {
        'mapValue': {
          'fields': _firestoreFields(Map<String, dynamic>.from(value)),
        },
      };
    }
    if (value is Iterable) {
      return {
        'arrayValue': {
          'values': value.map(_firestoreValue).toList(growable: false),
        },
      };
    }
    throw ReportsApiException(
      'Cannot save unsupported Firestore value: ${value.runtimeType}.',
    );
  }

  static String _newDocumentId() {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List<String>.generate(
      20,
      (_) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
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
