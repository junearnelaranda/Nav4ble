part of '../home.dart';

class _SavedPage extends StatelessWidget {
  const _SavedPage({
    required this.savedPlaces,
    required this.onUsePlace,
    required this.onDeletePlace,
    required this.onOpenPlace,
  });

  final List<SavedPlace> savedPlaces;
  final ValueChanged<SavedPlace> onUsePlace;
  final ValueChanged<SavedPlace> onDeletePlace;
  final ValueChanged<SavedPlace> onOpenPlace;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        if (savedPlaces.isEmpty)
          const _EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved places yet',
            detail: 'Save a destination from the route planner.',
          )
        else
          for (final place in savedPlaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Panel(
                child: InkWell(
                  onTap: () => onOpenPlace(place),
                  child: Row(
                    children: [
                      const _CircleIcon(icon: Icons.place_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: TextStyle(
                                color: context.navAblePrimaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${place.address} - ${place.tag}',
                              style: TextStyle(
                                color: context.navAbleSecondaryText,
                                fontSize: 13,
                                height: 1.35,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Route',
                        onPressed: () => onUsePlace(place),
                        icon: const Icon(Icons.route_rounded),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => onDeletePlace(place),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class SavedPlaceDetailsScreen extends StatefulWidget {
  const SavedPlaceDetailsScreen({
    super.key,
    required this.place,
    required this.onRoute,
    required this.onSave,
  });

  final SavedPlace place;
  final VoidCallback onRoute;
  final ValueChanged<SavedPlace> onSave;

  @override
  State<SavedPlaceDetailsScreen> createState() =>
      _SavedPlaceDetailsScreenState();
}

class _SavedPlaceDetailsScreenState extends State<SavedPlaceDetailsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late String _tag;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.place.name);
    _addressController = TextEditingController(text: widget.place.address);
    // Older saves used feature names ("Ramp") as tags; the picker only has
    // these, so anything else shows as Custom instead of crashing.
    _tag = SavedPlace.tags.contains(widget.place.tag)
        ? widget.place.tag
        : 'Custom';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a name and address.')));
      return;
    }

    // Keeps the link to the NavAble place it was saved from.
    widget.onSave(
      widget.place.copyWith(name: name, address: address, tag: _tag),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Place'), elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InputField(
                    controller: _nameController,
                    hintText: 'Place name',
                    icon: Icons.place_outlined,
                  ),
                  const SizedBox(height: 12),
                  _InputField(
                    controller: _addressController,
                    hintText: 'Accessible entrance or note',
                    icon: Icons.notes_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _tag,
                    decoration: _fieldDecoration(
                      hintText: 'Tag',
                      icon: Icons.label_outline,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Home', child: Text('Home')),
                      DropdownMenuItem(value: 'Work', child: Text('Work')),
                      DropdownMenuItem(
                        value: 'Transit',
                        child: Text('Transit'),
                      ),
                      DropdownMenuItem(value: 'Civic', child: Text('Civic')),
                      DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _tag = value);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onRoute,
                          icon: const Icon(Icons.route_rounded),
                          label: const Text('Route'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: kNavAbleNavy,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ),
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
