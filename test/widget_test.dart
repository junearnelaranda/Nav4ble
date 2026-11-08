// Screen tests that run without Supabase or the network. (The earlier tests
// here covered the pre-Supabase demo flows, which no longer exist.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/legal.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/splash.dart';
import 'package:navable/welcome.dart';

Widget _app(Widget home) => MaterialApp(
  theme: NavAbleTheme.light,
  darkTheme: NavAbleTheme.dark,
  home: home,
);

void main() {
  testWidgets('welcome links open the Terms and the Privacy Policy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const WelcomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text('What other users can see'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();
    expect(find.text('Using NavAble'), findsOneWidget);
  });

  testWidgets('the privacy policy says names are public on the leaderboard', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const LegalScreen(doc: LegalDoc.privacy)));
    expect(find.textContaining('Top Contributors leaderboard'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Read the Terms of Service'),
      300,
    );
    await tester.tap(find.text('Read the Terms of Service'));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsOneWidget); // app bar title
  });

  testWidgets('the splash moves on to the next screen', (tester) async {
    await tester.pumpWidget(
      _app(const SplashScreen(nextScreen: Text('Next screen'))),
    );
    expect(find.text('Next screen'), findsNothing);
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    expect(find.text('Next screen'), findsOneWidget);
  });
}
