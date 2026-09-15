import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef AddressLookup = Future<List<LatLng>> Function(String query);

class MapSearchController extends ChangeNotifier {
  MapSearchController({AddressLookup? lookup})
    : _lookup = lookup ?? _lookupAddress;

  final AddressLookup _lookup;
  int _request = 0;
  bool _disposed = false;
  bool isSearching = false;
  String? message;
  String? resultName;
  LatLng? result;

  void selectLocation(LatLng coordinates, {String name = 'Pinned location'}) {
    if (_disposed) return;
    _request++;
    isSearching = false;
    result = coordinates;
    resultName = name;
    message = 'Destination selected. Tap Start Navigation for directions.';
    notifyListeners();
  }

  static Future<List<LatLng>> _lookupAddress(String query) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Address search is available on Android.');
    }
    final locations = await Geocoding().locationFromAddress(query);
    return locations
        .map((location) => LatLng(location.latitude, location.longitude))
        .toList();
  }

  Future<void> search(String input) async {
    if (_disposed) return;
    final request = ++_request;
    final query = input.trim();
    result = null;
    resultName = null;
    isSearching = query.isNotEmpty;
    message = query.isEmpty
        ? 'Enter a place or area to search.'
        : 'Searching for $query…';
    notifyListeners();
    if (query.isEmpty) return;

    try {
      final matches = await _lookup(query).timeout(const Duration(seconds: 15));
      if (_disposed || request != _request) return;
      if (matches.isEmpty) {
        message = 'No location found. Try adding the city or a full address.';
      } else {
        result = matches.first;
        resultName = query;
        message =
            'Location found: $query. Add the city if this is not the right place.';
      }
    } on TimeoutException {
      if (_disposed || request != _request) return;
      message = 'Search timed out. Check your connection and try again.';
    } on UnsupportedError {
      if (_disposed || request != _request) return;
      message = 'Place search is available in the Android app.';
    } catch (_) {
      if (_disposed || request != _request) return;
      message =
          'Could not find this location. Check your connection or try a fuller address.';
    } finally {
      if (!_disposed && request == _request) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
