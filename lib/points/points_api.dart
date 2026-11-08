import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_picture.dart';
import 'levels.dart';

export 'levels.dart';

class PointsApiException implements Exception {
  const PointsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum LeaderboardPeriod {
  month,
  all;

  /// The value the database functions expect.
  String get wire => this == month ? 'month' : 'all';
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.fullName,
    required this.picture,
    required this.points,
    required this.level,
    required this.levelName,
  });

  final int rank;
  final String userId;
  final String fullName;
  final Uint8List? picture;
  final int points;
  final int level;
  final String levelName;

  /// Null when the row is missing its rank or user.
  static LeaderboardEntry? fromRow(Map<String, dynamic> row) {
    final rank = row['rank'];
    final userId = row['user_id'];
    if (rank is! num || userId is! String) return null;
    return LeaderboardEntry(
      rank: rank.toInt(),
      userId: userId,
      fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? (row['full_name'] as String).trim()
          : 'NavAble contributor',
      picture: ProfilePicture.decode(row['profile_picture'] as String?),
      points: (row['points'] as num?)?.toInt() ?? 0,
      level: (row['level'] as num?)?.toInt() ?? 0,
      levelName: row['level_name'] as String? ?? 'Newcomer',
    );
  }
}

/// The signed-in user's place for a period. [points] and [rank] belong to
/// the period; [progress] is always from lifetime points.
class MyStanding {
  const MyStanding({
    required this.rank,
    required this.points,
    required this.progress,
  });

  factory MyStanding.fromRow(
    Map<String, dynamic> row, {
    required int lifetimePoints,
    List<ContributorLevel> levels = ContributorLevel.defaults,
  }) => MyStanding(
    rank: (row['rank'] as num?)?.toInt(),
    points: (row['points'] as num?)?.toInt() ?? 0,
    progress: progressFor(lifetimePoints, levels),
  );

  /// Null when the user has no points in the period.
  final int? rank;
  final int points;
  final LevelProgress progress;
}

class PointsAward {
  const PointsAward({
    required this.points,
    required this.tier,
    required this.sourceType,
    required this.placeName,
    required this.createdAt,
  });

  final int points;
  final String tier;

  /// 'Report' or 'Review'.
  final String sourceType;
  final String placeName;
  final DateTime createdAt;

  static PointsAward? fromRow(Map<String, dynamic> row) {
    final points = row['points'];
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (points is! num || created == null) return null;
    final source = row['source_type'] as String? ?? 'Report';
    final parent = row[source == 'Review' ? 'reviews' : 'reports'];
    final location = parent is Map ? parent['locations'] : null;
    final name = location is Map ? location['location_name'] : null;
    return PointsAward(
      points: points.toInt(),
      tier: row['tier'] as String? ?? 'Custom',
      sourceType: source,
      placeName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'a place',
      createdAt: created.toLocal(),
    );
  }
}

/// A report or review still waiting for an admin.
class PendingContribution {
  const PendingContribution({
    required this.kind,
    required this.placeName,
    required this.createdAt,
  });

  /// 'Report' or 'Review'.
  final String kind;
  final String placeName;
  final DateTime createdAt;
}

class AppAlert {
  const AppAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;

  /// 'Points', 'Level Up', 'Report Update', and so on.
  final String type;
  final bool isRead;
  final DateTime createdAt;

  static AppAlert? fromRow(Map<String, dynamic> row) {
    final id = row['notification_id'];
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (id is! String || created == null) return null;
    return AppAlert(
      id: id,
      title: row['title'] as String? ?? '',
      message: row['message'] as String? ?? '',
      type: row['notification_type'] as String? ?? '',
      isRead: row['is_read'] == true,
      createdAt: created.toLocal(),
    );
  }
}

/// Reads contributor points, levels, the leaderboard and alerts.
abstract final class PointsApi {
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _me => _client.auth.currentUser?.id;

  static Future<T> _guard<T>(Future<T> Function() run, String message) async {
    try {
      return await run();
    } on PostgrestException {
      throw PointsApiException(message);
    } on Exception {
      throw PointsApiException(message);
    }
  }

  /// Level thresholds; the built-in defaults if they can't be loaded.
  static Future<List<ContributorLevel>> levels() async {
    try {
      final rows = await _client
          .from('contributor_levels')
          .select('level, name, min_points')
          .order('level');
      final levels = [for (final row in rows) ContributorLevel.fromRow(row)];
      return levels.isEmpty ? ContributorLevel.defaults : levels;
    } catch (_) {
      return ContributorLevel.defaults;
    }
  }

