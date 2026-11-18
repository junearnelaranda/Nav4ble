import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navable/guides_api.dart';
import 'package:navable/widgets/feature_guide_widgets.dart';

FeatureGuide guide({
  String id = 'g1',
  String feature = 'Elevator',
  String where = 'Beside the supermarket',
  double? latitude = 10.29,
  double? longitude = 123.88,
}) => FeatureGuide(
  id: id,
  featureId: 'f1',
  featureName: feature,
  whereText: where,
  floor: 'Ground floor',
  landmark: 'Across the pharmacy',
  latitude: latitude,
  longitude: longitude,
  featurePhotoUrl: 'https://example.com/feature.jpg',
  nearbyPhotoUrl: 'https://example.com/nearby.jpg',
);

Finder icon(String feature) =>
    find.byKey(ValueKey('guide-icon-${featureKey(feature)}'));

class Harness {
  final spots = <GuideSpot?>[];
  final added = <String>[];
  final wentTo = <FeatureGuide>[];
  final opened = <bool>[];
  var directions = 0;

  Widget panel({
    String locationId = 'place-a',
    List<String> features = const ['Elevator', 'Parking'],
    bool isGuest = false,
    required Future<List<FeatureGuide>> Function(String) load,
  }) => PlaceGuidePanel(
    locationId: locationId,
    features: features,
    isGuest: isGuest,
    placeCard: const Text('PLACE CARD'),
    loadGuides: load,
    onSpotChanged: spots.add,
    onAddGuide: added.add,
    onGoToSpot: wentTo.add,
    onDirections: () => directions++,
    onOpenChanged: opened.add,
  );
}

Widget app(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = true,
}) => MediaQuery(
  data: MediaQueryData(
    size: size,
    textScaler: TextScaler.linear(textScale),
    disableAnimations: disableAnimations,
  ),
  child: MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.bottomLeft, child: child),
    ),
  ),
);

Future<List<FeatureGuide>> Function(String) returns(List<FeatureGuide> list) =>
    (_) async => list;

