import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/home.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/reports_api.dart';

final reports = [
  for (var i = 0; i < 7; i++)
    MyReport(
      id: 'r$i',
      title: 'Report $i',
      detail: 'Detail $i',
      category: 'Accessible ramp',
      placeName: 'Place $i',
      status: ReportStatus.pending,
      createdAt: DateTime(2026, 11, 19 - i),
    ),
];

Future<int> pumpReports(
  WidgetTester tester, {
  required double width,
  ReportKind? kind,
  double textScale = 1,
  void Function()? onOpenContributions,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: NavAbleTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: ReportsPage(
            reports: reports,
            locations: const [],
            initialLocation: null,
            photoCaptureRequestId: 0,
            onPhotoCaptureRequestHandled: () {},
            onAnalyzePhotos: (_) async => throw UnimplementedError(),
            onSubmitReport: (_, _) async => false,
            onBackToHome: () {},
            onOpenContributions: onOpenContributions ?? () {},
            initialKind: kind,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return 0;
}

int shownReports(WidgetTester tester) => [
  for (var i = 0; i < 7; i++)
    if (find.text('Report $i').evaluate().isNotEmpty) i,
].length;

void main() {
  testWidgets('phone keeps the choices in one column', (tester) async {
    await pumpReports(tester, width: 390);
    final contribute = tester.getRect(find.text('Contribute Accessibility'));
    final issue = tester.getRect(find.text('Report an Issue'));
    expect(issue.top, greaterThan(contribute.bottom));
  });

  testWidgets('phone keeps the map between the fields', (tester) async {
    await pumpReports(tester, width: 390, kind: ReportKind.feature);
    final location = tester.getRect(find.text('Location'));
    final type = tester.getRect(find.text('Feature Type'));
    expect(type.top, greaterThan(location.bottom));
    expect(type.left, location.left);
  });

  testWidgets('PC shows the choices side by side', (tester) async {
    await pumpReports(tester, width: 1440);
    expect(
      tester.getTopLeft(find.text('Report an Issue')).dy,
      tester.getTopLeft(find.text('Contribute Accessibility')).dy,
    );
  });

  testWidgets('PC form has the map on the right', (tester) async {
    await pumpReports(tester, width: 1440, kind: ReportKind.feature);
    final location = tester.getRect(find.text('Location'));
    final type = tester.getRect(find.text('Feature Type'));
    expect(location.left, greaterThan(type.right));
  });

  testWidgets('PC shows five recent submissions and a link', (tester) async {
    var opened = 0;
    await pumpReports(
      tester,
      width: 1440,
      kind: ReportKind.feature,
      onOpenContributions: () => opened++,
    );
    expect(shownReports(tester), 5);
    await tester.ensureVisible(find.text('See all submissions'));
    await tester.tap(find.text('See all submissions'));
    expect(opened, 1);
  });

  for (final width in const [640.0, 1000.0]) {
    for (final kind in const [null, ReportKind.feature]) {
      testWidgets('no overflow at $width px, ${kind ?? 'choices'}', (
        tester,
      ) async {
        await pumpReports(tester, width: width, kind: kind, textScale: 1.2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('narrow wide form keeps Location above Submit', (tester) async {
    // 680 px window: the form's columns stack, so Location must come first.
    await pumpReports(tester, width: 680, kind: ReportKind.feature);
    final location = tester.getRect(find.text('Location'));
    final submit = tester.getRect(find.textContaining('Submit').first);
    expect(location.top, lessThan(submit.top));
  });

  testWidgets('report map keeps its pin when the window resizes', (
    tester,
  ) async {
    final map = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_ReportMapPlaceholder',
    );
    await pumpReports(tester, width: 390, kind: ReportKind.feature);
    final before = tester.state(map);
    await pumpReports(tester, width: 1440, kind: ReportKind.feature);
    expect(identical(tester.state(map), before), isTrue);
  });
}
