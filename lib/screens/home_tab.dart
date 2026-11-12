part of '../home.dart';

class _PlanPage extends StatelessWidget {
  const _PlanPage({
    required this.isGuest,
    required this.accessibleLocations,
    required this.locationsLoading,
    required this.locationsError,
    required this.selectedLocation,
    required this.selectedPlace,
    required this.onOpenInGoogleMaps,
    required this.destinationController,
    required this.placeSearchResults,
    required this.resultPins,
    required this.placeSearching,
    required this.searchedPlace,
    required this.routeStatus,
    required this.walkingRoute,
    required this.routing,
    required this.avoidStairs,
    required this.prioritizeElevators,
    required this.accessibleEntrance,
    required this.accessibleToilet,
    required this.tactilePaving,
    required this.accessibleParking,
    required this.wheelchairSeating,
    required this.onLocationSelected,
    required this.onAvoidStairsChanged,
    required this.onPrioritizeElevatorsChanged,
    required this.onAccessibleEntranceChanged,
    required this.onAccessibleToiletChanged,
    required this.onTactilePavingChanged,
    required this.onAccessibleParkingChanged,
    required this.onWheelchairSeatingChanged,
    required this.onDestinationChanged,
    required this.onSearchPlaces,
    required this.onSearchTapped,
    required this.onDismissSuggestions,
    required this.onPlaceSelected,
    required this.onOpenRouteDetails,
    required this.onSaveDestination,
    required this.onReportBarrier,
    required this.onSubmitAccessiblePhoto,
    required this.onSubmitPlacePhoto,
    required this.onOpenSaved,
    required this.onOpenFilters,
  });

  final bool isGuest;
  final List<AccessibleLocation> accessibleLocations;
  final bool locationsLoading;
  final String? locationsError;
  final AccessibleLocation? selectedLocation;
  final _SelectedPlace? selectedPlace;
  final VoidCallback onOpenInGoogleMaps;
  final TextEditingController destinationController;
  final List<PlaceSearchResult> placeSearchResults;

  /// The last search's places, drawn as green (accessible) or red pins.
  final List<PlaceSearchResult> resultPins;
  final bool placeSearching;
  final PlaceSearchResult? searchedPlace;
  final String? routeStatus;
  final PlannedRoute? walkingRoute;
  final bool routing;
  final bool avoidStairs;
  final bool prioritizeElevators;
  final bool accessibleEntrance;
  final bool accessibleToilet;
  final bool tactilePaving;
  final bool accessibleParking;
  final bool wheelchairSeating;
  final ValueChanged<AccessibleLocation> onLocationSelected;
  final ValueChanged<bool> onAvoidStairsChanged;
  final ValueChanged<bool> onPrioritizeElevatorsChanged;
  final ValueChanged<bool> onAccessibleEntranceChanged;
  final ValueChanged<bool> onAccessibleToiletChanged;
  final ValueChanged<bool> onTactilePavingChanged;
  final ValueChanged<bool> onAccessibleParkingChanged;
  final ValueChanged<bool> onWheelchairSeatingChanged;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onSearchPlaces;
  final VoidCallback onSearchTapped;
  final VoidCallback onDismissSuggestions;
  final ValueChanged<PlaceSearchResult> onPlaceSelected;
  final VoidCallback onOpenRouteDetails;
  final ValueChanged<AccessibleLocation> onSaveDestination;
  final VoidCallback onReportBarrier;
  final VoidCallback onSubmitAccessiblePhoto;
  final ValueChanged<AccessibleLocation> onSubmitPlacePhoto;
  final VoidCallback onOpenSaved;
  final VoidCallback onOpenFilters;

  /// Word groups for the selected chips (see [matchesAccessibilityFilters]).
  List<List<String>> get _selectedFilterWords => [
    if (avoidStairs) AccessibilityFilterWords.ramps,
    if (prioritizeElevators) AccessibilityFilterWords.elevators,
    if (accessibleEntrance) AccessibilityFilterWords.entrance,
    if (accessibleToilet) AccessibilityFilterWords.toilet,
    if (tactilePaving) AccessibilityFilterWords.tactile,
    if (accessibleParking) AccessibilityFilterWords.parking,
    if (wheelchairSeating) AccessibilityFilterWords.seating,
  ];

