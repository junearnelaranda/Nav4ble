part of '../home.dart';

const _cebuMapCenter = osm.LatLng(10.3157, 123.8854);

class _OpenStreetMapView extends StatefulWidget {
  const _OpenStreetMapView({
    super.key,
    required this.initialPosition,
    this.showLocationButton = false,
    this.selectionMode = false,
    this.initialSelection,
    this.onLocationSelected,
    this.locations = const [],
    this.route,
    this.searchedPlace,
    this.onAccessibleLocationTapped,
    this.borderRadius = BorderRadius.zero,
  });

  final osm.LatLng initialPosition;
  final bool showLocationButton;
  final bool selectionMode;
  final osm.LatLng? initialSelection;
  final ValueChanged<osm.LatLng>? onLocationSelected;
  final List<AccessibleLocation> locations;
  final PlannedRoute? route;
  final PlaceSearchResult? searchedPlace;
  final ValueChanged<AccessibleLocation>? onAccessibleLocationTapped;
  final BorderRadius borderRadius;

  @override
  State<_OpenStreetMapView> createState() => _OpenStreetMapViewState();
}

class _OpenStreetMapViewState extends State<_OpenStreetMapView> {
  final fm.MapController _controller = fm.MapController();
  osm.LatLng? _selectedPosition;
  osm.LatLng? _currentPosition;
  bool _mapReady = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialSelection;
  }

  @override
  void didUpdateWidget(covariant _OpenStreetMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route != oldWidget.route && widget.route != null && _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    }
    if (widget.searchedPlace != oldWidget.searchedPlace &&
        widget.searchedPlace != null &&
        _mapReady &&
        widget.route == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.searchedPlace != null) {
          _controller.move(widget.searchedPlace!.point, 16);
        }
      });
    }
  }

  void _fitRoute() {
    final route = widget.route;
    if (!_mapReady || route == null || route.points.length < 2) return;
    _controller.fitCamera(
      fm.CameraFit.bounds(
        bounds: fm.LatLngBounds.fromPoints(route.points),
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ),
    );
  }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on location services and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Allow location access in your device settings.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _locateMe() async {
    if (_locating || !_mapReady) return;
    setState(() => _locating = true);
    try {
      final position = await _getCurrentPosition();
      final location = osm.LatLng(position.latitude, position.longitude);
      _controller.move(location, 16);
      if (!mounted) return;
      setState(() => _currentPosition = location);
      if (widget.selectionMode) _selectLocation(location);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _selectLocation(osm.LatLng position) {
    setState(() => _selectedPosition = position);
    widget.onLocationSelected?.call(position);
  }

  @override
  Widget build(BuildContext context) {
    final selectedPosition = _selectedPosition;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fm.FlutterMap(
            mapController: _controller,
            options: fm.MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: widget.selectionMode ? 15 : 14,
              onTap: widget.selectionMode
                  ? (_, point) => _selectLocation(point)
                  : null,
              onMapReady: () {
                if (mounted) {
                  setState(() => _mapReady = true);
                  _fitRoute();
                }
              },
            ),
            children: [
              fm.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.navable',
              ),
              if (widget.route case final route?)
                fm.PolylineLayer(
                  polylines: [
                    fm.Polyline(
                      points: route.points,
                      strokeWidth: 6,
                      color: kNavAbleNavy,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              fm.MarkerLayer(
                markers: [
                  for (final location in widget.locations)
                    fm.Marker(
                      point: osm.LatLng(location.latitude, location.longitude),
                      width: 46,
                      height: 50,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: widget.onAccessibleLocationTapped == null
                              ? null
                              : () {
                                  _selectLocation(
                                    osm.LatLng(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                  );
                                  widget.onAccessibleLocationTapped!(location);
                                },
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: NavAblePalette.greenDark,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  if (widget.selectionMode && selectedPosition != null)
                    fm.Marker(
                      point: selectedPosition,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_pin,
                        color: kNavAbleNavy,
                        size: 42,
                      ),
                    ),
                  if (widget.route case final route?)
                    fm.Marker(
                      point: route.origin,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  if (widget.searchedPlace case final place?)
                    fm.Marker(
                      point: place.point,
                      width: 46,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.deepOrange,
                        size: 44,
                      ),
                    ),
                  if (widget.route case final route?)
                    fm.Marker(
                      point: route.destination,
                      width: 46,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.deepOrange,
                        size: 44,
                      ),
                    ),
                  if (_currentPosition != null)
                    fm.Marker(
                      point: _currentPosition!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              fm.RichAttributionWidget(
                attributions: [
                  fm.TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (widget.showLocationButton)
            Positioned(
              top: 132,
              right: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Use my location',
                  onPressed: _locating || !_mapReady ? null : _locateMe,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  color: kNavAbleNavy,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
