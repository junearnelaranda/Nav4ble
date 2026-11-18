import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../guides_api.dart';
import '../navable_design.dart';

/// "Where is this feature?": a contributor describes where to find a feature
/// at a place, with two photos and an optional map pin. An admin reviews it
/// before anyone else can see it.
class AddGuideScreen extends StatefulWidget {
  const AddGuideScreen({
    super.key,
    required this.locationId,
    required this.placeName,
    required this.placePoint,
    required this.features,
    required this.onSubmit,
    required this.pinPickerBuilder,
    this.initialFeatureName,
    this.initialFeaturePhotoUrl,
    this.pickPhoto,
  });

  final String locationId;
  final String placeName;
  final LatLng placePoint;
  final List<GuideFeature> features;
  final String? initialFeatureName;

  /// A photo already uploaded with a scan, used as the feature photo.
  final String? initialFeaturePhotoUrl;
  final Future<void> Function(GuideSubmission guide) onSubmit;

  /// Builds the map used to pin the spot.
  final Widget Function(
    BuildContext context,
    LatLng start,
    ValueChanged<LatLng> onPicked,
  )
  pinPickerBuilder;

  /// Replaces the device's camera and gallery picker.
  final Future<Uint8List?> Function(BuildContext context)? pickPhoto;

  @override
  State<AddGuideScreen> createState() => _AddGuideScreenState();
}

class _AddGuideScreenState extends State<AddGuideScreen> {
  final _where = TextEditingController();
  final _floor = TextEditingController();
  final _landmark = TextEditingController();
  GuideFeature? _feature;
  Uint8List? _featurePhoto;
  Uint8List? _nearbyPhoto;
  LatLng? _pin;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final wanted = widget.initialFeatureName;
    if (wanted != null) {
      for (final feature in widget.features) {
        if (featureKey(feature.name) == featureKey(wanted)) _feature = feature;
      }
    }
  }

  @override
  void dispose() {
    _where.dispose();
    _floor.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pickFromDevice() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 1024,
    );
    return photo?.readAsBytes();
  }

  Future<void> _choosePhoto(ValueChanged<Uint8List> onPicked) async {
    try {
      final picker = widget.pickPhoto;
      final bytes = picker != null
          ? await picker(context)
          : await _pickFromDevice();
      if (!mounted || bytes == null) return;
      final problem = GuidesApi.photoProblem(bytes);
      setState(() {
        _error = problem;
        if (problem == null) onPicked(bytes);
      });
    } on Exception {
      if (mounted) setState(() => _error = "Couldn't open that photo.");
    }
  }

  Future<void> _choosePin() async {
    var picked = _pin ?? widget.placePoint;
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Pin the spot')),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: widget.pinPickerBuilder(
                    context,
                    picked,
                    (point) => picked = point,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(NavAbleSpacing.md),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Use this spot'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) setState(() => _pin = picked);
  }

  Future<void> _submit() async {
    if (_sending) return;
    final feature = _feature;
    final photoUrl = widget.initialFeaturePhotoUrl;
    final problem = feature == null
        ? 'Choose a feature.'
        : GuidesApi.validate(
            whereText: _where.text,
            floor: _floor.text,
            landmark: _landmark.text,
            hasFeaturePhoto: _featurePhoto != null || photoUrl != null,
            hasNearbyPhoto: _nearbyPhoto != null,
            pin: _pin,
            place: widget.placePoint,
          );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.onSubmit(
        GuideSubmission(
          locationId: widget.locationId,
          featureId: feature!.id,
          whereText: _where.text.trim(),
          floor: _floor.text.trim(),
          landmark: _landmark.text.trim(),
          pin: _pin,
          featurePhoto: _featurePhoto,
          featurePhotoUrl: _featurePhoto == null ? photoUrl : null,
          nearbyPhoto: _nearbyPhoto!,
        ),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks! An admin will review your guide.'),
        ),
      );
    } on GuidesApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a guide')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NavAbleSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Where is this feature?',
                      style: TextStyle(
                        color: context.navAblePrimaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.placeName,
                    style: TextStyle(color: context.navAbleSecondaryText),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<GuideFeature>(
                    initialValue: _feature,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Feature'),
                    items: [
                      for (final feature in widget.features)
                        DropdownMenuItem(
                          value: feature,
                          child: Text(
                            feature.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _sending
                        ? null
                        : (feature) => setState(() => _feature = feature),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _where,
                    enabled: !_sending,
                    maxLength: GuidesApi.maxWhere,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Where to find it',
                      hintText: 'Right side of the main entrance',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _floor,
                    enabled: !_sending,
                    maxLength: GuidesApi.maxFloor,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Floor (optional)',
                      hintText: 'Ground floor',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _landmark,
                    enabled: !_sending,
                    maxLength: GuidesApi.maxLandmark,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nearby sign or landmark (optional)',
                      hintText: 'Beside the blue sign',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PhotoSlot(
                          slotKey: const ValueKey('guide-photo-feature'),
                          label: 'Photo of the feature',
                          bytes: _featurePhoto,
                          url: widget.initialFeaturePhotoUrl,
                          onTap: _sending
                              ? null
                              : () => _choosePhoto(
                                  (bytes) => _featurePhoto = bytes,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PhotoSlot(
                          slotKey: const ValueKey('guide-photo-nearby'),
                          label: "Photo of what's nearby",
                          bytes: _nearbyPhoto,
                          onTap: _sending
                              ? null
                              : () => _choosePhoto(
                                  (bytes) => _nearbyPhoto = bytes,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Avoid people's faces, plate numbers and other personal "
                    'details. Approved photos are shown to everyone.',
                    style: TextStyle(
                      color: context.navAbleSecondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pin the spot (optional)',
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _sending ? null : _choosePin,
                    icon: Icon(
                      _pin == null
                          ? Icons.add_location_alt_outlined
                          : Icons.check_circle_outline_rounded,
                    ),
                    label: Text(
                      _pin == null ? 'Choose on the map' : 'Spot pinned',
                    ),
                  ),
                  if (_pin != null)
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () => setState(() => _pin = null),
                      child: const Text('Remove pin'),
                    ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: NavAbleSize.primaryButton,
                    child: FilledButton(
                      onPressed: _sending ? null : _submit,
                      child: Text(_sending ? 'Sending…' : 'Submit for review'),
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

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.slotKey,
    required this.label,
    required this.onTap,
    this.bytes,
    this.url,
  });

  final Key slotKey;
  final String label;
  final Uint8List? bytes;
  final String? url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final photo = bytes;
    final link = url;
    final hasPhoto = photo != null || link != null;
    Widget placeholder() => Center(
      child: Icon(
        Icons.add_a_photo_outlined,
        color: context.navAbleSecondaryText,
      ),
    );
    return Semantics(
      button: true,
      label: hasPhoto ? '$label, added. Tap to change.' : '$label, required',
      onTap: onTap,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 108,
            child: Material(
              color: context.navAbleSecondaryText.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(NavAbleRadius.tile),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: slotKey,
                onTap: onTap,
                child: photo != null
                    ? Image.memory(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => placeholder(),
                      )
                    : link != null
                    ? Image.network(
                        link,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => placeholder(),
                      )
                    : placeholder(),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