  @override
  Widget build(BuildContext context) {
    final filters = _selectedFilterWords;
    // Green pins have accessibility info, red pins none yet (filters never
    // change that). With filters on, pins that don't match are faded, and
    // only places confirmed to lack a chosen feature are hidden.
    final matching = accessibleLocations
        .where(
          (l) =>
              filterMatch(has: l.features, selected: filters) ==
              FilterMatch.matches,
        )
        .toList();
    final selected = selectedLocation;
    final pins = [
      for (final location in accessibleLocations)
        if (filterMatch(has: location.features, selected: filters) !=
                FilterMatch.excluded ||
            // The selected place stays on the map even if it doesn't match.
            location.id == selected?.id)
          location,
    ];
    final visibleResults = [
      for (final result in resultPins)
        if (filterMatch(has: [?result.accessibility], selected: filters) !=
                FilterMatch.excluded ||
            result.point == searchedPlace?.point)
          result,
    ];
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final actionButtons = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _MapActionButton(
          icon: Icons.bookmark_border_rounded,
          tooltip: 'Saved places',
          label: 'Saved',
          onPressed: onOpenSaved,
        ),
        const SizedBox(height: 9),
        _MapActionButton(
          icon: Icons.campaign_outlined,
          tooltip: 'Report an accessibility issue',
          label: 'Report',
          onPressed: onReportBarrier,
        ),
        const SizedBox(height: 9),
        _MapActionButton(
          icon: Icons.document_scanner_outlined,
          tooltip: 'Scan an accessibility feature',
          label: 'Scan',
          onPressed: onSubmitAccessiblePhoto,
        ),
      ],
    );
    return Stack(
      children: [
        Positioned.fill(
          child: _OpenStreetMapView(
            key: ValueKey(accessibleLocations.isNotEmpty),
            initialPosition: selectedLocation == null
                ? _cebuMapCenter
                : osm.LatLng(
                    selectedLocation!.latitude,
                    selectedLocation!.longitude,
                  ),
            showLocationButton: true,
            locations: pins,
            // With filters on, pins that don't match them are faded.
            isConfirmed: (location) =>
                filters.isEmpty ||
                filterMatch(has: location.features, selected: filters) ==
                    FilterMatch.matches,
            isResultConfirmed: (result) =>
                filters.isEmpty ||
                filterMatch(has: [?result.accessibility], selected: filters) ==
                    FilterMatch.matches,
            route: walkingRoute,
            searchedPlace: searchedPlace,
            searchResults: visibleResults,
            onSearchResultTapped: onPlaceSelected,
            selectedLocationId: selectedLocation?.id,
            onAccessibleLocationTapped: onLocationSelected,
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 12,
          child: Column(
            children: [
              // A tap anywhere else (map, pins, chips) hides the
              // suggestions so the pins are easy to see.
              TapRegion(
                onTapOutside: (_) => onDismissSuggestions(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HomeSearchBar(
                      controller: destinationController,
                      onSubmitted: (_) => onSearchPlaces(),
                      onChanged: onDestinationChanged,
                      onTap: onSearchTapped,
                      onFilterPressed: onOpenFilters,
                      onSearchPressed: onSearchPlaces,
                    ),
                    if (placeSearching || placeSearchResults.isNotEmpty)
                      _PlaceSearchResults(
                        results: placeSearchResults,
                        loading: placeSearching,
                        onSelected: onPlaceSelected,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _AccessibilityFilterChip(
                        icon: Icons.accessible_forward_rounded,
                        label: 'Ramps',
                        selected: avoidStairs,
                        onSelected: onAvoidStairsChanged,
                      ),
                      const SizedBox(width: 8),
                      _AccessibilityFilterChip(
                        icon: Icons.elevator_outlined,
                        label: 'Elevators',
                        selected: prioritizeElevators,
                        onSelected: onPrioritizeElevatorsChanged,
                      ),
                      const SizedBox(width: 8),
                      _AccessibilityFilterChip(
                        icon: Icons.meeting_room_outlined,
                        label: 'Entrance',
                        selected: accessibleEntrance,
                        onSelected: onAccessibleEntranceChanged,
                      ),
                      const SizedBox(width: 8),
                      _AccessibilityFilterChip(
                        icon: Icons.wc_rounded,
                        label: 'Accessible Toilet',
                        selected: accessibleToilet,
                        onSelected: onAccessibleToiletChanged,
                      ),
                      const SizedBox(width: 8),
                      _AccessibilityFilterChip(
                        icon: Icons.blind_rounded,
                        label: 'Tactile Paving',
                        selected: tactilePaving,
                        onSelected: onTactilePavingChanged,
                      ),
                      const SizedBox(width: 8),
                      _AccessibilityFilterChip(
                        icon: Icons.local_parking_rounded,
                        label: 'Parking',
                        selected: accessibleParking,
                        onSelected: onAccessibleParkingChanged,
                      ),
                      const SizedBox(width: 8),
                      _AccessibilityFilterChip(
                        icon: Icons.event_seat_outlined,
                        label: 'Seating',
                        selected: wheelchairSeating,
                        onSelected: onWheelchairSeatingChanged,
                      ),
                    ],
                  ),
                ),
              ),
              if (filters.isNotEmpty &&
                  !locationsLoading &&
                  accessibleLocations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _MapLabel(
                    icon: matching.isEmpty
                        ? Icons.filter_alt_off_rounded
                        : Icons.filter_alt_rounded,
                    label: matching.isEmpty
                        ? 'No verified matches yet. Red pins have no info.'
                        : '${matching.length} '
                              '${matching.length == 1 ? 'place matches' : 'places match'}'
                              ' your filters',
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 12,
          // Wide screens: leave room for the fixed buttons on the right.
          right: wide ? 170 : 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Narrow screens: the card spans the width, so the buttons sit
              // above it. Wide screens give them their own fixed spot.
              if (!isGuest && !wide) ...[
                Align(alignment: Alignment.centerRight, child: actionButtons),
                const SizedBox(height: 12),
              ],
              if (routeStatus != null) ...[
                Material(
                  color: context.navAbleSurface,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            routeStatus!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.navAbleSecondaryText,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (walkingRoute != null)
                          TextButton(
                            onPressed: onOpenRouteDetails,
                            child: const Text('View Route Details'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  // The place card shows only once a place is picked; until
                  // then the map stays clear (a loading error still shows).
                  child: switch (selectedPlace) {
                    null when locationsError != null => _NearbyLocationMessage(
                      loading: false,
                      error: locationsError,
                      hasLocations: accessibleLocations.isNotEmpty,
                    ),
                    null => const SizedBox.shrink(),
                    final place => _AutoCollapsePlaceCard(
                      place: place,
                      onOpenMaps: onOpenInGoogleMaps,
                      onSave: switch (place.accessibleLocation) {
                        null => null,
                        final location => () => onSaveDestination(location),
                      },
                      onAddPhoto: switch (place.accessibleLocation) {
                        null => null,
                        final location => () => onSubmitPlacePhoto(location),
                      },
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
        // Wide screens: fixed at the bottom right, beside the place card,
        // so they don't move when the card grows.
        if (!isGuest && wide)
          Positioned(right: 12, bottom: 12, child: actionButtons),
      ],
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onChanged,
    required this.onTap,
    required this.onFilterPressed,
    required this.onSearchPressed,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final VoidCallback onFilterPressed;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: EdgeInsets.zero,
      borderRadius: 24,
      color: context.navAbleSurface,
      child: SizedBox(
        height: NavAbleSize.compactControl,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: 'Where would you like to go?',
            hintStyle: TextStyle(
              color: context.navAbleSecondaryText,
              fontSize: 12,
            ),
            prefixIcon: IconButton(
              tooltip: 'Search places',
              onPressed: onSearchPressed,
              icon: Icon(
                Icons.search_rounded,
                color: context.navAbleSecondaryText,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints.tightFor(
              width: 44,
              height: NavAbleSize.compactControl,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    tooltip: 'Route filters',
                    padding: EdgeInsets.zero,
                    onPressed: onFilterPressed,
                    icon: const Icon(Icons.tune_rounded, size: 19),
                  ),
                ),
                SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    tooltip: 'Voice search',
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice search coming soon.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.mic_none_rounded, size: 20),
                  ),
                ),
              ],
            ),
            suffixIconConstraints: const BoxConstraints.tightFor(
              width: 80,
              height: NavAbleSize.compactControl,
            ),
            border: InputBorder.none,
            filled: false,
            hintMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchResults extends StatelessWidget {
  const _PlaceSearchResults({
    required this.results,
    required this.loading,
    required this.onSelected,
  });

  final List<PlaceSearchResult> results;
  final bool loading;
  final ValueChanged<PlaceSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.navAbleSurface,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          // About 3½ rows tall, so the result pins stay visible on the map.
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < results.length; index++) ...[
                      if (index > 0)
                        const Divider(height: 1, indent: 48, endIndent: 12),
                      ListTile(
                        dense: true,
                        // Same colors as the map pins: green = accessible.
                        leading: Icon(
                          results[index].isAccessible
                              ? Icons.accessible_rounded
                              : Icons.place_rounded,
                          color: results[index].isAccessible
                              ? (context.isNavAbleDark
                                    ? NavAblePalette.green
                                    : NavAblePalette.greenDark)
                              : _pushPinRed,
                        ),
                        title: Text(
                          results[index].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          results[index].accessibility ??
                              results[index].displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onSelected(results[index]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _AccessibilityFilterChip extends StatelessWidget {
  const _AccessibilityFilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isNavAbleDark;
    final labelColor = selected ? kNavAbleNavy : context.navAblePrimaryText;
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: Icon(icon, size: 17, color: labelColor),
      label: Text(label),
      showCheckmark: false,
      backgroundColor: isDark ? NavAblePalette.darkSurface : Colors.white,
      selectedColor: const Color(0xFF9AF5AE),
      side: BorderSide(
        color: selected
            ? const Color(0xFF7DE493)
            : isDark
            ? NavAblePalette.darkBorder
            : const Color(0xFFD0D5DD),
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: labelColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(!value),
          child: SizedBox(
            height: NavAbleSize.control,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, color: kNavAbleNavy, size: 20),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF202630),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: value,
                    onChanged: (nextValue) => onChanged(nextValue ?? false),
                    activeColor: kNavAbleNavy,
                    checkColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(
                      color: Color(0xFF7F8790),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: kNavAbleNavy,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                label!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        NavAbleHoverLift(
          child: Material(
            color: context.navAbleSurface,
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              color: context.navAblePrimaryText,
              icon: Icon(icon, size: 21),
            ),
          ),
        ),
      ],
    );
  }
}

/// The destination the user picked: a NavAble (Supabase) location or a
/// place search result. Built from the live selection, never stored.
class _SelectedPlace {
  const _SelectedPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.accessibleLocation,
  });

  factory _SelectedPlace.fromAccessible(AccessibleLocation location) =>
      _SelectedPlace(
        name: location.name,
        address: location.address,
        latitude: location.latitude,
        longitude: location.longitude,
        accessibleLocation: location,
      );

  factory _SelectedPlace.fromSearch(
    PlaceSearchResult place, {
    AccessibleLocation? accessibleLocation,
  }) => _SelectedPlace(
    name: accessibleLocation?.name ?? place.name,
    address: accessibleLocation?.address ?? place.displayName,
    latitude: place.point.latitude,
    longitude: place.point.longitude,
    accessibleLocation: accessibleLocation,
  );

  final String name;
  final String address;
  final double latitude;
  final double longitude;

  /// Set when NavAble has accessibility data for this place.
  final AccessibleLocation? accessibleLocation;

  String get key => accessibleLocation?.id ?? '$latitude,$longitude';
}

/// Small pill so labels stay readable on any map tile.
class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.navAbleSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(NavAbleRadius.pill),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.navAblePrimaryText, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: context.navAblePrimaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the selected place. Tapping the card (expanded or collapsed)
/// opens the place in Google Maps.
class _AutoCollapsePlaceCard extends StatefulWidget {
  const _AutoCollapsePlaceCard({
    required this.place,
    required this.onOpenMaps,
    this.onSave,
    this.onAddPhoto,
  });

  final _SelectedPlace place;
  final VoidCallback onOpenMaps;
  final VoidCallback? onSave;
  final VoidCallback? onAddPhoto;

  @override
  State<_AutoCollapsePlaceCard> createState() => _AutoCollapsePlaceCardState();
}

class _AutoCollapsePlaceCardState extends State<_AutoCollapsePlaceCard> {
  static const _openDuration = Duration(seconds: 4);
  static const _animationDuration = Duration(milliseconds: 260);

  Timer? _collapseTimer;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _scheduleCollapse();
  }

  @override
  void didUpdateWidget(covariant _AutoCollapsePlaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.key != widget.place.key) {
      _expanded = true;
      _scheduleCollapse();
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_openDuration, () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _expand() {
    setState(() => _expanded = true);
    _scheduleCollapse();
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The card stays a light surface in both themes: it is the main action
    // on the map and reads best as a bright card over the dark map.
    return NavAbleLightTheme(
      child: MouseRegion(
        // Don't collapse while a mouse user is looking at the card.
        onEnter: (_) => _collapseTimer?.cancel(),
        onExit: (_) {
          if (_expanded) _scheduleCollapse();
        },
        child: AnimatedSize(
          duration: _animationDuration,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.bottomLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _expanded
                ? _PlaceDetailsCard(
                    key: ValueKey('expanded-${widget.place.key}'),
                    place: widget.place,
                    onOpenMaps: widget.onOpenMaps,
                    onSave: widget.onSave,
                    onAddPhoto: widget.onAddPhoto,
                  )
                : _CollapsedPlaceCard(
                    key: ValueKey('collapsed-${widget.place.key}'),
                    place: widget.place,
                    onOpenMaps: widget.onOpenMaps,
                    onExpand: _expand,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PlaceDetailsCard extends StatefulWidget {
  const _PlaceDetailsCard({
    super.key,
    required this.place,
    required this.onOpenMaps,
    this.onSave,
    this.onAddPhoto,
  });

  final _SelectedPlace place;
  final VoidCallback onOpenMaps;
  final VoidCallback? onSave;
  final VoidCallback? onAddPhoto;

  @override
  State<_PlaceDetailsCard> createState() => _PlaceDetailsCardState();
}

class _PlaceDetailsCardState extends State<_PlaceDetailsCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final location = place.accessibleLocation;
    final radius = BorderRadius.circular(NavAbleRadius.card);

    return Semantics(
      button: true,
      hint: 'Opens directions in Google Maps',
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _hovered ? NavAblePalette.green : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.34 : 0.24),
                blurRadius: _hovered ? 22 : 16,
                offset: Offset(0, _hovered ? 8 : 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onOpenMaps,
              onHover: (value) => setState(() => _hovered = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              mouseCursor: SystemMouseCursors.click,
              splashColor: NavAblePalette.green.withValues(alpha: 0.2),
              highlightColor: NavAblePalette.green.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kNavAbleNavy,
                                  fontSize: 16,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (place.address.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  place.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kNavAbleText,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (location?.rating case final rating?) ...[
                          const SizedBox(width: 8),
                          _RatingBadge(rating: rating),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (location == null)
                      const _AccessibilityNote(
                        icon: Icons.info_outline_rounded,
                        text:
                            'No NavAble accessibility data for this place yet.',
                      )
                    else if (location.features.isEmpty)
                      const _AccessibilityNote(
                        icon: Icons.accessible_rounded,
                        text: 'No accessibility features reported yet.',
                      )
                    else ...[
                      const _AccessibilityNote(
                        icon: Icons.accessible_rounded,
                        text: 'Accessibility features',
                        emphasized: true,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final feature in location.features.take(4))
                            _PlaceTag(label: feature.toUpperCase()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.onAddPhoto != null)
                          IconButton(
                            tooltip:
                                'Submit accessibility photos for '
                                '${place.name}',
                            onPressed: widget.onAddPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            color: kNavAbleNavy,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (widget.onSave != null)
                          IconButton(
                            tooltip: 'Save destination',
                            onPressed: widget.onSave,
                            icon: const Icon(Icons.bookmark_border_rounded),
                            color: kNavAbleNavy,
                            visualDensity: VisualDensity.compact,
                          ),
                        const Spacer(),
                        _OpenInMapsHint(highlighted: _hovered),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessibilityNote extends StatelessWidget {
  const _AccessibilityNote({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? NavAblePalette.greenDark : kNavAbleText;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: emphasized ? kNavAbleNavy : kNavAbleText,
              fontSize: 12,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Visual cue that the card opens Google Maps. The card itself is the
/// button, so this is not a separate tap target.
class _OpenInMapsHint extends StatelessWidget {
  const _OpenInMapsHint({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted ? NavAblePalette.greenDark : kNavAbleNavy,
          borderRadius: BorderRadius.circular(NavAbleRadius.pill),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'Directions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
          ],
        ),
      ),
    );
  }
}

class _CollapsedPlaceCard extends StatelessWidget {
  const _CollapsedPlaceCard({
    super.key,
    required this.place,
    required this.onOpenMaps,
    required this.onExpand,
  });

  final _SelectedPlace place;
  final VoidCallback onOpenMaps;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(NavAbleRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Semantics(
              button: true,
              hint: 'Opens directions in Google Maps',
              child: InkWell(
                onTap: onOpenMaps,
                mouseCursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        color: kNavAbleNavy,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kNavAbleNavy,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.directions_rounded,
                        color: NavAblePalette.greenDark,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Show place details',
            onPressed: onExpand,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            color: kNavAbleNavy,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _NearbyLocationMessage extends StatelessWidget {
  const _NearbyLocationMessage({
    required this.loading,
    required this.hasLocations,
    this.error,
  });

  final bool loading;
  final bool hasLocations;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      child: Row(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.location_searching_rounded,
              color: context.navAblePrimaryText,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading
                  ? 'Loading accessible locations…'
                  : error ??
                        (hasLocations
                            ? 'Tap a pin or search for a place to choose '
                                  'a destination.'
                            : 'No accessible locations are available yet.'),
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceTag extends StatelessWidget {
  const _PlaceTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFDDF8E4),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF147A39),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9AF5AE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: kNavAbleNavy, size: 14),
          SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: kNavAbleNavy,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
