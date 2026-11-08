/// Contributor levels and the math behind them. No I/O: the thresholds come
/// from the `contributor_levels` table (or [ContributorLevel.defaults]).
class ContributorLevel {
  const ContributorLevel({
    required this.level,
    required this.name,
    required this.minPoints,
  });

  factory ContributorLevel.fromRow(Map<String, dynamic> row) =>
      ContributorLevel(
        level: (row['level'] as num).toInt(),
        name: row['name'] as String,
        minPoints: (row['min_points'] as num).toInt(),
      );

  /// Level number, 1 (Explorer) to 5 (Platinum).
  final int level;
  final String name;

  /// Lifetime points needed to reach this level.
  final int minPoints;

  /// The levels the database starts with.
  static const defaults = [
    ContributorLevel(level: 1, name: 'Explorer', minPoints: 30),
    ContributorLevel(level: 2, name: 'Bronze', minPoints: 100),
    ContributorLevel(level: 3, name: 'Silver', minPoints: 300),
    ContributorLevel(level: 4, name: 'Gold', minPoints: 750),
    ContributorLevel(level: 5, name: 'Platinum', minPoints: 1500),
  ];
}

/// Where a lifetime points total stands: level, and progress to the next.
class LevelProgress {
  const LevelProgress({
    required this.points,
    required this.level,
    required this.name,
    required this.next,
    required this.pointsToNext,
    required this.fraction,
  });

  final int points;

  /// 0 for Newcomer, otherwise 1–5.
  final int level;
  final String name;

  /// The level after this one; null at the top level.
  final ContributorLevel? next;
  final int pointsToNext;

  /// 0..1 of the way from this level's threshold (0 for Newcomer) to the
  /// next; 1 at the top level.
  final double fraction;

  bool get isTop => next == null;
}

/// Level and progress for [points] lifetime points.
LevelProgress progressFor(int points, List<ContributorLevel> levels) {
  final sorted = [...levels]
    ..sort((a, b) => a.minPoints.compareTo(b.minPoints));
  ContributorLevel? current;
  ContributorLevel? next;
  for (final level in sorted) {
    if (level.minPoints <= points) {
      current = level;
    } else {
      next = level;
      break;
    }
  }
  if (next == null) {
    return LevelProgress(
      points: points,
      level: current?.level ?? 0,
      name: current?.name ?? 'Newcomer',
      next: null,
      pointsToNext: 0,
      fraction: 1,
    );
  }
  final from = current?.minPoints ?? 0;
  final span = next.minPoints - from;
  return LevelProgress(
    points: points,
    level: current?.level ?? 0,
    name: current?.name ?? 'Newcomer',
    next: next,
    pointsToNext: next.minPoints - points,
    fraction: span <= 0 ? 0 : ((points - from) / span).clamp(0.0, 1.0),
  );
}

/// Badge style per level, so the UI picks colors in one place.
enum LevelBadge { newcomer, explorer, bronze, silver, gold, platinum }

LevelBadge badgeFor(int level) =>
    LevelBadge.values[level.clamp(0, LevelBadge.values.length - 1)];
