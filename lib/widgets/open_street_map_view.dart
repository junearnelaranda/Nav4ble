part of '../home.dart';

const _cebuMapCenter = osm.LatLng(10.3157, 123.8854);

/// Dark map tiles from the regular OpenStreetMap tiles: the usual Leaflet
/// dark-mode recipe (invert + hue-rotate 180°, so water stays blue and parks
/// stay green), remapped onto NavAble's dark canvas so the map matches the
/// app instead of glowing pure black and white.
final List<double> _navAbleDarkTileMatrix = () {
  // hue-rotate(180deg) from the CSS filter spec.
  const hue = [
    [-0.574, 1.430, 0.144],
    [0.426, 0.430, 0.144],
    [0.426, 1.430, -0.856],
  ];
  // Darkest output (roads, land) and lightest output (labels, outlines).
  const dark = NavAblePalette.darkCanvas;
  const light = Color(0xFFDBE5EC);
  final darkRgb = [dark.r, dark.g, dark.b];
  final lightRgb = [light.r, light.g, light.b];
  return <double>[
    for (var row = 0; row < 3; row++) ...[
      // Inverting x is 1 - x; hue rows sum to 1, so H(1 - x) = 1 - Hx.
      for (var col = 0; col < 3; col++)
        -(lightRgb[row] - darkRgb[row]) * hue[row][col],
      0,
      lightRgb[row] * 255,
    ],
    0, 0, 0, 1, 0, // keep alpha
  ];
}();

Widget _navAbleDarkTileBuilder(
  BuildContext context,
  Widget tileWidget,
  fm.TileImage tile,
) {
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(_navAbleDarkTileMatrix),
    child: tileWidget,
  );
}

/// NavAble's map pin: a push-pin stuck into a white landing ring. Use it in an
/// `fm.Marker` sized [width] x [height] times [scale], with [anchor], so the
/// needle tip, in the ring's hole, sits exactly on the map point.
class _PushPin extends StatelessWidget {
  const _PushPin({this.color = _selectedPinOrange, this.scale = 1});

  final Color color;
  final double scale;

  static const width = 36.0;
  static const height = 62.0;
  static const _tipFromBottom = 7.0;

  /// Size of the pins that aren't the picked place.
  static const small = 0.7;

  /// Marker alignment that puts the needle tip on the point (any scale).
  static const anchor = Alignment(
    0,
    1 - 2 * (height - _tipFromBottom) / height,
  );

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width * scale, height * scale),
      painter: _PushPinPainter(color),
    );
  }
}

/// Map pin colors: green = has accessibility features, red = no
/// accessibility info yet, orange = the place you searched or picked.
const _pushPinRed = Color(0xFFF25C5C);
const _selectedPinOrange = Color(0xFFFF8A00);

class _PushPinPainter extends CustomPainter {
  const _PushPinPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final pin = w * 0.84; // the pin is a little narrower than its ring
    final stroke = pin * 0.09;
    final radius = pin / 2 - stroke;
    final headCenter = Offset(cx, radius + stroke);
    final tip = Offset(cx, h * (1 - _PushPin._tipFromBottom / _PushPin.height));
    final needleHalf = pin * 0.11;
    final needleTop = headCenter.dy + radius * 0.8;
    final taperStart = tip.dy - pin * 0.24;

