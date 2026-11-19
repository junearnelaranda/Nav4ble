import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../guides_api.dart';
import '../navable_design.dart';

/// The icon for an accessibility feature, matching the Home filter chips.
IconData iconForFeature(String name) {
  final feature = name.toLowerCase();
  if (feature.contains('ramp')) return Icons.accessible_forward_rounded;
  if (feature.contains('elevator')) return Icons.elevator_outlined;
  if (feature.contains('entrance')) return Icons.meeting_room_outlined;
  if (feature.contains('restroom') || feature.contains('toilet')) {
    return Icons.wc_rounded;
  }
  if (feature.contains('tactile')) return Icons.blind_rounded;
  if (feature.contains('parking')) return Icons.local_parking_rounded;
  if (feature.contains('seat')) return Icons.event_seat_outlined;
  return Icons.accessible_rounded;
}

/// A feature's exact spot, shown on the map while its guide is open.
class GuideSpot {
  const GuideSpot({required this.point, required this.icon});

  final LatLng point;
  final IconData icon;

  @override
  bool operator ==(Object other) =>
      other is GuideSpot && other.point == point && other.icon == icon;

  @override
  int get hashCode => Object.hash(point, icon);
}

/// The temporary round marker at a [GuideSpot]. Separate from the map's pins.
class GuideSpotMarker extends StatelessWidget {
  const GuideSpotMarker({super.key, required this.icon});

  static const size = 48.0;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NavAblePalette.greenDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

/// Floating feature icons above the place card. Tapping one opens where to
/// find that feature in place of the card.
class PlaceGuidePanel extends StatefulWidget {
  const PlaceGuidePanel({
    super.key,
    required this.locationId,
    required this.features,
    required this.isGuest,
    required this.placeCard,
    required this.loadGuides,
    required this.onSpotChanged,
    required this.onAddGuide,
    required this.onGoToSpot,
    required this.onDirections,
    this.onOpenChanged,
  });

  final String locationId;
  final List<String> features;
  final bool isGuest;
  final Widget placeCard;
  final Future<List<FeatureGuide>> Function(String locationId) loadGuides;

  /// The spot to show on the map; null when there is none.
  final ValueChanged<GuideSpot?> onSpotChanged;
  final ValueChanged<String> onAddGuide;
  final ValueChanged<FeatureGuide> onGoToSpot;
  final VoidCallback onDirections;

  /// Whether a feature's guide is showing in place of the place card.
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<PlaceGuidePanel> createState() => _PlaceGuidePanelState();
}

class _PlaceGuidePanelState extends State<PlaceGuidePanel> {
  /// Null until loaded, and after a failed load: the row then stays hidden
  /// rather than claiming that no guides exist.
  Map<String, List<FeatureGuide>>? _guides;
  String? _openFeature;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _reportClosedAfterFrame();
  }

  /// A new panel starts closed, so nothing from an earlier place stays on
  /// the map. Waits for the frame because the parent is still building.
  void _reportClosedAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSpotChanged(null);
      widget.onOpenChanged?.call(false);
    });
  }

  @override
  void didUpdateWidget(covariant PlaceGuidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locationId == widget.locationId) return;
    final hadGuideOpen = _openFeature != null;
    _guides = null;
    _openFeature = null;
    _load();
    if (hadGuideOpen) _reportClosedAfterFrame();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final guides = await widget.loadGuides(widget.locationId);
      if (!mounted || request != _request) return;
      setState(() => _guides = guidesByFeature(guides));
    } on Exception {
      // Guides are extra help: the place card keeps working without them.
    }
  }

  List<FeatureGuide> _guidesFor(String feature) =>
      _guides?[featureKey(feature)] ?? const [];

  void _showSpot(FeatureGuide? guide) {
    widget.onSpotChanged(
      guide != null && guide.hasPin
          ? GuideSpot(
              point: LatLng(guide.latitude!, guide.longitude!),
              icon: iconForFeature(guide.featureName),
            )
          : null,
    );
  }

  void _toggle(String feature) {
    if (_openFeature == feature) {
      _close();
      return;
    }
    setState(() => _openFeature = feature);
    _showSpot(_guidesFor(feature).firstOrNull);
    widget.onOpenChanged?.call(true);
  }

  void _close() {
    setState(() => _openFeature = null);
    widget.onSpotChanged(null);
    widget.onOpenChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final open = _openFeature;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_guides != null && widget.features.isNotEmpty)
          _FeatureIconRow(
            features: widget.features,
            hasGuide: (feature) => _guidesFor(feature).isNotEmpty,
            selected: open,
            onTap: _toggle,
          ),
        if (open == null)
          widget.placeCard
        else if (_guidesFor(open).isEmpty)
          FeatureGuideEmptyView(
            featureName: open,
            isGuest: widget.isGuest,
            onAdd: () => widget.onAddGuide(open),
            onClose: _close,
          )
        else
          FeatureGuideView(
            key: ValueKey(open),
            featureName: open,
            guides: _guidesFor(open),
            isGuest: widget.isGuest,
            onGuideShown: _showSpot,
            onGoToSpot: widget.onGoToSpot,
            onDirections: widget.onDirections,
            onAddAnother: () => widget.onAddGuide(open),
            onClose: _close,
          ),
      ],
    );
  }
}

