import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ProfileStats {
  const ProfileStats({
    required this.contributionPoints,
    required this.reportCount,
    required this.savedPlaceCount,
  });

  final int? contributionPoints;
  final int? reportCount;
  final int? savedPlaceCount;
}

class ProfileStatsApi {
  ProfileStatsApi._();

  static const _projectId = 'nav4ble-22f2d';
  static const _documentsUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  static Future<ProfileStats> getCurrentUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const ProfileStats(
        contributionPoints: null,
        reportCount: null,
        savedPlaceCount: null,
      );
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      return const ProfileStats(
        contributionPoints: null,
        reportCount: null,
        savedPlaceCount: null,
      );
    }

    final results = await Future.wait([
      _countOwnedDocuments(
        collectionNames: const ['reports'],
        ownerFields: const ['submittedBy'],
        uid: user.uid,
        token: token,
      ),
      _countOwnedDocuments(
        collectionNames: const ['saved_Locations', 'saved_locations'],
        ownerFields: const ['userId', 'user_id', 'uid'],
        uid: user.uid,
        token: token,
      ),
      _getContributionPoints(user.uid, token),
    ]);
    return ProfileStats(
      reportCount: results[0],
      savedPlaceCount: results[1],
      contributionPoints: results[2],
    );
  }

  static Future<int?> _countOwnedDocuments({
    required List<String> collectionNames,
    required List<String> ownerFields,
    required String uid,
    required String token,
  }) async {
    for (final collection in collectionNames) {
      final documentNames = <String>{};
      var querySucceeded = false;
      for (final ownerField in ownerFields) {
        final documents = await _runQuery(
          collection: collection,
          ownerField: ownerField,
          uid: uid,
          token: token,
        );
        if (documents == null) continue;
        querySucceeded = true;
        documentNames.addAll(documents);
      }
      if (querySucceeded) return documentNames.length;
    }
    return null;
  }

  static Future<Set<String>?> _runQuery({
    required String collection,
    required String ownerField,
    required String uid,
    required String token,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_documentsUrl:runQuery'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'structuredQuery': {
                'from': [
                  {'collectionId': collection},
                ],
                'where': {
                  'fieldFilter': {
                    'field': {'fieldPath': ownerField},
                    'op': 'EQUAL',
                    'value': {'stringValue': uid},
                  },
                },
                'select': {
                  'fields': [
                    {'fieldPath': ownerField},
                  ],
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final body = jsonDecode(response.body);
      if (body is! List) return null;
      return body
          .whereType<Map>()
          .map((row) => row['document'])
          .whereType<Map>()
          .map((document) => document['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
    } on Exception {
      return null;
    }
  }

  static Future<int?> _getContributionPoints(String uid, String token) async {
    for (final collection in const ['user_profiles', 'users']) {
      try {
        final response = await http
            .get(
              Uri.parse('$_documentsUrl/$collection/$uid'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final body = jsonDecode(response.body);
        final fields = body is Map ? body['fields'] : null;
        if (fields is! Map) continue;
        for (final key in const [
          'contributionPoints',
          'contribution_points',
          'points',
        ]) {
          final value = fields[key];
          if (value is! Map) continue;
          final raw = value['integerValue'] ?? value['doubleValue'];
          if (raw is num) return raw.round();
          if (raw is String) return num.tryParse(raw)?.round();
        }
      } on Exception {
        continue;
      }
    }
    return null;
  }
}
