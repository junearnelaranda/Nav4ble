import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navable/services/map_search_controller.dart';

void main() {
  test(
    'manually placing a pin overrides an in-flight address lookup',
    () async {
      final response = Completer<List<LatLng>>();
      final controller = MapSearchController(lookup: (_) => response.future);
      addTearDown(controller.dispose);
      final pending = controller.search('old search');
      controller.selectLocation(const LatLng(10.31, 123.89));
      response.complete([const LatLng(20, 120)]);
      await pending;
      expect(controller.result, const LatLng(10.31, 123.89));
      expect(controller.resultName, 'Pinned location');
      expect(controller.isSearching, isFalse);
    },
  );
  test(
    'search trims the query and exposes the first matching coordinate',
    () async {
      final controller = MapSearchController(
        lookup: (query) async {
          expect(query, 'Guadalupe Church, Cebu City');
          return [const LatLng(10.33, 123.87), const LatLng(10.34, 123.88)];
        },
      );
      addTearDown(controller.dispose);
      await controller.search('  Guadalupe Church, Cebu City  ');
      expect(controller.result, const LatLng(10.33, 123.87));
      expect(controller.resultName, 'Guadalupe Church, Cebu City');
      expect(controller.isSearching, isFalse);
    },
  );

  test('blank query does not call the geocoder', () async {
    final controller = MapSearchController(
      lookup: (_) async {
        fail('Empty searches must not call the geocoder');
      },
    );
    addTearDown(controller.dispose);
    await controller.search('   ');
    expect(controller.message, 'Enter a place or area to search.');
    expect(controller.isSearching, isFalse);
  });

  test('no matches clears the previous pin and offers recovery', () async {
    final controller = MapSearchController(
      lookup: (query) async => query == 'found' ? [const LatLng(10, 123)] : [],
    );
    addTearDown(controller.dispose);
    await controller.search('found');
    await controller.search('missing');
    expect(controller.result, isNull);
    expect(controller.message, contains('No location found'));
  });

  test('lookup failure ends loading and exposes an error', () async {
    final controller = MapSearchController(
      lookup: (_) async => throw Exception('offline'),
    );
    addTearDown(controller.dispose);
    await controller.search('Cebu');
    expect(controller.isSearching, isFalse);
    expect(controller.result, isNull);
    expect(controller.message, contains('Check your connection'));
  });

  test('an older response cannot replace a newer search', () async {
    final old = Completer<List<LatLng>>();
    final controller = MapSearchController(
      lookup: (query) =>
          query == 'old' ? old.future : Future.value([const LatLng(20, 120)]),
    );
    addTearDown(controller.dispose);
    final pending = controller.search('old');
    await controller.search('new');
    old.complete([const LatLng(10, 123)]);
    await pending;
    expect(controller.resultName, 'new');
    expect(controller.result, const LatLng(20, 120));
  });

  test(
    'disposing during lookup does not notify listeners afterwards',
    () async {
      final response = Completer<List<LatLng>>();
      final controller = MapSearchController(lookup: (_) => response.future);
      final pending = controller.search('Cebu');
      controller.dispose();
      response.complete([const LatLng(10, 123)]);
      await pending;
    },
  );
}
