import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/widgets/navable_shell.dart';

final pageKey = GlobalKey();
final builtMenus = <bool>[];

Widget shell() => NavAbleShell(
  pageKey: pageKey,
  page: const Padding(
    padding: EdgeInsets.all(8),
    child: TextField(key: ValueKey('field')),
  ),
  appBar: AppBar(title: const Text('APP BAR')),
  bottomBar: const SizedBox(height: 60, child: Text('BOTTOM BAR')),
  sideMenu: (extended) {
    builtMenus.add(extended);
    return SizedBox(
      width: extended ? 220 : 80,
      child: Text(extended ? 'FULL MENU' : 'ICON MENU'),
    );
  },
);

Future<void> pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(home: shell()));
  await tester.pump();
}

void main() {
  setUp(builtMenus.clear);

  testWidgets('phone uses the app bar and bottom bar', (tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(tester, 390);
    expect(find.text('APP BAR'), findsOneWidget);
    expect(find.text('BOTTOM BAR'), findsOneWidget);
    expect(builtMenus, isEmpty);
  });

  testWidgets('compact uses the icon menu', (tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(tester, 800);
    expect(find.text('ICON MENU'), findsOneWidget);
    expect(find.text('APP BAR'), findsNothing);
    expect(find.text('BOTTOM BAR'), findsNothing);
  });

  testWidgets('wide uses the full menu', (tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(tester, 1440);
    expect(find.text('FULL MENU'), findsOneWidget);
    expect(find.text('APP BAR'), findsNothing);
  });

  testWidgets('typing survives resizing the window', (tester) async {
    addTearDown(tester.view.reset);
    await pumpAt(tester, 390);
    await tester.enterText(
      find.byKey(const ValueKey('field')),
      'Ramp at gate 2',
    );
    await pumpAt(tester, 1440);
    expect(find.text('Ramp at gate 2'), findsOneWidget);
    await pumpAt(tester, 800);
    expect(find.text('Ramp at gate 2'), findsOneWidget);
  });
}
