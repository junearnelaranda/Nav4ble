import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/home.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/services/auth_service.dart';

Future<void> pumpProfile(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  VoidCallback? onReportPlace,
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
          body: ProfilePage(
            user: const NavAbleUser(
              fullName: 'June Arnel Aranda',
              email: 'june@example.com',
            ),
            contributionPoints: 120,
            reportCount: 6,
            savedPlaceCount: 3,
            statsLoading: false,
            submissions: const [],
            onEditProfile: () {},
            onOpenInfo: (_, _) {},
            onSignOut: () {},
            onReportPlace: onReportPlace ?? () {},
            pointsSection: const SizedBox(
              height: 220,
              child: Center(child: Text('POINTS SECTION')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('phone keeps one column', (tester) async {
    await pumpProfile(tester, width: 390);
    final edit = tester.getRect(find.text('Edit Profile'));
    final settings = tester.getRect(find.text('Accessibility Settings'));
    expect(settings.top, greaterThan(edit.bottom));
    expect(
      tester.getTopLeft(find.text('POINTS SECTION')).dy,
      lessThan(edit.top),
    );
  });

  testWidgets('PC puts the profile card on the left', (tester) async {
    await pumpProfile(tester, width: 1440);
    final edit = tester.getRect(find.text('Edit Profile'));
    final settings = tester.getRect(find.text('Accessibility Settings'));
    final points = tester.getRect(find.text('POINTS SECTION'));
    expect(settings.left, greaterThan(edit.right));
    expect(points.left, greaterThan(edit.right));
    expect(
      tester.getSize(find.byKey(const ValueKey('profile-card'))).width,
      320,
    );
  });

  testWidgets('PC caps the width', (tester) async {
    await pumpProfile(tester, width: 1920);
    final card = tester.getRect(find.byKey(const ValueKey('profile-card')));
    final settings = tester.getRect(find.text('Accessibility Settings'));
    expect(settings.right - card.left, lessThanOrEqualTo(1100));
  });

  for (final width in const [640.0, 1000.0]) {
    testWidgets('no overflow at $width px with large text', (tester) async {
      await pumpProfile(tester, width: width, textScale: 1.2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Offline Maps is gone from the menu', (tester) async {
    await pumpProfile(tester, width: 390);
    expect(find.text('Offline Maps'), findsNothing);
    expect(find.text('Help & Support'), findsOneWidget);
  });

  testWidgets('Help & Support opens a page with ways to get help', (
    tester,
  ) async {
    await pumpProfile(tester, width: 390);
    await tester.ensureVisible(find.text('Help & Support'));
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    expect(find.text('How can we help?'), findsOneWidget);
    expect(find.text('Report a bug in the app'), findsOneWidget);
    expect(find.text('Report a problem at a place'), findsOneWidget);
    expect(find.text('Email the NavAble team'), findsOneWidget);
    expect(find.text('Common questions'), findsOneWidget);
  });

  testWidgets('Help: reporting a place problem goes to Reports', (
    tester,
  ) async {
    var opened = 0;
    await pumpProfile(tester, width: 390, onReportPlace: () => opened++);
    await tester.ensureVisible(find.text('Help & Support'));
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report a problem at a place'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('How can we help?'), findsNothing);
  });

  testWidgets('Help: a common question opens its answer', (tester) async {
    await pumpProfile(tester, width: 390);
    await tester.ensureVisible(find.text('Help & Support'));
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    final question = find.text('Do I need an internet connection?');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.textContaining('needs an internet connection'), findsOneWidget);
  });

  for (final width in const [390.0, 1440.0]) {
    testWidgets('Help page has no overflow at $width px, large text', (
      tester,
    ) async {
      await pumpProfile(tester, width: width, textScale: 1.3);
      await tester.ensureVisible(find.text('Help & Support'));
      await tester.tap(find.text('Help & Support'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
