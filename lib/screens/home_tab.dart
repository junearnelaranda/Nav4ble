part of '../home.dart';

class _PlanPage extends StatelessWidget {
  const _PlanPage({
    required this.mapKey,
    required this.mapSearch,
    required this.onSearch,
    required this.isGuest,
    required this.destinationController,
    required this.routeStatus,
    required this.avoidStairs,
    required this.prioritizeElevators,
    required this.accessibleEntrance,
    required this.accessibleToilet,
    required this.tactilePaving,
    required this.audioAssistance,
    required this.reports,
    required this.onAvoidStairsChanged,
    required this.onPrioritizeElevatorsChanged,
    required this.onAccessibleEntranceChanged,
    required this.onAccessibleToiletChanged,
    required this.onTactilePavingChanged,
    required this.onAudioAssistanceChanged,
    required this.onPlanRoute,
    required this.onSaveDestination,
    required this.onReportBarrier,
    required this.onOpenSaved,
    required this.onOpenFilters,
  });

  final bool isGuest;
  final GlobalKey<NavAbleMapState> mapKey;
  final MapSearchController mapSearch;
  final VoidCallback onSearch;
  final TextEditingController destinationController;
  final String? routeStatus;
  final bool avoidStairs;
  final bool prioritizeElevators;
  final bool accessibleEntrance;
  final bool accessibleToilet;
  final bool tactilePaving;
  final bool audioAssistance;
  final List<AccessReport> reports;
  final ValueChanged<bool> onAvoidStairsChanged;
  final ValueChanged<bool> onPrioritizeElevatorsChanged;
  final ValueChanged<bool> onAccessibleEntranceChanged;
  final ValueChanged<bool> onAccessibleToiletChanged;
  final ValueChanged<bool> onTactilePavingChanged;
  final ValueChanged<bool> onAudioAssistanceChanged;
  final VoidCallback onPlanRoute;
  final VoidCallback onSaveDestination;
  final VoidCallback onReportBarrier;
  final VoidCallback onOpenSaved;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: NavAbleMap(
            key: mapKey,
            searchController: mapSearch,
            onDestinationSelected: (name) => destinationController.text = name,
            padding: EdgeInsets.only(
              top: 190,
              bottom: routeStatus == null ? 160 : 240,
            ),
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
                onSubmitted: (_) => onSearch(),
                onFilterPressed: onOpenFilters,
              ),
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: mapSearch,
                builder: (context, _) => mapSearch.message == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                if (mapSearch.isSearching) ...[
                                  const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      mapSearch.message!,
                                      style: const TextStyle(
                                        color: kNavAbleNavy,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
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
          bottom: routeStatus == null ? 88 : 178,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MapActionButton(
                icon: Icons.my_location_rounded,
                tooltip: 'My location',
                onPressed: () => mapKey.currentState?.centerOnUser(),
              ),
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
                  icon: Icons.qr_code_scanner_rounded,
                  tooltip: 'Scan accessibility code',
                  label: 'Scan',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Accessibility scanner coming soon.'),
                      ),
                    );
                  },
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
                      ],
                    ),
                  ),
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
                      'Demo Accessible Places',
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
                        child: _NearbyPlaceCard(onSave: onSaveDestination),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: 180,
                    child: _StartNavigationButton(onPressed: onPlanRoute),
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
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterPressed;

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
          decoration: InputDecoration(
            hintText: 'Where would you like to go?',
            hintStyle: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            prefixIcon: IconButton(
              tooltip: 'Search map',
              onPressed: () => onSubmitted(controller.text),
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

class _NearbyPlaceCard extends StatelessWidget {
  const _NearbyPlaceCard({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 18),
      borderRadius: 12,
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ayala Central Bloc',
                  style: TextStyle(
                    color: kNavAbleNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '0.7 miles • Transit',
                  style: TextStyle(color: kNavAbleText, fontSize: 10),
                ),
                SizedBox(height: 5),
                Wrap(
                  spacing: 5,
                  children: [
                    _PlaceTag(label: 'RAMP'),
                    _PlaceTag(label: 'LIFT'),
                  ],
                ),
              ],
            ),
          ),
          const _RatingBadge(),
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
  const _RatingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9AF5AE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: kNavAbleNavy, size: 14),
          SizedBox(width: 3),
          Text(
            '4.9',
            style: TextStyle(
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
  const _StartNavigationButton({required this.onPressed});

  final VoidCallback onPressed;

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
        icon: const Icon(Icons.navigation_rounded, size: 20),
        label: const Text(
          'Start Navigation',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