  static Future<List<LeaderboardEntry>> leaderboard(
    LeaderboardPeriod period, {
    int maxRows = 20,
  }) => _guard(() async {
    final rows = await _client.rpc(
      'get_leaderboard',
      params: {'period': period.wire, 'max_rows': maxRows},
    );
    return [
      for (final row in (rows as List).whereType<Map>())
        ?LeaderboardEntry.fromRow(Map<String, dynamic>.from(row)),
    ];
  }, "Couldn't load the leaderboard");

  /// Null for guests.
  static Future<MyStanding?> myStanding(LeaderboardPeriod period) async {
    if (_me == null) return null;
    return _guard(() async {
      Future<Map<String, dynamic>?> standing(LeaderboardPeriod p) async {
        final rows = await _client.rpc(
          'get_my_standing',
          params: {'period': p.wire},
        );
        final list = (rows as List).whereType<Map>().toList();
        return list.isEmpty ? null : Map<String, dynamic>.from(list.first);
      }

      // Started together; the progress bar needs lifetime points even
      // when the period is this month.
      final periodRow = standing(period);
      final lifetimeRow = period == LeaderboardPeriod.all
          ? periodRow
          : standing(LeaderboardPeriod.all);
      final levelList = levels();
      final row = await periodRow;
      final lifetime = await lifetimeRow;
      final thresholds = await levelList;
      if (row == null) return null;
      return MyStanding.fromRow(
        row,
        lifetimePoints: (lifetime?['points'] as num?)?.toInt() ?? 0,
        levels: thresholds,
      );
    }, 'Points unavailable right now');
  }

  /// The signed-in user's awards, newest first.
  static Future<List<PointsAward>> myAwards() async {
    final me = _me;
    if (me == null) return const [];
    return _guard(() async {
      final rows = await _client
          .from('contribution_points')
          .select(
            'points, tier, source_type, created_at, '
            'reports(locations(location_name)), '
            'reviews(locations(location_name))',
          )
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(50);
      return [for (final row in rows) ?PointsAward.fromRow(row)];
    }, 'Points unavailable right now');
  }

  /// Reports and reviews still waiting for an admin, with no award yet.
  static Future<List<PendingContribution>> myPending() async {
    final me = _me;
    if (me == null) return const [];
    return _guard(() async {
      // One source failing (for example no read access) still shows the other.
      Future<List<Map<String, dynamic>>> safe(
        Future<List<Map<String, dynamic>>> query,
      ) => query.catchError((Object _) => <Map<String, dynamic>>[]);
      final results = await Future.wait([
        safe(
          _client
              .from('reports')
              .select(
                'created_at, locations(location_name), contribution_points(point_id)',
              )
              .eq('user_id', me)
              .eq('status', 'Pending'),
        ),
        safe(
          _client
              .from('reviews')
              .select(
                'review_date, locations(location_name), contribution_points(point_id)',
              )
              .eq('user_id', me)
              .eq('review_status', 'Pending Review'),
        ),
      ]);
      PendingContribution? pending(Map row, String kind, String dateKey) {
        final awards = row['contribution_points'];
        if (awards is List && awards.isNotEmpty) return null;
        if (awards is Map) return null;
        final created = DateTime.tryParse(row[dateKey]?.toString() ?? '');
        final location = row['locations'];
        final name = location is Map ? location['location_name'] : null;
        return PendingContribution(
          kind: kind,
          placeName: name is String && name.trim().isNotEmpty
              ? name.trim()
              : 'a place',
          createdAt: (created ?? DateTime.now()).toLocal(),
        );
      }

      return [
        for (final row in results[0]) ?pending(row, 'Report', 'created_at'),
        for (final row in results[1]) ?pending(row, 'Review', 'review_date'),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }, 'Points unavailable right now');
  }

  static Future<List<AppAlert>> myAlerts() async {
    final me = _me;
    if (me == null) return const [];
    return _guard(() async {
      final rows = await _client
          .from('notifications')
          .select(
            'notification_id, title, message, notification_type, is_read, created_at',
          )
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(50);
      return [for (final row in rows) ?AppAlert.fromRow(row)];
    }, "Couldn't load your alerts");
  }

  static Future<void> markAlertsRead() async {
    final me = _me;
    if (me == null) return;
    await _guard(
      () => _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', me)
          .eq('is_read', false),
      "Couldn't update your alerts",
    );
  }
}
