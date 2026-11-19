import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/home.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/points/points_api.dart';
import 'package:navable/reports_api.dart';

final twoReports = [
  for (var i = 0; i < 2; i++)
    MyReport(
      id: 'r$i',
      title: 'Ramp report $i',
      detail: '',
      category: 'Accessible ramp',
      placeName: 'Place $i',
      status: ReportStatus.pending,
      createdAt: DateTime(2026, 11, 18),
    ),
];

final threeAlerts = [
  for (final (title, type) in const [
    ('Points earned', 'Points'),
    ('Level reached', 'Level Up'),
    ('Maintenance notice', 'System Announcement'),
  ])
    AppAlert(
      id: title,
      title: title,
      message: 'Message for $title',
      type: type,
      isRead: false,
      createdAt: DateTime(2026, 11, 18),
    ),
];

Future<void> pumpAlerts(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
  List<MyReport>? reports,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: NavAbleTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1400),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: AlertsPage(
            reports: reports ?? twoReports,
            alerts: threeAlerts,
            onOpenReports: () {},
          ),
        ),
      ),
    ),
  );
}

int visibleCards() => [
  for (final text in [
    'Ramp report 0',
    'Ramp report 1',
    'Points earned',
    'Level reached',
    'Maintenance notice',
  ])
    if (find.textContaining(text).evaluate().isNotEmpty) text,
].length;

Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

void main() {
  testWidgets('filters show on every size', (tester) async {
    await pumpAlerts(tester);
    expect(chip('All'), findsOneWidget);
    expect(chip('Reports'), findsOneWidget);
    expect(chip('Points'), findsOneWidget);
  });

  testWidgets('All shows everything', (tester) async {
    await pumpAlerts(tester);
    expect(visibleCards(), 5);
  });

  testWidgets('Reports filter shows report updates only', (tester) async {
    await pumpAlerts(tester);
    await tester.tap(chip('Reports'));
    await tester.pump();
    expect(find.textContaining('Ramp report 0'), findsOneWidget);
    expect(find.textContaining('Ramp report 1'), findsOneWidget);
    expect(visibleCards(), 2);
  });

  testWidgets('Points filter shows points and level ups only', (tester) async {
    await pumpAlerts(tester);
    await tester.tap(chip('Points'));
    await tester.pump();
    expect(find.text('Points earned'), findsOneWidget);
    expect(find.text('Level reached'), findsOneWidget);
    expect(visibleCards(), 2);
  });

  testWidgets('an empty filter says so', (tester) async {
    await pumpAlerts(tester, reports: const []);
    await tester.tap(chip('Reports'));
    await tester.pump();
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('PC caps the width and centers the list', (tester) async {
    await pumpAlerts(tester, width: 1440);
    final heading = tester.getRect(find.text('Alerts'));
    expect(heading.left, greaterThanOrEqualTo((1440 - 760) / 2));
  });

  for (final width in const [640.0, 1000.0]) {
    testWidgets('no overflow at $width px with large text', (tester) async {
      await pumpAlerts(tester, width: width, textScale: 1.2);
      expect(tester.takeException(), isNull);
    });
  }
}
