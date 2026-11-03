part of '../home.dart';

/// Explore: a search shows Google places with NavAble's accessibility data
/// on top; an empty search lists NavAble's own verified places.
class _ExplorePage extends StatefulWidget {
  const _ExplorePage({
    required this.searchController,
    required this.locations,
    required this.locationsLoading,
    required this.locationsError,
    required this.onNavigate,
    required this.onSubmitPhoto,
    required this.onContributeGooglePlace,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final List<AccessibleLocation> locations;
  final bool locationsLoading;
  final String? locationsError;
  final ValueChanged<AccessibleLocation> onNavigate;
  final ValueChanged<AccessibleLocation> onSubmitPhoto;

  /// "Add accessibility info" on a Google place; the NavAble place linked to
  /// it is passed too when there is one.
  final void Function(GooglePlace place, AccessibleLocation? linked)
  onContributeGooglePlace;

  /// Pull down to reload NavAble's places (new photos, features).
  final Future<void> Function() onRefresh;

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

/// Filter chips and the words that count as a match for each.
const _exploreFilters = <(String, IconData, List<String>)>[
  (
    'Wheelchair Accessible',
    Icons.accessible_rounded,
    ['wheelchair accessible', 'ramp', 'entrance', 'step-free'],
  ),
  ('Elevator', Icons.elevator_outlined, ['elevator', 'lift']),
  ('Accessible Restroom', Icons.wc_rounded, ['restroom', 'toilet']),
  ('Ramp', Icons.accessible_forward_rounded, ['ramp']),
  ('Braille', Icons.grid_on_rounded, ['braille', 'tactile']),
  ('Audio Assistance', Icons.hearing_rounded, ['audio']),
  // Google Maps also reports these two.
  ('Accessible Parking', Icons.local_parking_rounded, ['parking']),
  ('Wheelchair Seating', Icons.event_seat_outlined, ['seating']),
];

/// Filters only hide places known not to fit: a place with no accessibility
/// info yet (e.g. Google-only) still shows, listed after the matches.
bool _matchesFilters(Iterable<String> tags, Set<String> selected) {
  if (selected.isEmpty || tags.isEmpty) return true;
  final lower = tags.map((t) => t.toLowerCase()).toList();
  return _exploreFilters
      .where((f) => selected.contains(f.$1))
      .every((f) => f.$3.any((word) => lower.any((t) => t.contains(word))));
}

class _ExplorePageState extends State<_ExplorePage> {
  final Set<String> _selectedFilters = {};
  String _sortMode = 'Rating';
  late String _query;

  // Google search state; null results = show NavAble's own list.
  List<GooglePlace>? _googleResults;
  bool _searching = false;
  String? _searchError;
  osm.LatLng? _origin;

  @override
  void initState() {
    super.initState();
    _query = widget.searchController.text;
    _loadOrigin();
  }

  /// The user's last known spot, for distances on NavAble cards. Left
  /// unset (no distance shown) rather than guessing.
  Future<void> _loadOrigin() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null || !mounted || _origin != null) return;
      setState(() => _origin = osm.LatLng(last.latitude, last.longitude));
    } catch (_) {
      // No permission yet: cards just leave the distance out.
    }
  }

  double? _distanceToPlace(AccessibleLocation place) {
    final origin = _origin;
    if (origin == null) return null;
    return PlacesApi.distanceKm(
      origin.latitude,
      origin.longitude,
      place.latitude,
      place.longitude,
    );
  }

  /// Google place id -> NavAble place: linked by the admin, or else matched
  /// by location and name (see [matchNavAblePlace]).
  Map<String, AccessibleLocation> get _linkedPlaces {
    final byId = {
      for (final location in widget.locations)
        ?location.googlePlaceId: location,
    };
    return {
      ...byId,
      for (final place in _googleResults ?? const <GooglePlace>[])
        if (!byId.containsKey(place.id))
          place.id: ?matchNavAblePlace(place, widget.locations),
    };
  }

