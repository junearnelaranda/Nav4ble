import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/home.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/services/auth_service.dart';

Future<void> pumpProfile(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
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
}
