import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/locations_api.dart';
import 'package:navable/navable_design.dart';
import 'package:navable/widgets/place_photo_carousel.dart';

const photos = [
  PlacePhoto(url: 'https://example.com/a.jpg'),
  PlacePhoto(url: 'https://example.com/b.jpg', contributor: 'June A.'),
  PlacePhoto(url: 'https://example.com/c.jpg', contributor: 'Ana R.'),
];

Future<void> pumpCarousel(
  WidgetTester tester, {
  List<PlacePhoto> items = photos,
  VoidCallback? onOpen,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: NavAbleTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: PlacePhotoCarousel(
                photos: items,
                placeName: 'Ayala Malls',
                placeholder: const ColoredBox(
                  key: ValueKey('placeholder'),
                  color: Colors.grey,
                ),
                onOpen: onOpen == null ? null : (_) => onOpen(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('a place\'s gallery falls back to its single cover', () {
    const withCover = AccessibleLocation(
      id: '1',
      name: 'A',
      address: '',
      latitude: 0,
      longitude: 0,
      features: [],
      photoUrl: 'https://example.com/cover.jpg',
    );
    expect(withCover.gallery.map((photo) => photo.url), [
      'https://example.com/cover.jpg',
    ]);
    const withPhotos = AccessibleLocation(
      id: '2',
      name: 'B',
      address: '',
      latitude: 0,
      longitude: 0,
      features: [],
      photos: photos,
    );
    expect(withPhotos.photoUrl, 'https://example.com/a.jpg');
    expect(withPhotos.gallery, photos);
  });

  testWidgets('no photos shows the placeholder', (tester) async {
    await pumpCarousel(tester, items: const []);
    expect(find.byKey(const ValueKey('placeholder')), findsOneWidget);
    expect(find.byTooltip('Next photo'), findsNothing);
  });

  testWidgets('one photo has no arrows or counter', (tester) async {
    await pumpCarousel(tester, items: photos.sublist(0, 1));
    expect(find.byTooltip('Next photo'), findsNothing);
    expect(find.text('1 / 1'), findsNothing);
  });

  testWidgets('arrows move between photos and show the credit', (tester) async {
    await pumpCarousel(tester);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Photo by June A.'), findsNothing);

    await tester.tap(find.byTooltip('Next photo'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Photo by June A.'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous photo'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('swiping moves to the next photo', (tester) async {
    await pumpCarousel(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('the first photo has no back arrow, the last no next', (
    tester,
  ) async {
    await pumpCarousel(tester);
    expect(find.byTooltip('Previous photo'), findsNothing);
    await tester.tap(find.byTooltip('Next photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next photo'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.byTooltip('Next photo'), findsNothing);
  });

  testWidgets('tapping a photo opens it', (tester) async {
    var opened = 0;
    await pumpCarousel(tester, onOpen: () => opened++);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    expect(opened, 1);
  });

  testWidgets('full screen viewer opens on the tapped photo and closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: NavAbleTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPlacePhotoViewer(
                context,
                photos: photos,
                initialIndex: 1,
                placeName: 'Ayala Malls',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Photo by June A.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close photos'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsNothing);
  });
}
