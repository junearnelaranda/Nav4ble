import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/widgets/side_menu.dart';

const items = [
  SideMenuItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Map',
  ),
  SideMenuItem(
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore_rounded,
    label: 'Explore',
  ),
  SideMenuItem(
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check_rounded,
    label: 'Reports',
  ),
  SideMenuItem(
    icon: Icons.notifications_none_rounded,
    selectedIcon: Icons.notifications_rounded,
    label: 'Alerts',
    badge: 3,
  ),
  SideMenuItem(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

class Calls {
  final selected = <int>[];
  var leaderboard = 0;
  var profile = 0;
  var signIn = 0;
}

Future<void> pumpMenu(
  WidgetTester tester,
  Calls calls, {
  bool extended = true,
  List<SideMenuItem> menuItems = items,
  int selectedIndex = 1,
  String? userName = 'June A.',
  bool guest = false,
  ThemeData? theme,
  double height = 800,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(1200, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? NavAbleTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(1200, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Row(
            children: [
              NavAbleSideMenu(
                items: menuItems,
                selectedIndex: selectedIndex,
                onSelected: calls.selected.add,
                extended: extended,
                onLeaderboard: () => calls.leaderboard++,
                userName: guest ? null : userName,
                onOpenProfile: guest ? null : () => calls.profile++,
                onSignIn: guest ? () => calls.signIn++ : null,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get menu => find.byType(NavAbleSideMenu);

void main() {
  testWidgets('shows labels when extended', (tester) async {
    await pumpMenu(tester, Calls());
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Top Contributors'), findsOneWidget);
    expect(tester.getSize(menu).width, 220);
  });

  testWidgets('shows icons only when compact', (tester) async {
    await pumpMenu(tester, Calls(), extended: false);
    expect(find.text('Explore'), findsNothing);
    expect(find.byTooltip('Explore'), findsOneWidget);
    expect(tester.getSize(menu).width, 80);
  });

  testWidgets('marks the selected page', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMenu(tester, Calls());
    expect(
      tester.getSemantics(find.byKey(const ValueKey('side-menu-1'))),
      isSemantics(isSelected: true, label: 'Explore'),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('side-menu-0'))),
      isSemantics(isSelected: false, label: 'Map'),
    );
    semantics.dispose();
  });

  testWidgets('items are tall enough to tap', (tester) async {
    await pumpMenu(tester, Calls(), extended: false);
    for (var index = 0; index < items.length; index++) {
      final size = tester.getSize(find.byKey(ValueKey('side-menu-$index')));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('tapping an item selects it', (tester) async {
    final calls = Calls();
    await pumpMenu(tester, calls);
    await tester.tap(find.text('Reports'));
    expect(calls.selected, [2]);
  });

  testWidgets('keyboard users can choose a page', (tester) async {
    final calls = Calls();
    await pumpMenu(tester, calls);
    final reports = find.byKey(const ValueKey('side-menu-2'));
    Focus.of(
      tester.element(find.descendant(of: reports, matching: find.byType(Text))),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls.selected, [2]);
  });

  testWidgets('top contributors opens the leaderboard', (tester) async {
    final calls = Calls();
    await pumpMenu(tester, calls);
    await tester.tap(find.text('Top Contributors'));
    expect(calls.leaderboard, 1);
  });

  testWidgets('shows the unread count', (tester) async {
    await pumpMenu(tester, Calls());
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('hides a zero count and caps a large one', (tester) async {
    await pumpMenu(
      tester,
      Calls(),
      menuItems: const [
        SideMenuItem(icon: Icons.map, selectedIcon: Icons.map, label: 'Map'),
        SideMenuItem(
          icon: Icons.notifications_none_rounded,
          selectedIcon: Icons.notifications_rounded,
          label: 'Alerts',
          badge: 12,
        ),
      ],
      selectedIndex: 0,
    );
    expect(find.text('0'), findsNothing);
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('guests get a sign in button', (tester) async {
    final calls = Calls();
    await pumpMenu(tester, calls, guest: true);
    expect(find.text('June A.'), findsNothing);
    await tester.tap(find.text('Sign in'));
    expect(calls.signIn, 1);
  });

  testWidgets('signed-in users open their profile', (tester) async {
    final calls = Calls();
    await pumpMenu(tester, calls);
    await tester.tap(find.text('June A.'));
    expect(calls.profile, 1);
  });

  testWidgets('stays navy and readable in dark theme', (tester) async {
    await pumpMenu(tester, Calls(), theme: NavAbleTheme.dark);
    final material = tester.widget<Material>(
      find.descendant(of: menu, matching: find.byType(Material)).first,
    );
    expect(material.color, NavAblePalette.navy);
    final label = tester.widget<Text>(find.text('Explore'));
    expect(label.style?.color, Colors.white);
  });

  for (final extended in const [true, false]) {
    testWidgets('fits large text (extended: $extended)', (tester) async {
      await pumpMenu(
        tester,
        Calls(),
        extended: extended,
        height: 600,
        textScale: 1.2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard focus and hover show clearly on navy', (tester) async {
    await pumpMenu(tester, Calls());
    final inkWells = tester.widgetList<InkWell>(
      find.descendant(
        of: find.byType(NavAbleSideMenu),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWells, isNotEmpty);
    for (final ink in inkWells) {
      expect(ink.focusColor, Colors.white.withValues(alpha: 0.24));
      expect(ink.hoverColor, Colors.white.withValues(alpha: 0.10));
    }
  });
}
