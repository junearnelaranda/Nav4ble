part of '../home.dart';

class _PlanPage extends StatelessWidget {
  const _PlanPage({
    required this.isGuest,
    required this.accessibleLocations,
    required this.locationsLoading,
    required this.locationsError,
    required this.selectedLocation,
    required this.destinationController,
    required this.placeSearchResults,
    required this.placeSearching,
    required this.searchedPlace,
    required this.routeStatus,
    required this.walkingRoute,
    required this.routing,
    required this.travelMode,
    required this.routeDurations,
    required this.destinationSelected,
    required this.avoidStairs,
    required this.prioritizeElevators,
    required this.accessibleEntrance,
    required this.accessibleToilet,
    required this.tactilePaving,
    required this.audioAssistance,
    required this.onLocationSelected,
    required this.onAvoidStairsChanged,
    required this.onPrioritizeElevatorsChanged,
    required this.onAccessibleEntranceChanged,
    required this.onAccessibleToiletChanged,
    required this.onTactilePavingChanged,
    required this.onAudioAssistanceChanged,
    required this.onPlanRoute,
    required this.onRouteModeSelected,
    required this.onDestinationChanged,
    required this.onSearchPlaces,
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
  final TextEditingController destinationController;
  final List<PlaceSearchResult> placeSearchResults;
  final bool placeSearching;
  final PlaceSearchResult? searchedPlace;
  final String? routeStatus;
  final PlannedRoute? walkingRoute;
  final bool routing;
  final TravelMode travelMode;
  final Map<TravelMode, double> routeDurations;
  final bool destinationSelected;
  final bool avoidStairs;
  final bool prioritizeElevators;
  final bool accessibleEntrance;
  final bool accessibleToilet;
  final bool tactilePaving;
  final bool audioAssistance;
  final ValueChanged<AccessibleLocation> onLocationSelected;
  final ValueChanged<bool> onAvoidStairsChanged;
  final ValueChanged<bool> onPrioritizeElevatorsChanged;
  final ValueChanged<bool> onAccessibleEntranceChanged;
  final ValueChanged<bool> onAccessibleToiletChanged;
  final ValueChanged<bool> onTactilePavingChanged;
  final ValueChanged<bool> onAudioAssistanceChanged;
  final VoidCallback onPlanRoute;
  final ValueChanged<TravelMode> onRouteModeSelected;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onSearchPlaces;
  final ValueChanged<PlaceSearchResult> onPlaceSelected;
  final VoidCallback onOpenRouteDetails;
  final ValueChanged<AccessibleLocation> onSaveDestination;
  final VoidCallback onReportBarrier;
  final VoidCallback onSubmitAccessiblePhoto;
  final ValueChanged<AccessibleLocation> onSubmitPlacePhoto;
  final VoidCallback onOpenSaved;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
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
            locations: accessibleLocations,
            route: walkingRoute,
            searchedPlace: searchedPlace,
            onAccessibleLocationTapped: onLocationSelected,
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 12,
          child: Column(
            children: [
              _HomeSearchBar(
                controller: destinationController,
                onSubmitted: (_) => onSearchPlaces(),
                onChanged: onDestinationChanged,
                onFilterPressed: onOpenFilters,
                onSearchPressed: onSearchPlaces,
              ),
              if (placeSearching || placeSearchResults.isNotEmpty)
                _PlaceSearchResults(
                  results: placeSearchResults,
                  loading: placeSearching,
                  onSelected: onPlaceSelected,
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
                        label: 'Ramps Only',
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
                        icon: Icons.hearing_rounded,
                        label: 'Audio Assistance',
                        selected: audioAssistance,
                        onSelected: onAudioAssistanceChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: walkingRoute != null
              ? 230
              : routeStatus == null
              ? 88
              : 178,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isGuest) ...[
                const SizedBox(height: 9),
                _MapActionButton(
                  icon: Icons.bookmark_border_rounded,
                  tooltip: 'Saved places',
                  label: 'Saved',
                  onPressed: onOpenSaved,
                ),
                const SizedBox(height: 9),
                _MapActionButton(
                  icon: Icons.campaign_outlined,
                  tooltip: 'Report a barrier',
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
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (routeStatus != null) ...[
                Material(
                  color: Colors.white,
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
                            style: const TextStyle(
                              color: kNavAbleText,
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
              if (walkingRoute != null) ...[
                _RouteModeOptions(
                  selectedMode: travelMode,
                  durations: routeDurations,
                  enabled: !routing,
                  onSelected: onRouteModeSelected,
                ),
                const SizedBox(height: 8),
              ],
              const Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.accessible_rounded,
                      color: kNavAbleNavy,
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Accessible Locations',
                      style: TextStyle(
                        color: kNavAbleNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: selectedLocation == null
                            ? _NearbyLocationMessage(
                                loading: locationsLoading,
                                error: locationsError,
                              )
                            : _AutoCollapsePlaceCard(
                                location: selectedLocation!,
                                onSave: () =>
                                    onSaveDestination(selectedLocation!),
                                onAddPhoto: () =>
                                    onSubmitPlacePhoto(selectedLocation!),
                              ),
                      ),
                    ),
                  ),
                  if (destinationSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      width: 180,
                      child: _StartNavigationButton(
                        onPressed: routing ? null : onPlanRoute,
                        loading: routing,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onChanged,
    required this.onFilterPressed,
    required this.onSearchPressed,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: EdgeInsets.zero,
      borderRadius: 24,
      color: Colors.white,
      child: SizedBox(
        height: NavAbleSize.compactControl,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Where would you like to go?',
            hintStyle: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            prefixIcon: IconButton(
              tooltip: 'Search places',
              onPressed: onSearchPressed,
              icon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF475467),
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
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < results.length; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, indent: 48, endIndent: 12),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: kNavAbleNavy),
                    title: Text(
                      results[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      results[index].displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelected(results[index]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _RouteModeOptions extends StatelessWidget {
  const _RouteModeOptions({
    required this.selectedMode,
    required this.durations,
    required this.enabled,
    required this.onSelected,
  });

  final TravelMode selectedMode;
  final Map<TravelMode, double> durations;
  final bool enabled;
  final ValueChanged<TravelMode> onSelected;

  @override
  Widget build(BuildContext context) {
    const modes = [
      (TravelMode.walking, Icons.directions_walk_rounded),
      (TravelMode.car, Icons.directions_car_rounded),
      (TravelMode.motorcycle, Icons.motorcycle_rounded),
    ];

    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            for (final (mode, icon) in modes)
              Expanded(
                child: _RouteModeOption(
                  mode: mode,
                  icon: icon,
                  selected: selectedMode == mode,
                  enabled: enabled,
                  durationSeconds: durations[mode],
                  onTap: () => onSelected(mode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteModeOption extends StatelessWidget {
  const _RouteModeOption({
    required this.mode,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.durationSeconds,
    required this.onTap,
  });

  final TravelMode mode;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final double? durationSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutes = durationSeconds == null
        ? '-- min'
        : '${(durationSeconds! / 60).round()} min';
    final label = '${mode.label}, $minutes';

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? kNavAbleNavy.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? kNavAbleNavy : const Color(0xFF667085),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    minutes,
                    style: TextStyle(
                      color: selected ? kNavAbleNavy : const Color(0xFF475467),
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: Icon(icon, size: 17),
      label: Text(label),
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF9AF5AE),
      side: BorderSide(
        color: selected ? const Color(0xFF7DE493) : const Color(0xFFD0D5DD),
      ),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: kNavAbleNavy,
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
            color: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              color: kNavAbleNavy,
              icon: Icon(icon, size: 21),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoCollapsePlaceCard extends StatefulWidget {
  const _AutoCollapsePlaceCard({
    required this.location,
    required this.onSave,
    required this.onAddPhoto,
  });

  final AccessibleLocation location;
  final VoidCallback onSave;
  final VoidCallback onAddPhoto;

  @override
  State<_AutoCollapsePlaceCard> createState() =>
      _AutoCollapsePlaceCardState();
}

class _AutoCollapsePlaceCardState extends State<_AutoCollapsePlaceCard> {
  static const _openDuration = Duration(seconds: 3);
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
    if (oldWidget.location.id != widget.location.id) {
      _collapseTimer?.cancel();
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
    return AnimatedSize(
      duration: _animationDuration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.bottomLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _expanded
            ? _NearbyPlaceCard(
                key: ValueKey('expanded-${widget.location.id}'),
                location: widget.location,
                onSave: widget.onSave,
                onAddPhoto: widget.onAddPhoto,
              )
            : Material(
                key: ValueKey('collapsed-${widget.location.id}'),
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _expand,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                            widget.location.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kNavAbleNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: kNavAbleNavy,
                          size: 19,
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

class _NearbyPlaceCard extends StatelessWidget {
  const _NearbyPlaceCard({
    super.key,
    required this.location,
    required this.onSave,
    required this.onAddPhoto,
  });

  final AccessibleLocation location;
  final VoidCallback onSave;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 18),
      borderRadius: 12,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: const TextStyle(
                    color: kNavAbleNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kNavAbleText, fontSize: 10),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 5,
                  children: [
                    for (final feature in location.features.take(3))
                      _PlaceTag(label: feature.toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
          if (location.rating != null) _RatingBadge(rating: location.rating!),
          IconButton(
            tooltip: 'Submit accessibility photos for ${location.name}',
            onPressed: onAddPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            color: kNavAbleNavy,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Save destination',
            onPressed: onSave,
            icon: const Icon(Icons.bookmark_border_rounded),
            color: kNavAbleNavy,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _NearbyLocationMessage extends StatelessWidget {
  const _NearbyLocationMessage({required this.loading, this.error});

  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      color: Colors.white,
      child: Row(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.location_searching_rounded, color: kNavAbleNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading
                  ? 'Loading accessible locations…'
                  : error ?? 'No accessible locations are available yet.',
              style: const TextStyle(color: kNavAbleText, fontSize: 12),
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
            fontSize: 9,
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

class _StartNavigationButton extends StatelessWidget {
  const _StartNavigationButton({required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NavAbleSize.primaryButton,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kNavAbleNavy,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const StadiumBorder(),
        ),
        icon: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.navigation_rounded, size: 20),
        label: Text(
          loading ? 'Finding Route…' : 'Start Navigation',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
