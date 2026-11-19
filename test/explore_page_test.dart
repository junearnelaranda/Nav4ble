import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/home.dart';
import 'package:navable/locations_api.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/widgets/place_photo_carousel.dart';

final places = [
  for (var i = 0; i < 7; i++)
    AccessibleLocation(
      id: 'p$i',
      name: 'Place $i',
      address: 'Street $i, Cebu City',
      latitude: 10.3 + i / 1000,
      longitude: 123.9,
      features: const ['Elevator', 'Accessible parking'],
      rating: 5 - i / 10,
      category: 'Shopping mall',
      photos: i == 0
          ? const [
              PlacePhoto(url: 'https://example.com/a.jpg'),
              PlacePhoto(
                url: 'https://example.com/b.jpg',
                contributor: 'June A.',
              ),
              PlacePhoto(url: 'https://example.com/c.jpg'),
            ]
          : const [],
    ),
];

Future<void> pumpExplore(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: NavAbleTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1000),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: ExplorePage(
            searchController: controller,
            locations: places,
            locationsLoading: false,
            locationsError: null,
            onNavigate: (_) {},
            onSubmitPhoto: (_) {},
            onContributeGooglePlace: (_, _) {},
            onRefresh: () async {},
            isGuest: true,
            onAddGuide: (_, _) {},
            onGoToGuideSpot: (_) {},
            loadGuides: (_) async => const [],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('phone keeps the single list', (tester) async {
    await pumpExplore(tester, width: 390);
    expect(find.text('Explore places'), findsNothing);
    final left = tester.getTopLeft(find.text('Place 0')).dx;
    expect(tester.getTopLeft(find.text('Place 1')).dx, left);
    expect(
      tester.getTopLeft(find.text('Place 1')).dy,
      greaterThan(tester.getTopLeft(find.text('Place 0')).dy),
    );
  });

  testWidgets('PC shows a heading and three columns', (tester) async {
    await pumpExplore(tester, width: 1440);
    expect(find.text('Explore places'), findsOneWidget);
    expect(find.text('7 places in Cebu City'), findsOneWidget);
    final top = tester.getTopLeft(find.text('Place 0')).dy;
    expect(tester.getTopLeft(find.text('Place 1')).dy, top);
    expect(tester.getTopLeft(find.text('Place 2')).dy, top);
    expect(tester.getTopLeft(find.text('Place 3')).dy, greaterThan(top));
  });

  testWidgets('PC caps the width', (tester) async {
    await pumpExplore(tester, width: 1920);
    final heading = tester.getRect(find.text('Explore places'));
    final lastInRow = tester.getRect(find.text('Place 2'));
    // The content column starts at the heading and ends after the third card.
    expect(lastInRow.right - heading.left, lessThanOrEqualTo(1200));
  });

  for (final width in const [640.0, 1000.0]) {
    testWidgets('no overflow at $width px with large text', (tester) async {
      await pumpExplore(tester, width: width, textScale: 1.2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('there is no Braille filter', (tester) async {
    await pumpExplore(tester, width: 1440);
    expect(find.text('Elevator'), findsWidgets);
    expect(find.text('Braille'), findsNothing);
  });

  testWidgets('a card swipes through its photos', (tester) async {
    await pumpExplore(tester, width: 1440);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next photo').first);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Photo by June A.'), findsOneWidget);
  });

  Future<void> openDetails(WidgetTester tester, double width) async {
    await pumpExplore(tester, width: width);
    await tester.tap(find.text('Place 0').first);
    await tester.pumpAndSettle();
    expect(find.text('Place Details'), findsOneWidget);
  }

  testWidgets('PC place details puts the photos beside the details', (
    tester,
  ) async {
    await openDetails(tester, 1440);
    final photo = tester.getRect(find.byType(PlacePhotoCarousel));
    final name = tester.getRect(find.text('Place 0').last);
    expect(photo.width, lessThan(720));
    expect(photo.height, lessThan(480));
    expect(name.left, greaterThan(photo.right));
  });

  testWidgets('phone place details keeps the photos on top', (tester) async {
    await openDetails(tester, 390);
    final photo = tester.getRect(find.byType(PlacePhotoCarousel));
    final name = tester.getRect(find.text('Place 0').last);
    expect(name.top, greaterThan(photo.bottom));
  });

  for (final width in const [390.0, 800.0, 1440.0]) {
    testWidgets('place details has no overflow at $width px', (tester) async {
      await openDetails(tester, width);
      expect(tester.takeException(), isNull);
    });
  }
}
