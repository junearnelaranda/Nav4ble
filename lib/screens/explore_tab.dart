part of '../home.dart';

class _ExplorePage extends StatefulWidget {
  const _ExplorePage({
    required this.searchController,
    required this.locations,
    required this.locationsLoading,
    required this.locationsError,
    required this.onNavigate,
    required this.onSubmitPhoto,
  });

  final TextEditingController searchController;
  final List<AccessibleLocation> locations;
  final bool locationsLoading;
  final String? locationsError;
  final ValueChanged<AccessibleLocation> onNavigate;
  final ValueChanged<AccessibleLocation> onSubmitPhoto;

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  final Set<String> _selectedFilters = {};
  String _sortMode = 'Rating';
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.searchController.text;
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
      final matchesFilters =
          _selectedFilters.isEmpty ||
          _selectedFilters.any((filter) {
            final query = filter.toLowerCase().replaceAll('accessible ', '');
            return place.features.any(
              (feature) => feature.toLowerCase().contains(query),
            );
          });
      return matchesQuery && matchesFilters;
    }).toList();

    switch (_sortMode) {
      case 'Name':
        places.sort((a, b) => a.name.compareTo(b.name));
      default:
        places.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    }
    return places;
  }

  @override
  Widget build(BuildContext context) {
    final places = _visiblePlaces;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 90),
          children: [
            _ExploreSearchField(
              controller: widget.searchController,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final filter in const [
                      ('Wheelchair Accessible', Icons.accessible_rounded),
                      ('Elevator', Icons.elevator_outlined),
                      ('Accessible Restroom', Icons.wc_rounded),
                      ('Braille', Icons.grid_on_rounded),
                      ('Audio Assistance', Icons.hearing_rounded),
                    ]) ...[
                      _AccessibilityFilterChip(
                        icon: filter.$2,
                        label: filter.$1,
                        selected: _selectedFilters.contains(filter.$1),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedFilters.add(filter.$1);
                            } else {
                              _selectedFilters.remove(filter.$1);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${places.length} ${places.length == 1 ? 'place' : 'places'}',
                        style: TextStyle(
                          color: context.navAblePrimaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Locations from your NavAble database',
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
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'Rating', child: Text('Rating')),
                    PopupMenuItem(value: 'Name', child: Text('Name')),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sort by $_sortMode',
                        style: TextStyle(
                          color: context.navAblePrimaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 19),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.locationsLoading)
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
                icon: Icons.search_off_rounded,
                title: 'No accessible locations found',
                detail: 'Try another search or add a location to Firestore.',
              )
            else
              for (final place in places) ...[
                _ExplorePlaceCard(
                  place: place,
                  onNavigate: widget.onNavigate,
                  onSubmitPhoto: widget.onSubmitPhoto,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
        Positioned(
          right: 14,
          bottom: 14,
          child: Material(
            color: NavAblePalette.navy,
            elevation: 5,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Use my location',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Live location will be connected later.'),
                  ),
                );
              },
              color: Colors.white,
              icon: Icon(Icons.my_location_rounded, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExploreSearchField extends StatelessWidget {
  const _ExploreSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: EdgeInsets.zero,
      borderRadius: 12,
      color: context.navAbleSurface,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search accessible places',
          prefixIcon: Icon(Icons.search_rounded, size: 20),
          suffixIcon: Icon(Icons.tune_rounded, size: 19),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _ExplorePlaceCard extends StatelessWidget {
  const _ExplorePlaceCard({
    required this.place,
    required this.onNavigate,
    required this.onSubmitPhoto,
  });

  final AccessibleLocation place;
  final ValueChanged<AccessibleLocation> onNavigate;
  final ValueChanged<AccessibleLocation> onSubmitPhoto;

  @override
  Widget build(BuildContext context) {
    return NavAbleHoverLift(
      child: Material(
        color: context.navAbleSurface,
        elevation: 1,
        shadowColor: context.navAblePrimaryText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => _ExplorePlaceDetails(
                  place: place,
                  onNavigate: onNavigate,
                  onSubmitPhoto: onSubmitPhoto,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: context.isNavAbleDark
                      ? NavAblePalette.darkBorder
                      : kNavAbleAccent,
                  child: Icon(
                    Icons.accessible_rounded,
                    color: context.isNavAbleDark
                        ? NavAblePalette.green
                        : NavAblePalette.greenDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: TextStyle(
                          color: context.navAblePrimaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (place.address.isNotEmpty)
                        Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.navAbleSecondaryText,
                            fontSize: 11,
                          ),
                        ),
                      if (place.features.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final feature in place.features.take(4))
                                _ExploreTag(label: feature),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (place.rating != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, color: kNavAbleGreen, size: 16),
                  Text(place.rating!.toStringAsFixed(1)),
                ],
              ],
            ),
          ),
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
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: kNavAbleAccent,
                    child: Icon(
                      Icons.accessible_rounded,
                      color: context.navAblePrimaryText,
                      size: 30,
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
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      place.address,
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
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: Color(0xFF475467),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