  Future<osm.LatLng> _searchCenter() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return osm.LatLng(last.latitude, last.longitude);
    } catch (_) {
      // No permission or no fix yet: search around Cebu City.
    }
    return _cebuMapCenter;
  }

  Future<void> _runSearch() async {
    final query = widget.searchController.text.trim();
    if (query.isEmpty || _searching) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final center = await _searchCenter();
      final results = await PlacesApi.search(
        query,
        latitude: center.latitude,
        longitude: center.longitude,
      );
      if (!mounted) return;
      setState(() {
        _origin = center;
        _googleResults = results;
      });
    } on PlacesApiException catch (error) {
      if (!mounted) return;
      // Fall back to searching NavAble's own places.
      setState(() {
        _googleResults = null;
        _searchError = error.notConfigured
            ? 'Google search isn\'t set up yet, so these are NavAble places only.'
            : '${error.message} Showing NavAble places only.';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  double? _distanceKm(GooglePlace place) {
    final origin = _origin;
    if (origin == null || place.latitude == null || place.longitude == null) {
      return null;
    }
    return PlacesApi.distanceKm(
      origin.latitude,
      origin.longitude,
      place.latitude!,
      place.longitude!,
    );
  }

  List<GooglePlace> _visibleGoogle(List<GooglePlace> results) {
    final linked = _linkedPlaces;
    final places = results
        .where(
          (p) => _matchesFilters([
            ...?linked[p.id]?.features,
            ...p.accessibilityTags,
          ], _selectedFilters),
        )
        .toList();
    switch (_sortMode) {
      case 'Distance':
        places.sort(
          (a, b) => (_distanceKm(a) ?? double.infinity).compareTo(
            _distanceKm(b) ?? double.infinity,
          ),
        );
      default:
        // NavAble's accessibility rating first, then Google's rating.
        double score(GooglePlace p) =>
            (linked[p.id]?.rating ?? -1) * 10 + (p.rating ?? 0);
        places.sort((a, b) => score(b).compareTo(score(a)));
    }
    if (_selectedFilters.isEmpty) return places;
    bool hasInfo(GooglePlace p) =>
        (linked[p.id]?.features.isNotEmpty ?? false) ||
        p.accessibilityTags.isNotEmpty;
    return [...places.where(hasInfo), ...places.where((p) => !hasInfo(p))];
  }

  List<AccessibleLocation> get _visiblePlaces {
    final normalizedQuery = _query.trim().toLowerCase();
    final places = widget.locations.where((place) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          place.name.toLowerCase().contains(normalizedQuery) ||
          place.address.toLowerCase().contains(normalizedQuery) ||
          place.features.any(
            (feature) => feature.toLowerCase().contains(normalizedQuery),
          );
      return matchesQuery && _matchesFilters(place.features, _selectedFilters);
    }).toList();

    switch (_sortMode) {
      case 'Name':
        places.sort((a, b) => a.name.compareTo(b.name));
      default:
        places.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    }
    if (_selectedFilters.isEmpty) return places;
    return [
      ...places.where((p) => p.features.isNotEmpty),
      ...places.where((p) => p.features.isEmpty),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final google = _googleResults;
    final googlePlaces = google == null ? null : _visibleGoogle(google);
    final places = google == null
        ? _visiblePlaces
        : const <AccessibleLocation>[];
    final count = googlePlaces?.length ?? places.length;
    final sortModes = google == null
        ? const ['Rating', 'Name']
        : const ['Rating', 'Distance'];
    if (!sortModes.contains(_sortMode)) _sortMode = 'Rating';
    final linked = _linkedPlaces;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: _exploreList(
        context,
        google,
        googlePlaces,
        places,
        count,
        sortModes,
        linked,
      ),
    );
  }

  Widget _exploreList(
    BuildContext context,
    List<GooglePlace>? google,
    List<GooglePlace>? googlePlaces,
    List<AccessibleLocation> places,
    int count,
    List<String> sortModes,
    Map<String, AccessibleLocation> linked,
  ) {
    return ListView(
      // Scrollable even when short, so pull-to-refresh always works.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _ExploreSearchField(
          controller: widget.searchController,
          searching: _searching,
          onChanged: (value) => setState(() {
            _query = value;
            if (value.trim().isEmpty) {
              _googleResults = null;
              _searchError = null;
            }
          }),
          onSubmitted: _runSearch,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _exploreFilters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _exploreFilters[index];
              return _AccessibilityFilterChip(
                icon: filter.$2,
                label: filter.$1,
                selected: _selectedFilters.contains(filter.$1),
                onSelected: (selected) => setState(() {
                  selected
                      ? _selectedFilters.add(filter.$1)
                      : _selectedFilters.remove(filter.$1);
                }),
              );
            },
          ),
        ),
        if (_searchError != null) ...[
          const SizedBox(height: 10),
          Text(
            _searchError!,
            style: TextStyle(color: context.navAbleSecondaryText, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    google == null
                        ? '$count ${count == 1 ? 'place' : 'places'}'
                        : '$count ${count == 1 ? 'result' : 'results'} found',
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    google == null
                        ? 'Verified NavAble places. Search to find more.'
                        : 'Places by Google · accessibility by NavAble',
                    style: TextStyle(
                      color: context.navAbleSecondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Sort places',
              initialValue: _sortMode,
              onSelected: (value) => setState(() => _sortMode = value),
              itemBuilder: (context) => [
                for (final mode in sortModes)
                  PopupMenuItem(value: mode, child: Text(mode)),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sort by $_sortMode',
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 19,
                    color: context.navAblePrimaryText,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (googlePlaces != null) ...[
          if (googlePlaces.isEmpty)
            const _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No places match',
              detail: 'Try another search or remove a filter.',
            ),
          for (final place in googlePlaces) ...[
            _GooglePlaceCard(
              place: place,
              linked: linked[place.id],
              distanceKm: _distanceKm(place),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => _GooglePlaceDetails(
                    place: place,
                    linked: linked[place.id],
                    onContribute: () =>
                        widget.onContributeGooglePlace(place, linked[place.id]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const _PoweredByGoogle(),
        ] else if (widget.locationsLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.locationsError != null)
          _EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load locations',
            detail: widget.locationsError!,
          )
        else if (places.isEmpty)
          const _EmptyState(
            icon: Icons.travel_explore_rounded,
            title: 'Search for a place',
            detail:
                'Search any place by name or type, like a mall, café, '
                'hospital or terminal, to see its accessibility.',
          )
        else
          for (final place in places) ...[
            _ExplorePlaceCard(
              place: place,
              distanceKm: _distanceToPlace(place),
              onNavigate: widget.onNavigate,
              onSubmitPhoto: widget.onSubmitPhoto,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _ExploreSearchField extends StatelessWidget {
  const _ExploreSearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.searching,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: EdgeInsets.zero,
      borderRadius: 14,
      color: context.navAbleSurface,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search any place: cafés, malls, hospitals…',
          filled: false,
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          suffixIcon: searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Search',
                  onPressed: onSubmitted,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

/// Google requires its attribution next to Places results.
class _PoweredByGoogle extends StatelessWidget {
  const _PoweredByGoogle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Powered by Google',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.navAbleSecondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Google place photo loaded through the NavAble function, with the
/// photographer credit Google requires.
class _GooglePhoto extends StatelessWidget {
  const _GooglePhoto({required this.place, this.width = 600, this.coverUrl});

  final GooglePlace place;
  final int width;

  /// Admin-uploaded NavAble photo; shown instead of Google's when present.
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = _PhotoPlaceholder();
    if (coverUrl case final url?) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        semanticLabel: 'Photo of ${place.name}',
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      );
    }
    final photo = place.photo;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photo == null)
          placeholder
        else
          Image.network(
            PlacesApi.photoUrl(photo, width: width),
            headers: PlacesApi.photoHeaders,
            fit: BoxFit.cover,
            semanticLabel: 'Photo of ${place.name}',
            errorBuilder: (_, _, _) => placeholder,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
          ),
        if (photo != null && place.photoAttribution != null)
          Positioned(
            left: 8,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  'Photo: ${place.photoAttribution}',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _formatDistance(double km) => km < 1
    ? '${(km * 1000).round()} m'
    : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

class _GooglePlaceCard extends StatelessWidget {
  const _GooglePlaceCard({
    required this.place,
    required this.linked,
    required this.distanceKm,
    required this.onTap,
  });

  final GooglePlace place;
  final AccessibleLocation? linked;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // NavAble's verified features win; otherwise what Google reports.
    final tags = linked?.features.isNotEmpty == true
        ? linked!.features
        : place.accessibilityTags;
    final navAbleRating = linked?.rating;
    final subtitle = [
      if (distanceKm != null) _formatDistance(distanceKm!),
      if (place.shortAddress.isNotEmpty) place.shortAddress,
    ].join(' • ');

    return Material(
      color: context.navAbleSurface,
      elevation: 1,
      borderRadius: BorderRadius.circular(NavAbleRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 8,
              child: _GooglePhoto(place: place, coverUrl: linked?.photoUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.navAblePrimaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (navAbleRating != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'NavAble accessibility rating',
                          child: Text(
                            navAbleRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: NavAblePalette.green,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.navAbleSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  // Like the design: Google's own rating and hours stay on
                  // the details page.
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags.take(4)) _ExploreTag(label: tag),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GooglePlaceDetails extends StatelessWidget {
  const _GooglePlaceDetails({
    required this.place,
    required this.linked,
    required this.onContribute,
  });

  final GooglePlace place;
  final AccessibleLocation? linked;
  final VoidCallback onContribute;

  Future<void> _directions(BuildContext context) async {
    final opened = await GoogleMapsLauncher.openDirections(
      latitude: place.latitude,
      longitude: place.longitude,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this location in Google Maps.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = linked?.features ?? const <String>[];
    final fromGoogle = place.accessibilityTags;
    return Scaffold(
      appBar: AppBar(title: const Text('Place Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: NavAbleSpacing.xl),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _GooglePhoto(
                place: place,
                width: 1000,
                coverUrl: linked?.photoUrl,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(NavAbleSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (place.type != null) place.type!,
                      if (place.rating != null)
                        '★ ${place.rating!.toStringAsFixed(1)} (${place.ratingCount}) on Google',
                      if (place.openNow != null)
                        place.openNow! ? 'Open now' : 'Closed now',
                    ].join(' · '),
                    style: TextStyle(color: context.navAbleSecondaryText),
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      place.address,
                      style: TextStyle(color: context.navAbleSecondaryText),
                    ),
                  ],
                  const SizedBox(height: NavAbleSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Accessibility',
                          style: TextStyle(
                            color: context.navAblePrimaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (linked?.rating case final rating?)
                        Text(
                          '${rating.toStringAsFixed(1)} on NavAble',
                          style: const TextStyle(
                            color: NavAblePalette.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (verified.isNotEmpty) ...[
                    for (final feature in verified)
                      _AccessibilityLine(
                        icon: Icons.verified_rounded,
                        color: NavAblePalette.green,
                        text: feature,
                      ),
                    Text(
                      'Verified by NavAble',
                      style: TextStyle(
                        color: context.navAbleSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ] else if (fromGoogle.isNotEmpty) ...[
                    for (final feature in fromGoogle)
                      _AccessibilityLine(
                        icon: Icons.info_outline_rounded,
                        color: context.navAbleSecondaryText,
                        text: feature,
                      ),
                    Text(
                      'Reported by Google. Not yet verified by NavAble.',
                      style: TextStyle(
                        color: context.navAbleSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ] else
                    Text(
                      'No accessibility information yet. Be the first to add it.',
                      style: TextStyle(color: context.navAbleSecondaryText),
                    ),
                  const SizedBox(height: NavAbleSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: NavAbleSize.primaryButton,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onContribute();
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add Accessibility Info'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: NavAbleSize.control,
                    child: OutlinedButton.icon(
                      onPressed: () => _directions(context),
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Directions'),
                    ),
                  ),
                  const SizedBox(height: NavAbleSpacing.md),
                  const _PoweredByGoogle(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessibilityLine extends StatelessWidget {
  const _AccessibilityLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.navAblePrimaryText),
            ),
          ),
        ],
      ),
    );
  }
}

/// A NavAble place, in the same card style as the Google results.
class _ExplorePlaceCard extends StatelessWidget {
  const _ExplorePlaceCard({
    required this.place,
    required this.distanceKm,
    required this.onNavigate,
    required this.onSubmitPhoto,
  });

  final AccessibleLocation place;
  final double? distanceKm;
  final ValueChanged<AccessibleLocation> onNavigate;
  final ValueChanged<AccessibleLocation> onSubmitPhoto;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (distanceKm != null) _formatDistance(distanceKm!),
      ?_readableAddress(place.address),
    ].join(' • ');
    final rating = place.rating;

    return Material(
      color: context.navAbleSurface,
      elevation: 1,
      borderRadius: BorderRadius.circular(NavAbleRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => _ExplorePlaceDetails(
              place: place,
              onNavigate: onNavigate,
              onSubmitPhoto: onSubmitPhoto,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 8,
              child: _CoverPhoto(url: place.photoUrl, name: place.name),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.navAblePrimaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'NavAble accessibility rating',
                          child: Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: NavAblePalette.green,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.navAbleSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (place.features.isEmpty)
                    Text(
                      'No accessibility info yet',
                      style: TextStyle(
                        color: context.navAbleSecondaryText,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final feature in place.features.take(4))
                          _ExploreTag(label: feature),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [address], or null when it's empty or just coordinates ("10.31, 123.90"),
/// which some places store in place of a street address.
String? _readableAddress(String address) {
  final text = address.trim();
  if (text.isEmpty) return null;
  final coordinates = RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$');
  return coordinates.hasMatch(text) ? null : text;
}

/// A NavAble cover photo, or the same placeholder the Google cards use.
class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final placeholder = _PhotoPlaceholder();
    final link = url;
    if (link == null) return placeholder;
    return Image.network(
      link,
      fit: BoxFit.cover,
      semanticLabel: 'Photo of $name',
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.isNavAbleDark
          ? NavAblePalette.darkBorder
          : const Color(0xFFE8EEF0),
      child: Center(
        child: Icon(
          Icons.storefront_outlined,
          size: 40,
          color: context.navAbleSecondaryText,
        ),
      ),
    );
  }
}

class _ExplorePlaceDetails extends StatelessWidget {
  const _ExplorePlaceDetails({
    required this.place,
    required this.onNavigate,
    required this.onSubmitPhoto,
  });

  final AccessibleLocation place;
  final ValueChanged<AccessibleLocation> onNavigate;
  final ValueChanged<AccessibleLocation> onSubmitPhoto;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Place Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(NavAbleSpacing.md),
          children: [
            NavAbleSurface(
              width: double.infinity,
              padding: const EdgeInsets.all(NavAbleSpacing.cardInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(NavAbleRadius.tile),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _CoverPhoto(url: place.photoUrl, name: place.name),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    place.name,
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_readableAddress(place.address) case final address?) ...[
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(color: context.navAbleSecondaryText),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: context.navAbleSecondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Accessibility',
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (place.features.isEmpty)
                    Text('No accessibility features have been added yet.'),
                  for (final feature in place.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: kNavAbleGreen,
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(feature)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: NavAbleSize.primaryButton,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onSubmitPhoto(place);
                },
                icon: Icon(Icons.add_a_photo_outlined),
                label: Text('Submit Accessibility Photos'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: NavAbleSize.primaryButton,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onNavigate(place);
                },
                icon: Icon(Icons.navigation_rounded),
                label: Text('Navigate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreTag extends StatelessWidget {
  const _ExploreTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475467),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
