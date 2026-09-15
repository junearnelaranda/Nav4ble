import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navable/widgets/navable_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NavAbleMapState.configChannel, null);
  });

  testWidgets('missing Android key does not create a native map', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NavAbleMapState.configChannel, (call) async {
          expect(call.method, 'isConfigured');
          return false;
        });
    final key = GlobalKey<NavAbleMapState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NavAbleMap(key: key)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Google Maps is not configured yet.'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
    await key.currentState!.centerOnUser();
    await tester.pump();
    expect(find.text('The map is not available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configuration channel failure has a usable fallback', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NavAbleMapState.configChannel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NavAbleMap())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Google Maps is not configured yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop does not attempt to create an Android map', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NavAbleMap())),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The live map is available in the Android app.'),
      findsOneWidget,
    );
    expect(find.byType(GoogleMap), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
