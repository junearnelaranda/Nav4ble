import 'package:flutter_test/flutter_test.dart';
import 'package:navable/main.dart';

void main() {
  testWidgets('opens the welcome and login flow', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('INITIALIZING...'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(MyApp)));
    await tester.pumpAndSettle();

    expect(
      find.text('Every Path Made Clear.\nEvery Destination\nReached.'),
      findsOneWidget,
    );
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);
  });
}
