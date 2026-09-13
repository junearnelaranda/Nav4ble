part of '../home.dart';

class _ExplorePage extends StatefulWidget {
  const _ExplorePage({
    required this.searchController,
    required this.onNavigate,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onNavigate;

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  final Set<String> _selectedFilters = {'Wheelchair Accessible'};
  String _sortMode = 'Rating';
  late String _query;

  static const List<_ExplorePlace> _places = [
    _ExplorePlace(
      name: 'Abaca Baking Company',
      location: 'Ayala Center Cebu',
      distance: '0.3 km',
      score: 4.9,
      tags: ['Ramp', 'Elevator', 'Accessible Restroom'],
      icon: Icons.bakery_dining_rounded,
    ),
    _ExplorePlace(
      name: 'Figaro Coffee',
      location: 'Cebu Business Park',
      distance: '0.5 km',
      score: 4.8,
      tags: ['Ramp', 'Braille', 'Accessible Entrance'],
      icon: Icons.local_cafe_rounded,
    ),
    _ExplorePlace(
      name: "Bo's Coffee",
      location: 'Ayala Terraces',
      distance: '0.9 km',
      score: 4.6,
      tags: ['Priority Parking', 'Transit Hub'],
      icon: Icons.coffee_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _query = widget.searchController.text;
  }

  List<_ExplorePlace> get _visiblePlaces {
    final normalizedQuery = _query.trim().toLowerCase();
    final isGeneralCafeSearch =
        normalizedQuery.isEmpty ||
        normalizedQuery.contains('cafe') ||
        normalizedQuery.contains('coffee');
    final places = _places.where((place) {
      return isGeneralCafeSearch ||
          place.name.toLowerCase().contains(normalizedQuery) ||
          place.location.toLowerCase().contains(normalizedQuery);
    }).toList();

    switch (_sortMode) {
      case 'Name':
        places.sort((a, b) => a.name.compareTo(b.name));
      case 'Distance':
        places.sort((a, b) => a.distance.compareTo(b.distance));
      default:
        places.sort((a, b) => b.score.compareTo(a.score));
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
                        '${places.length} demo ${places.length == 1 ? 'place' : 'places'}',
                        style: const TextStyle(
                          color: kNavAbleNavy,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Local preview — no live places API yet',
                        style: TextStyle(color: kNavAbleText, fontSize: 11),
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
                    PopupMenuItem(value: 'Distance', child: Text('Distance')),
                    PopupMenuItem(value: 'Name', child: Text('Name')),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sort by $_sortMode',
                        style: const TextStyle(
                          color: kNavAbleNavy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (places.isEmpty)
              const _EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No demo places found',
                detail: 'Try searching for café, coffee, or Cebu.',
              )
            else
              for (final place in places) ...[
                _ExplorePlaceCard(
                  place: place,
                  onNavigate: widget.onNavigate,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
        Positioned(
          right: 14,
          bottom: 14,
          child: Material(
            color: kNavAbleNavy,
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
              icon: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExplorePlace {
  const _ExplorePlace({
    required this.name,
    required this.location,
    required this.distance,
    required this.score,
    required this.tags,
    required this.icon,
  });

  final String name;
  final String location;
  final String distance;
  final double score;
  final List<String> tags;
  final IconData icon;
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
      color: Colors.white,
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
  const _ExplorePlaceCard({required this.place, required this.onNavigate});

  final _ExplorePlace place;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return NavAbleHoverLift(
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: kNavAbleNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => _ExplorePlaceDetails(
                  place: place,
                  onNavigate: onNavigate,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 112,
                width: double.infinity,
                color: const Color(0xFFE3E7EA),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            place.icon,
                            color: const Color(0xFF98A2B3),
                            size: 38,
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Photo preview unavailable',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF9AF5AE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            'DEMO',
                            style: TextStyle(
                              color: kNavAbleNavy,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            style: const TextStyle(
                              color: kNavAbleNavy,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          place.score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF07883D),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${place.distance} • ${place.location}',
                      style: const TextStyle(color: kNavAbleText, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final tag in place.tags) _ExploreTag(label: tag),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
  });

  final _ExplorePlace place;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place Details')),
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
                    child: Icon(place.icon, color: kNavAbleNavy, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    place.name,
                    style: const TextStyle(
                      color: kNavAbleNavy,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${place.distance} • ${place.location}',
                    style: const TextStyle(color: kNavAbleText),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Accessibility',
                    style: TextStyle(
                      color: kNavAbleNavy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final feature in place.tags)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(
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
                  onNavigate(place.name);
                },
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Navigate'),
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
          style: const TextStyle(
            color: Color(0xFF475467),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