    final outline = Paint()
      ..color = const Color(0xFF1B1B1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Landing ring: soft shadow, white ring, and a dark hole the needle
    // goes into. The hole's centre is the exact location.
    final ring = Rect.fromCenter(
      center: tip,
      width: w * 0.72,
      height: w * 0.26,
    );
    canvas.drawOval(
      ring.inflate(1.5).shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawOval(ring, Paint()..color = Colors.white);
    canvas.drawOval(
      Rect.fromCenter(center: tip, width: w * 0.3, height: w * 0.11),
      Paint()..color = const Color(0xFF1B1B1F),
    );

    // Needle: straight shaft, then a taper to the point.
    final needle = Path()
      ..moveTo(cx - needleHalf, needleTop)
      ..lineTo(cx - needleHalf, taperStart)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(cx + needleHalf, taperStart)
      ..lineTo(cx + needleHalf, needleTop)
      ..close();
    canvas.drawPath(needle, Paint()..color = const Color(0xFFD5D8DD));
    canvas.drawPath(needle, outline);

    // Head.
    canvas.drawCircle(headCenter, radius, Paint()..color = color);
    canvas.drawCircle(headCenter, radius, outline);

    // Shine: a curved stroke and a dot on the upper left.
    final shine = Rect.fromCircle(center: headCenter, radius: radius * 0.62);
    canvas.drawArc(shine, 3.55, 1.25, false, outline);
    canvas.drawCircle(
      headCenter + Offset.fromDirection(3.2, radius * 0.62),
      stroke * 0.55,
      Paint()..color = const Color(0xFF1B1B1F),
    );
  }

  @override
  bool shouldRepaint(covariant _PushPinPainter oldDelegate) =>
      oldDelegate.color != color;
}

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
    this.searchResults = const [],
    this.onSearchResultTapped,
    this.selectedLocationId,
    this.onAccessibleLocationTapped,
    this.borderRadius = BorderRadius.zero,
    this.isConfirmed,
    this.isResultConfirmed,
  });

  /// Green pin when true, red ("not confirmed") otherwise. Defaults to
  /// "has any accessibility info"; Home passes its filter result instead.
  final bool Function(AccessibleLocation location)? isConfirmed;
  final bool Function(PlaceSearchResult result)? isResultConfirmed;

  final osm.LatLng initialPosition;
  final bool showLocationButton;
  final bool selectionMode;
  final osm.LatLng? initialSelection;
  final ValueChanged<osm.LatLng>? onLocationSelected;
  final List<AccessibleLocation> locations;
  final PlannedRoute? route;
  final PlaceSearchResult? searchedPlace;

  /// Search results shown as pins: green when accessible, red otherwise.
  final List<PlaceSearchResult> searchResults;
  final ValueChanged<PlaceSearchResult>? onSearchResultTapped;

  /// Id of the accessible location shown on the place card; its pin is
  /// drawn larger so the current selection is obvious.
  final String? selectedLocationId;
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
    if (widget.searchResults != oldWidget.searchResults &&
        widget.searchResults.isNotEmpty &&
        _mapReady &&
        widget.route == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitResults());
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

  void _fitResults() {
    final points = widget.searchResults.map((r) => r.point).toList();
    if (!mounted || points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.single, 16);
      return;
    }
    _controller.fitCamera(
      fm.CameraFit.bounds(
        bounds: fm.LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(48, 170, 48, 220),
        maxZoom: 16,
      ),
    );
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

  /// True when the push pin (route destination or searched place) sits on
  /// this location; it is then drawn as a round stand for the pin.
  static bool _samePoint(osm.LatLng a, osm.LatLng? b) =>
      b != null &&
      (a.latitude - b.latitude).abs() < 0.0002 &&
      (a.longitude - b.longitude).abs() < 0.0002;

  /// The picked place's pin is full size; the others are smaller.
  double _pinScale(bool picked) => picked ? 1 : _PushPin.small;

  bool _pushPinAt(AccessibleLocation location) {
    bool near(osm.LatLng? point) =>
        point != null &&
        (point.latitude - location.latitude).abs() < 0.0002 &&
        (point.longitude - location.longitude).abs() < 0.0002;
    return near(widget.route?.destination) || near(widget.searchedPlace?.point);
  }

  @override
  Widget build(BuildContext context) {
    final selectedPosition = _selectedPosition;
    final isDark = context.isNavAbleDark;
    final pinColor = isDark ? NavAblePalette.green : NavAblePalette.greenDark;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fm.FlutterMap(
            mapController: _controller,
            options: fm.MapOptions(
              // Shown before tiles load; avoids a light flash in dark mode.
              backgroundColor: isDark
                  ? NavAblePalette.darkCanvas
                  : const Color(0xFFE0E0E0),
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
                userAgentPackageName: 'navable.app',
                tileBuilder: isDark ? _navAbleDarkTileBuilder : null,
              ),
              if (widget.route case final route?)
                fm.PolylineLayer(
                  polylines: [
                    fm.Polyline(
                      points: route.points,
                      strokeWidth: 6,
                      color: isDark ? NavAblePalette.green : kNavAbleNavy,
                      borderStrokeWidth: 2,
                      borderColor: isDark
                          ? NavAblePalette.darkCanvas
                          : Colors.white,
                    ),
                  ],
                ),
              fm.MarkerLayer(
                markers: [
                  for (final location in widget.locations)
                    fm.Marker(
                      point: osm.LatLng(location.latitude, location.longitude),
                      width: _pushPinAt(location)
                          ? 44
                          : _PushPin.width *
                                _pinScale(
                                  location.id == widget.selectedLocationId,
                                ),
                      height: _pushPinAt(location)
                          ? 44
                          : _PushPin.height *
                                _pinScale(
                                  location.id == widget.selectedLocationId,
                                ),
                      alignment: _pushPinAt(location) ? null : _PushPin.anchor,
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
                          child: Tooltip(
                            message: location.name,
                            // A search or route push-pin already marks it.
                            child: _pushPinAt(location)
                                ? const SizedBox.expand()
                                : location.id == widget.selectedLocationId
                                ? const _PushPin()
                                : _PushPin(
                                    // Red until it has accessibility features.
                                    color:
                                        (widget.isConfirmed?.call(location) ??
                                            location.features.isNotEmpty)
                                        ? pinColor
                                        : _pushPinRed,
                                    scale: _PushPin.small,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  for (final result in widget.searchResults)
                    // The selected result is the push-pin; NavAble places
                    // already have their own pin.
                    if (!_samePoint(
                          result.point,
                          widget.searchedPlace?.point,
                        ) &&
                        !widget.locations.any(
                          (l) => _samePoint(
                            result.point,
                            osm.LatLng(l.latitude, l.longitude),
                          ),
                        ))
                      fm.Marker(
                        point: result.point,
                        width: _PushPin.width * _PushPin.small,
                        height: _PushPin.height * _PushPin.small,
                        alignment: _PushPin.anchor,
                        child: GestureDetector(
                          onTap: widget.onSearchResultTapped == null
                              ? null
                              : () => widget.onSearchResultTapped!(result),
                          child: Tooltip(
                            message: result.isAccessible
                                ? '${result.name}: ${result.accessibility}'
                                : '${result.name}: no accessibility info yet',
                            child: _PushPin(
                              color:
                                  (widget.isResultConfirmed?.call(result) ??
                                      result.isAccessible)
                                  ? pinColor
                                  : _pushPinRed,
                              scale: _PushPin.small,
                            ),
                          ),
                        ),
                      ),
                  if (widget.selectionMode && selectedPosition != null)
                    fm.Marker(
                      point: selectedPosition,
                      width: _PushPin.width,
                      height: _PushPin.height,
                      alignment: _PushPin.anchor,
                      child: const _PushPin(),
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
                      width: _PushPin.width,
                      height: _PushPin.height,
                      alignment: _PushPin.anchor,
                      child: const _PushPin(),
                    ),
                  if (widget.route case final route?)
                    fm.Marker(
                      point: route.destination,
                      width: _PushPin.width,
                      height: _PushPin.height,
                      alignment: _PushPin.anchor,
                      child: const _PushPin(),
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
                color: context.navAbleSurface,
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
                  color: context.navAblePrimaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
