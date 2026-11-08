import 'package:flutter_test/flutter_test.dart';
import 'package:navable/points/points_api.dart';

void main() {
  test('leaderboard row', () {
    final e = LeaderboardEntry.fromRow({
      'rank': 1,
      'user_id': 'u1',
      'full_name': 'Maria Reyes',
      'profile_picture': null,
      'points': 320,
      'level': 3,
      'level_name': 'Silver',
    })!;
    expect(
      [e.rank, e.fullName, e.points, e.levelName, e.picture],
      [1, 'Maria Reyes', 320, 'Silver', null],
    );
    expect(LeaderboardEntry.fromRow({'full_name': 'x'}), isNull);
  });

  test('award row takes the place from a report or a review', () {
    final r = PointsAward.fromRow({
      'points': 10,
      'tier': 'Regular',
      'source_type': 'Report',
      'created_at': '2026-11-07T03:00:00Z',
      'reports': {
        'locations': {'location_name': 'Ayala Center Cebu'},
      },
    })!;
    expect([r.points, r.placeName], [10, 'Ayala Center Cebu']);
    final v = PointsAward.fromRow({
      'points': 25,
      'tier': 'Big',
      'source_type': 'Review',
      'created_at': '2026-11-07T03:00:00Z',
      'reviews': null,
    })!;
    expect(v.placeName, 'a place');
  });

  test('alert row', () {
    final a = AppAlert.fromRow({
      'notification_id': 'n1',
      'title': '+10 points',
      'message': 'For your report at X',
      'notification_type': 'Points',
      'is_read': false,
      'created_at': '2026-11-07T03:00:00Z',
    })!;
    expect([a.type, a.isRead], ['Points', false]);
  });

  test('period wire values', () {
    expect(LeaderboardPeriod.values.map((p) => p.wire), ['month', 'all']);
  });

  test('standing row with no points this month has no rank', () {
    final s = MyStanding.fromRow({
      'rank': null,
      'points': 0,
      'level': 1,
      'level_name': 'Explorer',
      'next_level_name': 'Bronze',
      'next_level_min_points': 100,
    }, lifetimePoints: 40);
    expect(s.rank, isNull);
    expect(
      [s.points, s.progress.name, s.progress.next!.name],
      [0, 'Explorer', 'Bronze'],
    );
  });
}
