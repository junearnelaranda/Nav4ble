import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/map_search_controller.dart';

/// Android Google Maps surface. Location is requested only after a user tap.
class NavAbleMap extends StatefulWidget {
  const NavAbleMap({
    super.key,
    this.padding = EdgeInsets.zero,
    this.searchController,
    this.onDestinationSelected,
  });

  final EdgeInsets padding;
  final MapSearchController? searchController;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<NavAbleMap> createState() => NavAbleMapState();
}

class NavAbleMapState extends State<NavAbleMap> {
  static const configChannel = MethodChannel('navable/maps_config');
  static const _cebu = LatLng(10.3157, 123.8854);
  GoogleMapController? _controller;
  late final Future<bool> _configured;
  bool _locationEnabled = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _configured = _checkConfiguration();
    widget.searchController?.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant NavAbleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_onSearchChanged);
      widget.searchController?.addListener(_onSearchChanged);
      _onSearchChanged();
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
    _showSearchResult();
  }

  void _selectDestination(LatLng location) {
    widget.searchController?.selectLocation(location);
    widget.onDestinationSelected?.call('Pinned location');
  }

  Future<void> _showSearchResult() async {
    final location = widget.searchController?.result;
    if (location == null || _controller == null) return;
    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(location, 16),
      );
    } on PlatformException {
      _message('Could not move the map. Try searching again.');
    }
  }

  Future<bool> _checkConfiguration() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await configChannel.invokeMethod<bool>('isConfigured') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> centerOnUser() async {
    if (_locating) return;
    if (_controller == null) {
      _message('The map is not available yet.');
      return;
    }
    _locating = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Turn on your device location, then tap My location again.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        _message(
          'Allow location for NavAble in Android Settings → Apps → Permissions.',
        );
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _message(
          'Location permission was not granted. You can still browse the map.',
        );
        return;
      }
      setState(() => _locationEnabled = true);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (_) {
      _message(
        'Could not get your location. Check device location and try again.',
      );
    } finally {
      _locating = false;
    }
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_onSearchChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _configured,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFFE8ECEF),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != true) {
          return ColoredBox(
            color: const Color(0xFFE8ECEF),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Text(
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                      ? 'Google Maps is not configured yet.'
                      : 'The live map is available in the Android app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF0F2B4D)),
                ),
              ),
            ),
          );
        }
        return GoogleMap(
          onLongPress: widget.searchController == null
              ? null
              : _selectDestination,
          initialCameraPosition: const CameraPosition(target: _cebu, zoom: 13),
          onMapCreated: (controller) {
            if (!mounted) {
              controller.dispose();
              return;
            }
            _controller = controller;
            _showSearchResult();
          },
          markers: {
            if (widget.searchController?.result case final location?)
              Marker(
                markerId: const MarkerId('search-result'),
                position: location,
                draggable: true,
                onDragEnd: _selectDestination,
                infoWindow: InfoWindow(
                  title: widget.searchController?.resultName,
                  snippet: 'Drag pin to adjust destination',
                ),
              ),
          },
          padding: widget.padding,
          myLocationEnabled: _locationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
        );
      },
    );
  }
}
