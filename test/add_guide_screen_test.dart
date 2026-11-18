import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navable/guides_api.dart';
import 'package:navable/screens/add_guide_screen.dart';

const features = [
  GuideFeature(id: 'f-elevator', name: 'Elevator'),
  GuideFeature(id: 'f-parking', name: 'Accessible parking'),
];

final photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

Widget app({
  required Future<void> Function(GuideSubmission) onSubmit,
  String? initialFeatureName = 'Elevator',
  String? initialFeaturePhotoUrl,
  Size size = const Size(390, 844),
  double textScale = 1,
}) => MediaQuery(
  data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddGuideScreen(
                  locationId: 'place-1',
                  placeName: 'CityMall Bacalso',
                  placePoint: const LatLng(10.3, 123.9),
                  features: features,
                  initialFeatureName: initialFeatureName,
                  initialFeaturePhotoUrl: initialFeaturePhotoUrl,
                  onSubmit: onSubmit,
                  pickPhoto: (_) async => photo,
                  pinPickerBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> open(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> fillIn(WidgetTester tester, {bool featurePhoto = true}) async {
  await tester.enterText(
    field('Where to find it'),
    '  Beside the supermarket ',
  );
  await tester.enterText(field('Floor (optional)'), ' Ground floor ');
  await tester.enterText(
    field('Nearby sign or landmark (optional)'),
    ' Across the pharmacy ',
  );
  if (featurePhoto) {
    await tapVisible(tester, find.byKey(const ValueKey('guide-photo-feature')));
    await tester.pumpAndSettle();
  }
  await tapVisible(tester, find.byKey(const ValueKey('guide-photo-nearby')));
  await tester.pumpAndSettle();
}

Finder get submit => find.text('Submit for review');

void main() {
  testWidgets('shows every field', (tester) async {
    await open(tester, app(onSubmit: (_) async {}));
    expect(find.text('Where is this feature?'), findsOneWidget);
    expect(find.text('CityMall Bacalso'), findsOneWidget);
    expect(field('Where to find it'), findsOneWidget);
    expect(field('Floor (optional)'), findsOneWidget);
    expect(field('Nearby sign or landmark (optional)'), findsOneWidget);
    expect(find.text('Photo of the feature'), findsOneWidget);
    expect(find.text("Photo of what's nearby"), findsOneWidget);
    expect(find.text('Pin the spot (optional)'), findsOneWidget);
  });

  testWidgets('preselects the feature', (tester) async {
    await open(tester, app(onSubmit: (_) async {}));
    expect(find.text('Elevator'), findsOneWidget);
  });

  testWidgets('asks for a feature when none is preselected', (tester) async {
    var sent = 0;
    await open(
      tester,
      app(initialFeatureName: null, onSubmit: (_) async => sent++),
    );
    await fillIn(tester);
    await tapVisible(tester, submit);
    await tester.pumpAndSettle();
    expect(find.text('Choose a feature.'), findsOneWidget);
    expect(sent, 0);
  });

  testWidgets('explains what is missing', (tester) async {
    var sent = 0;
    await open(tester, app(onSubmit: (_) async => sent++));
    await tapVisible(tester, submit);
    await tester.pumpAndSettle();
    expect(find.text('Tell people where to find it.'), findsOneWidget);
    expect(sent, 0);
  });

  testWidgets('sends the guide', (tester) async {
    GuideSubmission? sent;
    await open(tester, app(onSubmit: (guide) async => sent = guide));
    await fillIn(tester);
    await tapVisible(tester, submit);
    await tester.pumpAndSettle();
    expect(sent?.locationId, 'place-1');
    expect(sent?.featureId, 'f-elevator');
    expect(sent?.whereText, 'Beside the supermarket');
    expect(sent?.floor, 'Ground floor');
    expect(sent?.landmark, 'Across the pharmacy');
    expect(sent?.featurePhoto, photo);
    expect(sent?.nearbyPhoto, photo);
    expect(sent?.pin, isNull);
    expect(find.text('Where is this feature?'), findsNothing);
    expect(
      find.text('Thanks! An admin will review your guide.'),
      findsOneWidget,
    );
  });

  testWidgets('submitting twice sends one guide', (tester) async {
    final pending = Completer<void>();
    var sent = 0;
    await open(
      tester,
      app(
        onSubmit: (_) {
          sent++;
          return pending.future;
        },
      ),
    );
    await fillIn(tester);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();
    expect(sent, 1);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('reuses the scan photo', (tester) async {
    GuideSubmission? sent;
    await open(
      tester,
      app(
        initialFeaturePhotoUrl: 'https://example.com/scan.jpg',
        onSubmit: (guide) async => sent = guide,
      ),
    );
    await fillIn(tester, featurePhoto: false);
    await tapVisible(tester, submit);
    await tester.pumpAndSettle();
    expect(sent?.featurePhotoUrl, 'https://example.com/scan.jpg');
    expect(sent?.featurePhoto, isNull);
  });

  testWidgets('keeps the form after a failure', (tester) async {
    await open(
      tester,
      app(onSubmit: (_) async => throw const GuidesApiException('Try again')),
    );
    await fillIn(tester);
    await tapVisible(tester, submit);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('  Beside the supermarket '), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: submit, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('screen readers can add a photo', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, app(onSubmit: (_) async {}));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('guide-photo-nearby'))),
      isSemantics(hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('fits a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(
      tester,
      app(onSubmit: (_) async {}, size: const Size(320, 568), textScale: 1.3),
    );
    expect(tester.takeException(), isNull);
  });
}