void main() {
  testWidgets('shows only the place card while guides load', (tester) async {
    final pending = Completer<List<FeatureGuide>>();
    await tester.pumpWidget(app(Harness().panel(load: (_) => pending.future)));
    await tester.pump();
    expect(find.text('PLACE CARD'), findsOneWidget);
    expect(icon('Elevator'), findsNothing);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('hides the row when loading fails', (tester) async {
    await tester.pumpWidget(
      app(
        Harness().panel(
          load: (_) async => throw const GuidesApiException('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PLACE CARD'), findsOneWidget);
    expect(icon('Elevator'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labels icons with and without guides', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(Harness().panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Elevator, where to find it'), findsOneWidget);
    expect(find.bySemanticsLabel('Parking, no guide yet'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('finds guides when capitals differ', (tester) async {
    await tester.pumpWidget(
      app(
        Harness().panel(features: const ['ELEVATOR'], load: returns([guide()])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(icon('ELEVATOR'));
    await tester.pumpAndSettle();
    expect(find.text('Beside the supermarket'), findsOneWidget);
  });

  testWidgets('icons are at least 48 px', (tester) async {
    await tester.pumpWidget(app(Harness().panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    final size = tester.getSize(icon('Elevator'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('icons stay still with animations off', (tester) async {
    await tester.pumpWidget(app(Harness().panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('icons float gently with animations on', (tester) async {
    await tester.pumpWidget(
      app(Harness().panel(load: returns([guide()])), disableAnimations: false),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a guide with a pin moves the map', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(harness.panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(harness.spots.last?.point, const LatLng(10.29, 123.88));
    expect(find.text('Go to this spot'), findsOneWidget);
    expect(find.text('PLACE CARD'), findsNothing);
    expect(find.text('Floor: Ground floor'), findsOneWidget);
    expect(find.text('Near: Across the pharmacy'), findsOneWidget);
    expect(find.text('Verified by NavAble'), findsOneWidget);
    expect(
      find.text('Google Maps may not show an accessible route.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Go to this spot'));
    expect(harness.wentTo.single.id, 'g1');
  });

  testWidgets('closing a guide restores the card', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(harness.panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close guide'));
    await tester.pumpAndSettle();
    expect(harness.spots.last, isNull);
    expect(find.text('PLACE CARD'), findsOneWidget);
  });

  testWidgets('tells the screen while a guide is open', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(harness.panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(harness.opened.last, isTrue);
    await tester.tap(find.byTooltip('Close guide'));
    await tester.pumpAndSettle();
    expect(harness.opened.last, isFalse);
  });

  testWidgets('a new panel clears a spot left on the map', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(harness.panel(load: returns(const []))));
    await tester.pumpAndSettle();
    expect(harness.spots, [null]);
    expect(harness.opened, [false]);
  });

  testWidgets('a guide without a pin offers Directions', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(
      app(
        harness.panel(load: returns([guide(latitude: null, longitude: null)])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(harness.spots.last, isNull);
    expect(find.text('Go to this spot'), findsNothing);
    await tester.tap(find.text('Directions'));
    expect(harness.directions, 1);
  });

  testWidgets('several spots can be stepped through', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(
      app(
        harness.panel(
          load: returns([
            guide(id: 'a'),
            guide(
              id: 'b',
              where: 'Near the food court',
              latitude: 10.2901,
              longitude: 123.8801,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(find.text('Spot 1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next spot'));
    await tester.pumpAndSettle();
    expect(find.text('Spot 2 of 2'), findsOneWidget);
    expect(find.text('Near the food court'), findsOneWidget);
    expect(harness.spots.last?.point, const LatLng(10.2901, 123.8801));
  });

  testWidgets('guests are asked to sign in', (tester) async {
    await tester.pumpWidget(
      app(Harness().panel(isGuest: true, load: returns(const []))),
    );
    await tester.pumpAndSettle();
    await tester.tap(icon('Parking'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to add where to find it'), findsOneWidget);
    expect(find.text('Add where to find it'), findsNothing);
  });

  testWidgets('signed-in users can add a guide', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(harness.panel(load: returns(const []))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Parking'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nobody has shared where this feature is yet.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add where to find it'));
    expect(harness.added, ['Parking']);
  });

  testWidgets('signed-in users can add another spot', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(harness.panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add another spot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add another spot'));
    expect(harness.added, ['Elevator']);
  });

  testWidgets('a late answer for the previous place is ignored', (
    tester,
  ) async {
    final placeA = Completer<List<FeatureGuide>>();
    final harness = Harness();
    Future<List<FeatureGuide>> load(String id) =>
        id == 'place-a' ? placeA.future : Future.value(const []);
    await tester.pumpWidget(
      app(harness.panel(features: const ['Elevator'], load: load)),
    );
    await tester.pump();
    await tester.pumpWidget(
      app(
        harness.panel(
          locationId: 'place-b',
          features: const ['Elevator'],
          load: load,
        ),
      ),
    );
    await tester.pumpAndSettle();
    placeA.complete([guide()]);
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(find.text('Beside the supermarket'), findsNothing);
    expect(
      find.text('Nobody has shared where this feature is yet.'),
      findsOneWidget,
    );
  });

  testWidgets('changing place closes an open guide', (tester) async {
    final harness = Harness();
    await tester.pumpWidget(app(harness.panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(harness.spots.last, isNotNull);
    await tester.pumpWidget(
      app(harness.panel(locationId: 'place-b', load: returns(const []))),
    );
    await tester.pumpAndSettle();
    expect(harness.spots.last, isNull);
    expect(find.text('PLACE CARD'), findsOneWidget);
  });

  testWidgets('a broken photo shows a placeholder', (tester) async {
    await tester.pumpWidget(app(Harness().panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Photo unavailable'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the guide fits a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Harness().panel(
          load: returns([guide(where: 'Beside the supermarket ' * 8)]),
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers can activate a feature icon', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(Harness().panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(icon('Elevator')),
      isSemantics(label: 'Elevator, where to find it', hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('screen readers can open a guide photo', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(Harness().panel(load: returns([guide()]))));
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Photo of what is nearby. Opens larger.'),
      ),
      isSemantics(hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('several spots fit a narrow phone at the largest text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Harness().panel(
          load: returns([guide(id: 'a'), guide(id: 'b')]),
        ),
        size: const Size(320, 568),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(icon('Elevator'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('PlaceGuideList', () {
    Widget list(
      Harness harness, {
      required Future<List<FeatureGuide>> Function(String) load,
      bool isGuest = false,
    }) => app(
      PlaceGuideList(
        locationId: 'place-a',
        features: const ['Elevator', 'Parking'],
        isGuest: isGuest,
        loadGuides: load,
        onAddGuide: harness.added.add,
        onGoToSpot: harness.wentTo.add,
        onDirections: () => harness.directions++,
      ),
    );

    testWidgets('lists each feature once guides load', (tester) async {
      await tester.pumpWidget(list(Harness(), load: returns([guide()])));
      await tester.pumpAndSettle();
      expect(find.text('Where to find it'), findsOneWidget);
      expect(find.text('Elevator'), findsOneWidget);
      expect(find.text('See the guide'), findsOneWidget);
      expect(find.text('No guide yet'), findsOneWidget);
    });

    testWidgets('stays hidden when guides cannot load', (tester) async {
      await tester.pumpWidget(
        list(
          Harness(),
          load: (_) async => throw const GuidesApiException('offline'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Where to find it'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens a feature guide', (tester) async {
      final harness = Harness();
      await tester.pumpWidget(list(harness, load: returns([guide()])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elevator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to this spot'));
      expect(harness.wentTo.single.id, 'g1');
    });

    testWidgets('offers to add a missing guide', (tester) async {
      final harness = Harness();
      await tester.pumpWidget(list(harness, load: returns(const [])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add where to find it'));
      await tester.pumpAndSettle();
      expect(harness.added, ['Parking']);
      expect(find.text('Add where to find it'), findsNothing);
    });
  });

  test('every feature has its own icon', () {
    expect(iconForFeature('Wheelchair ramp'), Icons.accessible_forward_rounded);
    expect(iconForFeature('Elevator'), Icons.elevator_outlined);
    expect(iconForFeature('Accessible entrance'), Icons.meeting_room_outlined);
    expect(iconForFeature('Accessible restroom'), Icons.wc_rounded);
    expect(iconForFeature('Tactile paving'), Icons.blind_rounded);
    expect(iconForFeature('Accessible parking'), Icons.local_parking_rounded);
    expect(iconForFeature('Wheelchair seating'), Icons.event_seat_outlined);
    expect(iconForFeature('Something new'), Icons.accessible_rounded);
  });
}
