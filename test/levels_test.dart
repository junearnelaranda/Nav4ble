import 'package:flutter_test/flutter_test.dart';
import 'package:navable/points/levels.dart';

void main() {
  const levels = ContributorLevel.defaults;

  test('newcomer below 30', () {
    final p = progressFor(0, levels);
    expect(
      [p.level, p.name, p.next!.name, p.pointsToNext],
      [0, 'Newcomer', 'Explorer', 30],
    );
    expect(p.fraction, 0);
    expect(progressFor(29, levels).level, 0);
  });

  test('exact thresholds reach the level', () {
    expect([30, 100, 300, 750, 1500].map((v) => progressFor(v, levels).name), [
      'Explorer',
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
    ]);
  });

  test('progress between levels', () {
    final p = progressFor(420, levels);
    expect(
      [p.level, p.name, p.next!.name, p.pointsToNext],
      [3, 'Silver', 'Gold', 330],
    );
    expect(p.fraction, closeTo(120 / 450, 1e-9));
  });

  test('top level', () {
    final p = progressFor(5000, levels);
    expect([p.isTop, p.next, p.pointsToNext, p.fraction], [true, null, 0, 1.0]);
  });

  test('unsorted or edited thresholds', () {
    final edited = levels.reversed
        .map(
          (l) => l.level == 4
              ? const ContributorLevel(level: 4, name: 'Gold', minPoints: 1000)
              : l,
        )
        .toList();
    expect(progressFor(800, edited).name, 'Silver');
  });

  test('levels read from database rows', () {
    final l = ContributorLevel.fromRow({
      'level': 2,
      'name': 'Bronze',
      'min_points': 100,
    });
    expect([l.level, l.name, l.minPoints], [2, 'Bronze', 100]);
  });

  test('badge for each level number', () {
    expect(List.generate(6, badgeFor), LevelBadge.values);
    expect(badgeFor(9), LevelBadge.platinum);
  });
}
