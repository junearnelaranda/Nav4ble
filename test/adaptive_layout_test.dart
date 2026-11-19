import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/widgets/adaptive_layout.dart';

Future<void> pumpAt(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double height = 900,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

const startKey = ValueKey('start');
const endKey = ValueKey('end');

Widget twoColumns({double? startWidth}) => TwoColumns(
  startWidth: startWidth,
  start: Container(key: startKey, height: 80, color: Colors.green),
  end: Container(key: endKey, height: 80, color: Colors.blue),
);

List<Widget> cards() => [
  for (var i = 0; i < 7; i++)
    Container(key: ValueKey('card-$i'), height: 60, color: Colors.grey),
];

void main() {
  test('screen size thresholds', () {
    expect(screenSizeFor(639), ScreenSize.phone);
    expect(screenSizeFor(640), ScreenSize.compact);
    expect(screenSizeFor(999), ScreenSize.compact);
    expect(screenSizeFor(1000), ScreenSize.wide);
  });

  testWidgets('screenSize reads the window width', (tester) async {
    late ScreenSize seen;
    await pumpAt(
      tester,
      Builder(
        builder: (context) {
          seen = context.screenSize;
          return const SizedBox();
        },
      ),
      width: 1440,
    );
    expect(seen, ScreenSize.wide);
  });

  testWidgets('PageWidth caps the width on a big screen', (tester) async {
    await pumpAt(
      tester,
      const PageWidth(
        maxWidth: 760,
        child: SizedBox(key: startKey, height: 10, width: double.infinity),
      ),
      width: 1440,
    );
    expect(tester.getSize(find.byKey(startKey)).width, 760);
    expect(tester.getTopLeft(find.byKey(startKey)).dx, (1440 - 760) / 2);
  });

  testWidgets('PageWidth fills a phone', (tester) async {
    await pumpAt(
      tester,
      const PageWidth(
        maxWidth: 760,
        child: SizedBox(key: startKey, height: 10, width: double.infinity),
      ),
    );
    expect(tester.getSize(find.byKey(startKey)).width, 390);
  });

  testWidgets('TwoColumns sits side by side when wide', (tester) async {
    await pumpAt(tester, twoColumns(), width: 1200);
    final start = tester.getRect(find.byKey(startKey));
    final end = tester.getRect(find.byKey(endKey));
    expect(end.top, start.top);
    expect(end.left, greaterThan(start.right));
  });

  testWidgets('TwoColumns stacks when narrow', (tester) async {
    await pumpAt(tester, twoColumns());
    final start = tester.getRect(find.byKey(startKey));
    final end = tester.getRect(find.byKey(endKey));
    expect(end.top, greaterThanOrEqualTo(start.bottom));
    expect(end.left, start.left);
  });

  testWidgets('TwoColumns honours a fixed start width', (tester) async {
    await pumpAt(tester, twoColumns(startWidth: 320), width: 1200);
    expect(tester.getSize(find.byKey(startKey)).width, 320);
  });

  for (final (width, perRow) in const [(1000.0, 3), (700.0, 2), (390.0, 1)]) {
    testWidgets('CardGrid shows $perRow per row at $width px', (tester) async {
      await pumpAt(tester, CardGrid(children: cards()), width: width);
      final firstTop = tester.getTopLeft(find.byKey(const ValueKey('card-0')));
      final sameRow = [
        for (var i = 0; i < 7; i++)
          if (tester.getTopLeft(find.byKey(ValueKey('card-$i'))).dy ==
              firstTop.dy)
            i,
      ];
      expect(sameRow.length, perRow);
    });
  }

  testWidgets('no overflow at large text on the breakpoint', (tester) async {
    await pumpAt(
      tester,
      Column(
        children: [
          PageWidth(maxWidth: 760, child: Text('A long title ' * 6)),
          TwoColumns(
            start: Text('Left column text ' * 8),
            end: Text('Right column text ' * 8),
          ),
          CardGrid(
            children: [for (var i = 0; i < 5; i++) Text('Card text ' * 6)],
          ),
        ],
      ),
      width: 640,
      textScale: 1.2,
    );
    expect(tester.takeException(), isNull);
  });
}
