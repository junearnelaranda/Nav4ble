import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/home.dart';
import 'package:navable/main.dart';
import 'package:navable/login.dart';
import 'package:navable/register.dart';

void main() {
  testWidgets('guest can search, inspect accessibility, and navigate', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Continue as a Guest'), findsOneWidget);
    expect(
      find.text(
        'Search  →  View place  →  Check accessibility  →  Navigate',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue as a Guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Alerts'), findsNothing);
    expect(find.text('Profile'), findsNothing);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Figaro');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Figaro Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Place Details'), findsOneWidget);
    expect(find.text('Accessibility'), findsOneWidget);
    expect(find.text('Braille'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);

    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Route to Figaro Coffee ready'), findsOneWidget);
  });

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

    final loginFields = find.byType(TextField);
    expect(
      tester.widget<TextField>(loginFields.at(0)).controller?.text,
      'june@gmail.com',
    );
    expect(
      tester.widget<TextField>(loginFields.at(1)).controller?.text,
      'june1234',
    );
    await tester.tap(find.text('Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    expect(find.text('Nearby Accessible Places'), findsOneWidget);
    expect(find.text('Start Navigation'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Where would you like to go?'),
      'Museum',
    );
    await tester.tap(find.text('Start Navigation'));
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

    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Issue Location'), findsOneWidget);
    expect(find.text('Issue Category'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Market Street crossing'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Market Street crossing'));
    await tester.pumpAndSettle();

    expect(find.text('Report Details'), findsOneWidget);
    await tester.tap(find.text('Confirm Report'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Verification Approved'), findsOneWidget);
    expect(find.text('Nearby Accessibility Updates'), findsOneWidget);
    expect(find.text('Verification Rejected'), findsOneWidget);
    expect(find.text('Admin Feedback'), findsOneWidget);
    await tester.tap(find.text('View Badge'));
    await tester.pumpAndSettle();
    expect(find.text('Community Verifier'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Saved places'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Places'), findsOneWidget);
    await tester.tap(find.text('Central Station'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Place'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('June'), findsOneWidget);
    expect(find.text('june@gmail.com'), findsOneWidget);

    await tester.ensureVisible(find.text('Accessibility Settings'));
    await tester.tap(find.text('Accessibility Settings'));
    await tester.pumpAndSettle();
    expect(find.text('GENERAL SETTINGS'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Text Size'), findsOneWidget);

    await tester.ensureVisible(find.text('My Submissions'));
    await tester.tap(find.text('My Submissions'));
    await tester.pumpAndSettle();
    expect(find.text('My Submissions'), findsOneWidget);
    expect(find.text('Pending (2)'), findsOneWidget);
    expect(find.text('Central Station Elevator'), findsOneWidget);
    await tester.tap(find.text('Approved (8)'));
    await tester.pumpAndSettle();
    expect(find.text('Main Street Ramp'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Log Out'));
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Edit profile'));
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsWidgets);
    expect(find.text('Add Profile Photo'), findsOneWidget);
    await tester.tap(find.text('Add Profile Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Take a Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('validates registration and creates an account', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Confirm your password.'), findsOneWidget);
    expect(
      find.text('Accept the terms to create your account.'),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alex Rider');
    await tester.enterText(fields.at(1), 'alex.rider@example.com');
    await tester.enterText(fields.at(2), 'accessible123');
    await tester.enterText(fields.at(3), 'accessible123');
    await tester.tap(find.byType(Checkbox));

    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    expect(find.text('Nearby Accessible Places'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Rider'), findsOneWidget);
    expect(find.text('alex.rider@example.com'), findsOneWidget);
  });

  testWidgets('home map placeholder fits a phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Where would you like to go?'), findsOneWidget);
    expect(find.text('Nearby Accessible Places'), findsOneWidget);
    expect(find.text('Start Navigation'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);

    final locationRight = tester.getTopRight(find.byTooltip('My location')).dx;
    for (final tooltip in [
      'Saved places',
      'Report a barrier',
      'Scan accessibility code',
    ]) {
      expect(
        tester.getTopRight(find.byTooltip(tooltip)).dx,
        closeTo(locationRight, 0.1),
      );
    }

    final shortcutList = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(shortcutList, findsOneWidget);
    expect(find.text('Audio Assistance'), findsOneWidget);
    await tester.drag(shortcutList, const Offset(-260, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Route filters'));
    await tester.pumpAndSettle();

    expect(find.text('Accessibility Filters'), findsOneWidget);
    expect(find.text('Wheelchair Ramp'), findsOneWidget);
    expect(find.text('Accessible Entrance'), findsOneWidget);
    expect(find.text('Audio Assistance'), findsNWidgets(2));

    await tester.tap(find.text('Clear All'));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);

    await tester.tap(find.text('Wheelchair Ramp'));
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Accessibility Filters'), findsNothing);
    expect(find.text('Accessibility filters applied.'), findsOneWidget);
  });

  testWidgets('explore shows and searches local demo places', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.text('3 demo places'), findsOneWidget);
    expect(find.text('Abaca Baking Company'), findsOneWidget);
    expect(find.text('Figaro Coffee'), findsOneWidget);
    expect(find.text("Bo's Coffee"), findsOneWidget);
    expect(find.text('DEMO'), findsNWidgets(3));

    final searchField = find.byType(TextField);
    expect(
      tester.widget<TextField>(searchField).controller?.text,
      'Cafe near Ayala Center Cebu',
    );
    await tester.enterText(searchField, 'Figaro');
    await tester.pumpAndSettle();

    expect(find.text('1 demo place'), findsOneWidget);
    expect(find.text('Figaro Coffee'), findsOneWidget);
    expect(find.text('Abaca Baking Company'), findsNothing);
  });
}
