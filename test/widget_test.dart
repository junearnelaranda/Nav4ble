import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/main.dart';

void main() {
  testWidgets('opens welcome, login, and home flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    expect(
      find.text('Every Path Made Clear.\nEvery Destination Reached.'),
      findsOneWidget,
    );
    expect(find.text('Get Started'), findsOneWidget);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'june@example.com'),
      'demo@navable.app',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '********'),
      'password123',
    );
    await tester.tap(find.text('Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    expect(find.text('Route Planner'), findsOneWidget);
    expect(find.text('Nearby Accessibility Reports'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Where are you going?'),
      'Museum',
    );
    await tester.tap(find.text('Plan Accessible Route'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Route to Museum ready'), findsOneWidget);
    await tester.tap(find.text('View Route Details'));
    await tester.pumpAndSettle();

    expect(find.text('Route Details'), findsOneWidget);
    expect(find.text('Step-Free Directions'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Accessibility Reports'), findsOneWidget);
    await tester.tap(find.text('Market Street crossing'));
    await tester.pumpAndSettle();

    expect(find.text('Report Details'), findsOneWidget);
    await tester.tap(find.text('Confirm Report'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Places'), findsOneWidget);
    await tester.tap(find.text('Central Station'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Place'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
  });
}