class _FeatureIconRow extends StatefulWidget {
  const _FeatureIconRow({
    required this.features,
    required this.hasGuide,
    required this.selected,
    required this.onTap,
  });

  final List<String> features;
  final bool Function(String feature) hasGuide;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  State<_FeatureIconRow> createState() => _FeatureIconRowState();
}

class _FeatureIconRowState extends State<_FeatureIconRow>
    with SingleTickerProviderStateMixin {
  static const _lift = 5.0;

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
      _float.value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wraps onto a second line, so no icon is ever cut off at the edge.
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, _lift + 2, 2, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8 + _lift,
        children: [
          for (final (index, feature) in widget.features.indexed)
            AnimatedBuilder(
              animation: _float,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  _float.isAnimating
                      ? -_lift *
                            (0.5 +
                                0.5 *
                                    math.sin(
                                      2 * math.pi * _float.value + index,
                                    ))
                      : 0,
                ),
                child: child,
              ),
              child: _FeatureIcon(
                feature: feature,
                hasGuide: widget.hasGuide(feature),
                selected: widget.selected == feature,
                onTap: () => widget.onTap(feature),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({
    required this.feature,
    required this.hasGuide,
    required this.selected,
    required this.onTap,
  });

  static const _size = 48.0;

  final String feature;
  final bool hasGuide;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color iconColor;
    if (selected) {
      fill = NavAblePalette.greenDark;
      iconColor = Colors.white;
    } else if (hasGuide) {
      fill = Colors.white;
      iconColor = NavAblePalette.greenDark;
    } else {
      fill = const Color(0xFFE6EAE7);
      iconColor = const Color(0xFF5A6773);
    }
    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      label: hasGuide ? '$feature, where to find it' : '$feature, no guide yet',
      excludeSemantics: true,
      child: Tooltip(
        message: feature,
        child: SizedBox.square(
          key: ValueKey('guide-icon-${featureKey(feature)}'),
          dimension: _size,
          child: Material(
            color: fill,
            shape: const CircleBorder(),
            elevation: 5,
            shadowColor: Colors.black54,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: CustomPaint(
                painter: _IconRingPainter(
                  color: selected
                      ? Colors.white
                      : hasGuide
                      ? NavAblePalette.green
                      : const Color(0xFF7D8B97),
                  dashed: !hasGuide && !selected,
                ),
                child: Center(
                  child: Icon(iconForFeature(feature), color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring around a feature icon: solid with a guide, dashed without one.
class _IconRingPainter extends CustomPainter {
  const _IconRingPainter({required this.color, required this.dashed});

  static const _dashes = 14;

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = (Offset.zero & size).deflate(1);
    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }
    const step = 2 * math.pi / _dashes;
    for (var dash = 0; dash < _dashes; dash++) {
      canvas.drawArc(rect, dash * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IconRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

/// "Where to find it" on a place's details: one row per feature, opening its
/// guide in a sheet. Stays hidden until the guides have loaded.
class PlaceGuideList extends StatefulWidget {
  const PlaceGuideList({
    super.key,
    required this.locationId,
    required this.features,
    required this.isGuest,
    required this.loadGuides,
    required this.onAddGuide,
    required this.onGoToSpot,
    required this.onDirections,
  });

  final String locationId;
  final List<String> features;
  final bool isGuest;
  final Future<List<FeatureGuide>> Function(String locationId) loadGuides;
  final ValueChanged<String> onAddGuide;
  final ValueChanged<FeatureGuide> onGoToSpot;
  final VoidCallback onDirections;

  @override
  State<PlaceGuideList> createState() => _PlaceGuideListState();
}

class _PlaceGuideListState extends State<PlaceGuideList> {
  Map<String, List<FeatureGuide>>? _guides;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final guides = await widget.loadGuides(widget.locationId);
      if (mounted) setState(() => _guides = guidesByFeature(guides));
    } on Exception {
      // The rest of the place details work without guides.
    }
  }

  void _open(String feature, List<FeatureGuide> guides) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) {
        void close() => Navigator.of(sheet).pop();
        void add() {
          close();
          widget.onAddGuide(feature);
        }

        return Padding(
          padding: const EdgeInsets.all(NavAbleSpacing.sm),
          child: guides.isEmpty
              ? FeatureGuideEmptyView(
                  featureName: feature,
                  isGuest: widget.isGuest,
                  onAdd: add,
                  onClose: close,
                )
              : FeatureGuideView(
                  featureName: feature,
                  guides: guides,
                  isGuest: widget.isGuest,
                  onGuideShown: (_) {},
                  onGoToSpot: widget.onGoToSpot,
                  onDirections: widget.onDirections,
                  onAddAnother: add,
                  onClose: close,
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final guides = _guides;
    if (guides == null || widget.features.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            'Where to find it',
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final feature in widget.features)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              iconForFeature(feature),
              color: NavAblePalette.greenDark,
            ),
            title: Text(feature),
            subtitle: Text(
              (guides[featureKey(feature)] ?? const []).isEmpty
                  ? 'No guide yet'
                  : 'See the guide',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                _open(feature, guides[featureKey(feature)] ?? const []),
          ),
      ],
    );
  }
}

/// A white card with a title and a close button, used by both guide views.
class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.closeTooltip,
    required this.onClose,
    required this.children,
  });

  final String title;
  final String closeTooltip;
  final VoidCallback? onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NavAbleLightTheme(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: Material(
          color: Colors.white,
          elevation: 6,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(NavAbleRadius.card),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: NavAblePalette.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: closeTooltip,
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                        color: NavAblePalette.navy,
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where to find a feature: the written location, two photos and, when the
/// spot has a pin, a way to go there. Steps through several spots.
class FeatureGuideView extends StatefulWidget {
  const FeatureGuideView({
    super.key,
    required this.featureName,
    required this.guides,
    required this.onGuideShown,
    required this.onGoToSpot,
    required this.onDirections,
    required this.onAddAnother,
    required this.isGuest,
    this.onClose,
  });

  final String featureName;
  final List<FeatureGuide> guides;

  /// Called when the user steps to another spot.
  final ValueChanged<FeatureGuide> onGuideShown;
  final ValueChanged<FeatureGuide> onGoToSpot;
  final VoidCallback onDirections;
  final VoidCallback onAddAnother;
  final bool isGuest;
  final VoidCallback? onClose;

  @override
  State<FeatureGuideView> createState() => _FeatureGuideViewState();
}

class _FeatureGuideViewState extends State<FeatureGuideView> {
  int _index = 0;

  void _step(int by) {
    setState(() => _index += by);
    widget.onGuideShown(widget.guides[_index]);
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guides[_index.clamp(0, widget.guides.length - 1)];
    final count = widget.guides.length;
    const detail = TextStyle(color: NavAblePalette.text, fontSize: 13);
    return _GuideCard(
      title: widget.featureName,
      closeTooltip: 'Close guide',
      onClose: widget.onClose,
      children: [
        if (count > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Previous spot',
                onPressed: _index == 0 ? null : () => _step(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  'Spot ${_index + 1} of $count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NavAblePalette.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next spot',
                onPressed: _index == count - 1 ? null : () => _step(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        Text(
          guide.whereText,
          style: const TextStyle(
            color: NavAblePalette.navy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (guide.floor case final floor?) ...[
          const SizedBox(height: 3),
          Text('Floor: $floor', style: detail),
        ],
        if (guide.landmark case final landmark?) ...[
          const SizedBox(height: 3),
          Text('Near: $landmark', style: detail),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GuidePhoto(
                url: guide.featurePhotoUrl,
                label: 'Photo of the ${widget.featureName}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GuidePhoto(
                url: guide.nearbyPhotoUrl,
                label: 'Photo of what is nearby',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(
              Icons.verified_rounded,
              color: NavAblePalette.greenDark,
              size: 16,
            ),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Verified by NavAble',
                style: TextStyle(
                  color: NavAblePalette.greenDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (guide.hasPin) ...[
          FilledButton.icon(
            onPressed: () => widget.onGoToSpot(guide),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Go to this spot'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Google Maps may not show an accessible route.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NavAblePalette.text, fontSize: 11),
          ),
        ] else
          FilledButton.icon(
            onPressed: widget.onDirections,
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Directions'),
          ),
        if (!widget.isGuest)
          TextButton(
            onPressed: widget.onAddAnother,
            child: const Text('Add another spot'),
          ),
      ],
    );
  }
}

/// A guide photo; tapping it opens it full screen.
class _GuidePhoto extends StatelessWidget {
  const _GuidePhoto({required this.url, required this.label});

  final String url;
  final String label;

  Widget _unavailable() => const ColoredBox(
    color: Color(0xFFE4EDE6),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Text(
          'Photo unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(color: NavAblePalette.text, fontSize: 11),
        ),
      ),
    ),
  );

  void _enlarge(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  semanticLabel: label,
                  errorBuilder: (_, _, _) => _unavailable(),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Close photo',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. Opens larger.',
      onTap: () => _enlarge(context),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NavAbleRadius.tile),
        child: SizedBox(
          height: 88,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _unavailable(),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: () => _enlarge(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown for a feature nobody has written a guide for yet.
class FeatureGuideEmptyView extends StatelessWidget {
  const FeatureGuideEmptyView({
    super.key,
    required this.featureName,
    required this.isGuest,
    required this.onAdd,
    this.onClose,
  });

  final String featureName;
  final bool isGuest;
  final VoidCallback onAdd;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      title: featureName,
      closeTooltip: 'Close guide',
      onClose: onClose,
      children: [
        const Text(
          'Nobody has shared where this feature is yet.',
          style: TextStyle(color: NavAblePalette.text, fontSize: 13),
        ),
        const SizedBox(height: 10),
        if (isGuest)
          const Text(
            'Sign in to add where to find it',
            style: TextStyle(
              color: NavAblePalette.navy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add where to find it'),
          ),
      ],
    );
  }
}
