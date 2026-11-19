import 'package:flutter_test/flutter_test.dart';
import 'package:navable/alerts_filter.dart';

void main() {
  test('labels', () {
    expect(AlertFilter.values.map((f) => f.label), [
      'All',
      'Reports',
      'Points',
    ]);
  });

  test('report cards show for All and Reports only', () {
    expect(showsReportCards(AlertFilter.all), isTrue);
    expect(showsReportCards(AlertFilter.reports), isTrue);
    expect(showsReportCards(AlertFilter.points), isFalse);
  });

  const types = [
    'Report Update',
    'Points',
    'Level Up',
    'System Announcement',
    'Accessibility Update',
  ];

  test('All matches every alert', () {
    for (final type in types) {
      expect(alertMatches(AlertFilter.all, type), isTrue, reason: type);
    }
  });

  test('Reports matches report updates only', () {
    expect(
      [
        for (final type in types)
          if (alertMatches(AlertFilter.reports, type)) type,
      ],
      ['Report Update'],
    );
  });

  test('Points matches points and level ups only', () {
    expect(
      [
        for (final type in types)
          if (alertMatches(AlertFilter.points, type)) type,
      ],
      ['Points', 'Level Up'],
    );
  });
}
