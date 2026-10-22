part of '../home.dart';

class _ReportsPage extends StatefulWidget {
  const _ReportsPage({
    required this.reports,
    required this.locations,
    required this.initialLocation,
    required this.photoCaptureRequestId,
    required this.onPhotoCaptureRequestHandled,
    required this.onAnalyzePhotos,
    required this.onSubmitReport,
    required this.onOpenReport,
  });

  final List<AccessReport> reports;
  final List<AccessibleLocation> locations;
  final AccessibleLocation? initialLocation;
  final int photoCaptureRequestId;
  final VoidCallback onPhotoCaptureRequestHandled;
  final Future<PhotoAnalysis> Function(List<Uint8List>) onAnalyzePhotos;
  final Future<bool> Function(AccessReport, PhotoAnalysis) onSubmitReport;
  final ValueChanged<AccessReport> onOpenReport;

  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<_ReportsPage> {
  late final TextEditingController _locationController = TextEditingController(
    text: widget.initialLocation == null
        ? ''
        : '${widget.initialLocation!.latitude.toStringAsFixed(6)}, ${widget.initialLocation!.longitude.toStringAsFixed(6)}',
  );
  late final TextEditingController _placeNameController = TextEditingController(
    text: widget.initialLocation?.name ?? '',
  );
  final TextEditingController _descriptionController = TextEditingController();
  String? _category;
  final List<Uint8List> _selectedPhotos = [];
  PhotoAnalysis? _photoAnalysis;
  ImageSource? _lastPhotoSource;
  bool _isPickingPhoto = false;
  bool _isAnalyzingPhotos = false;
  bool _isSubmitting = false;
  String? _selectedLocationId;

  static const _maxPhotos = 5;

  static const _categories = <String>[
    'Accessible ramp',
    'Elevator access',
    'Step-free entrance',
    'Accessible toilet',
    'Tactile paving',
    'Audio assistance',
    'Wheelchair parking',
    'Accessibility issue',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocationId = widget.initialLocation?.id;
    if (widget.photoCaptureRequestId > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onPhotoCaptureRequestHandled();
        _choosePhoto(ImageSource.camera);
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _placeNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  IconData get _selectedCategoryIcon {
    final category = _category ?? '';
    if (category.contains('ramp')) return Icons.accessible_forward_rounded;
    if (category.contains('Elevator')) return Icons.elevator_outlined;
    if (category.contains('entrance')) return Icons.door_front_door_outlined;
    if (category.contains('toilet')) return Icons.wc_rounded;
    if (category.contains('tactile')) return Icons.blind_outlined;
    if (category.contains('Audio')) return Icons.hearing_rounded;
    return Icons.warning_amber_rounded;
  }

  Future<void> _choosePhoto(ImageSource source) async {
    if (_isPickingPhoto || _isAnalyzingPhotos || _isSubmitting) return;
    setState(() => _isPickingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1024,
      );
      if (!mounted || photo == null) return;
      final photoBytes = await photo.readAsBytes();
      if (!mounted) return;
      if (photoBytes.lengthInBytes > ReportsApi.maxPhotoBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This photo is over 700 KiB. Choose a smaller photo and try again.',
            ),
          ),
        );
        return;
      }
      if (_selectedPhotos.length >= _maxPhotos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can attach up to 5 photos.')),
        );
        return;
      }
      setState(() {
        _selectedPhotos.add(photoBytes);
        _photoAnalysis = null;
        _lastPhotoSource = source;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the selected photo source.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _scanPhotos() async {
    if (_isAnalyzingPhotos || _selectedPhotos.isEmpty) return;
    setState(() {
      _isAnalyzingPhotos = true;
      _photoAnalysis = null;
    });
    try {
      final result = await widget.onAnalyzePhotos(
        List<Uint8List>.unmodifiable(_selectedPhotos),
      );
      if (!mounted) return;
      setState(() => _photoAnalysis = result);
      if (result.message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message!)));
      }
    } on ReportsApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _photoAnalysis = PhotoAnalysis.failedFor(
          _selectedPhotos.length,
          message: error.message,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      const message =
          'Photo scanning is unavailable. You can still submit for review.';
      setState(() {
        _photoAnalysis = PhotoAnalysis.failedFor(
          _selectedPhotos.length,
          message: message,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isAnalyzingPhotos = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();

    if (location.isEmpty ||
        _category == null ||
        description.isEmpty ||
        _selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pin the location, add a category and description, and attach at least one photo.',
          ),
        ),
      );
      return;
    }
    final analysis = _photoAnalysis;
    if (analysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan the photos before submitting.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final submitted = await widget.onSubmitReport(
      AccessReport(
        title: _placeNameController.text.trim().isEmpty
            ? 'Accessibility location'
            : _placeNameController.text.trim(),
        locationId: _selectedLocationId,
        location: location,
        detail: description,
        category: _category!,
        icon: _selectedCategoryIcon,
        photoBytes: List<Uint8List>.of(_selectedPhotos),
      ),
      analysis,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (submitted) {
        _category = null;
        _selectedPhotos.clear();
        _photoAnalysis = null;
        _lastPhotoSource = null;
        _descriptionController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.xxl,
      ),
      children: [
        Text(
          'Submit Accessibility Photos',
          style: TextStyle(
            color: context.navAblePrimaryText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xs),
        Text(
          'Share photo evidence of an accessible feature or a barrier. AI suggestions are reviewed by a person.',
          style: TextStyle(
            color: context.navAbleSecondaryText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: NavAbleSpacing.lg),
        _ReportFormCard(
          icon: Icons.location_on_outlined,
          title: 'Accessible Location',
          child: Column(
            children: [
              _ReportMapPlaceholder(
                initialLocation: widget.initialLocation,
                locations: widget.locations,
                onLocationSelected: (position) {
                  setState(() {
                    _locationController.text =
                        '${position.latitude.toStringAsFixed(6)}, '
                        '${position.longitude.toStringAsFixed(6)}';
                    _selectedLocationId = null;
                  });
                },
                onAccessibleLocationSelected: (location) {
                  setState(() {
                    _selectedLocationId = location.id;
                    _placeNameController.text = location.name;
                    _locationController.text =
                        '${location.latitude.toStringAsFixed(6)}, '
                        '${location.longitude.toStringAsFixed(6)}';
                  });
                },
              ),
              const SizedBox(height: NavAbleSpacing.sm),
              SizedBox(
                height: NavAbleSize.compactControl,
                child: TextField(
                  controller: _placeNameController,
                  onChanged: (value) {
                    if (widget.initialLocation?.name != value.trim()) {
                      setState(() => _selectedLocationId = null);
                    }
                  },
                  style: TextStyle(fontSize: 13),
                  decoration: _reportFieldDecoration(
                    context,
                    hintText: 'Place or establishment name',
                    icon: Icons.storefront_outlined,
                  ),
                ),
              ),
              const SizedBox(height: NavAbleSpacing.sm),
              SizedBox(
                height: NavAbleSize.compactControl,
                child: TextField(
                  controller: _locationController,
                  onChanged: (_) => setState(() => _selectedLocationId = null),
                  style: TextStyle(fontSize: 13),
                  decoration: _reportFieldDecoration(
                    context,
                    hintText: 'Tap the map to pin the exact location',
                    icon: Icons.my_location_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        _ReportFormCard(
          icon: Icons.category_outlined,
          title: 'Issue Category',
          child: SizedBox(
            height: NavAbleSize.control,
            child: DropdownButtonFormField<String>(
              key: ValueKey(_category),
              initialValue: _category,
              isExpanded: true,
              hint: Text('Select issue type...'),
              decoration: _reportFieldDecoration(
                context,
                hintText: 'Select issue type...',
              ),
              items: [
                for (final category in _categories)
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        _ReportFormCard(
          icon: Icons.description_outlined,
          title: 'Description',
          child: TextField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: _reportFieldDecoration(
              context,
              hintText: 'Provide details about the accessibility problem...',
            ),
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        _ReportFormCard(
          icon: Icons.add_a_photo_outlined,
          title: 'Add Photos',
          child: Column(
            children: [
              if (_selectedPhotos.isNotEmpty) ...[
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedPhotos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: NavAbleSpacing.sm),
                    itemBuilder: (context, index) {
                      final photo = _selectedPhotos[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(
                          NavAbleRadius.small,
                        ),
                        child: Stack(
                          children: [
                            Image.memory(
                              photo,
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Accessibility report photo ${index + 1}',
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: IconButton.filledTonal(
                                tooltip: 'Remove photo ${index + 1}',
                                visualDensity: VisualDensity.compact,
                                onPressed: _isAnalyzingPhotos || _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedPhotos.removeAt(index);
                                          _photoAnalysis = null;
                                        });
                                      },
                                icon: Icon(Icons.close_rounded, size: 18),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: NavAbleSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: _PhotoSourceButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Take Photo',
                      selected: _lastPhotoSource == ImageSource.camera,
                      onTap:
                          _isPickingPhoto ||
                              _isAnalyzingPhotos ||
                              _isSubmitting ||
                              _selectedPhotos.length >= _maxPhotos
                          ? null
                          : () => _choosePhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: NavAbleSpacing.sm),
                  Expanded(
                    child: _PhotoSourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'From Gallery',
                      selected: _lastPhotoSource == ImageSource.gallery,
                      onTap:
                          _isPickingPhoto ||
                              _isAnalyzingPhotos ||
                              _isSubmitting ||
                              _selectedPhotos.length >= _maxPhotos
                          ? null
                          : () => _choosePhoto(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NavAbleSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _selectedPhotos.isEmpty ||
                          _isPickingPhoto ||
                          _isAnalyzingPhotos
                      ? null
                      : _scanPhotos,
                  icon: _isAnalyzingPhotos
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.document_scanner_outlined),
                  label: Text(
                    _isAnalyzingPhotos
                        ? 'Scanning photos…'
                        : _photoAnalysis == null
                        ? 'Scan Photos with AI'
                        : 'Scan Again',
                  ),
                ),
              ),
              if (_isAnalyzingPhotos) ...[
                const SizedBox(height: NavAbleSpacing.xs),
                const LinearProgressIndicator(),
              ],
              if (_photoAnalysis case final analysis?) ...[
                const SizedBox(height: NavAbleSpacing.sm),
                _PhotoAnalysisCard(analysis: analysis),
              ],
              if (_isPickingPhoto) ...[
                const SizedBox(height: NavAbleSpacing.sm),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: NavAbleSize.primaryButton,
          child: FilledButton(
            onPressed:
                _isSubmitting || _isAnalyzingPhotos || _photoAnalysis == null
                ? null
                : _submit,
            child: Text(_isSubmitting ? 'Submitting…' : 'Submit for Review'),
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: context.navAbleSecondaryText,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Reports are verified by the community within 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.navAbleSecondaryText,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NavAbleSpacing.xxl),
        Text(
          'Accessibility Reports',
          style: TextStyle(
            color: context.navAblePrimaryText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        for (final report in widget.reports)
          Padding(
            padding: const EdgeInsets.only(bottom: NavAbleSpacing.sm),
            child: _ReportCard(
              report: report,
              onTap: () => widget.onOpenReport(report),
            ),
          ),
      ],
    );
  }
}

class _PhotoAnalysisCard extends StatelessWidget {
  const _PhotoAnalysisCard({required this.analysis});

  final PhotoAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final title = switch (analysis.status) {
      'completed' => 'AI scan complete',
      'partial' => 'Some photos were scanned',
      _ => 'AI scan unavailable',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.sm),
      decoration: BoxDecoration(
        color: context.isNavAbleDark
            ? NavAblePalette.darkSurface
            : const Color(0xFFF1F7F3),
        borderRadius: BorderRadius.circular(NavAbleRadius.small),
        border: Border.all(
          color: context.isNavAbleDark
              ? NavAblePalette.darkBorder
              : const Color(0xFFD5E9DB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            analysis.message ??
                'Suggestions only. An administrator must verify every report.',
            style: TextStyle(color: context.navAbleSecondaryText, fontSize: 12),
          ),
          for (final suggestion in analysis.photoSuggestions) ...[
            const SizedBox(height: 8),
            Text(
              'Photo ${((suggestion['photoIndex'] as num?)?.toInt() ?? -1) + 1}',
              style: TextStyle(
                color: context.navAblePrimaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (suggestion['detections'] is List &&
                (suggestion['detections'] as List).isNotEmpty)
              for (final detection
                  in (suggestion['detections'] as List).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    detection.entries
                        .where(
                          (entry) =>
                              entry.value is String ||
                              entry.value is num ||
                              entry.value is bool,
                        )
                        .map((entry) => '${entry.key}: ${entry.value}')
                        .join(' · '),
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontSize: 12,
                    ),
                  ),
                )
            else
              Text(
                'No objects detected in this photo.',
                style: TextStyle(
                  color: context.navAbleSecondaryText,
                  fontSize: 12,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReportFormCard extends StatelessWidget {
  const _ReportFormCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.md),
      borderRadius: NavAbleRadius.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: context.navAblePrimaryText),
              const SizedBox(width: NavAbleSpacing.xs),
              Text(
                title,
                style: TextStyle(
                  color: context.navAblePrimaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: NavAbleSpacing.sm),
          child,
        ],
      ),
    );
  }
}

InputDecoration _reportFieldDecoration(
  BuildContext context, {
  required String hintText,
  IconData? icon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: context.navAbleSecondaryText, fontSize: 13),
    prefixIcon: icon == null ? null : Icon(icon, size: 18),
    filled: true,
    fillColor: context.navAbleSurface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: NavAbleSpacing.sm,
      vertical: NavAbleSpacing.sm,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NavAbleRadius.small),
      borderSide: const BorderSide(color: NavAblePalette.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NavAbleRadius.small),
      borderSide: const BorderSide(color: NavAblePalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(NavAbleRadius.small),
      borderSide: const BorderSide(color: kNavAbleGreen, width: 1.5),
    ),
  );
}

class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kNavAbleGreen : const Color(0xFF98A2B3);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: NavAbleHoverLift(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NavAbleRadius.small),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: color,
              radius: NavAbleRadius.small,
            ),
            child: SizedBox(
              height: 88,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : icon,
                    color: selected
                        ? NavAblePalette.greenDark
                        : context.navAbleSecondaryText,
                    size: 24,
                  ),
                  const SizedBox(height: NavAbleSpacing.xs),
                  Text(
                    selected ? '$label added' : label,
                    style: TextStyle(
                      color: selected
                          ? NavAblePalette.greenDark
                          : context.navAblePrimaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

class _ReportMapPlaceholder extends StatefulWidget {
  const _ReportMapPlaceholder({
    required this.initialLocation,
    required this.locations,
    required this.onLocationSelected,
    required this.onAccessibleLocationSelected,
  });

  final AccessibleLocation? initialLocation;
  final List<AccessibleLocation> locations;
  final ValueChanged<osm.LatLng> onLocationSelected;
  final ValueChanged<AccessibleLocation> onAccessibleLocationSelected;

  @override
  State<_ReportMapPlaceholder> createState() => _ReportMapPlaceholderState();
}

class _ReportMapPlaceholderState extends State<_ReportMapPlaceholder> {
  osm.LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = _positionFor(widget.initialLocation);
  }

  @override
  void didUpdateWidget(covariant _ReportMapPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLocation?.id != widget.initialLocation?.id ||
        oldWidget.initialLocation?.latitude !=
            widget.initialLocation?.latitude ||
        oldWidget.initialLocation?.longitude !=
            widget.initialLocation?.longitude) {
      _selectedPosition = _positionFor(widget.initialLocation);
    }
  }

  osm.LatLng? _positionFor(AccessibleLocation? location) => location == null
      ? null
      : osm.LatLng(location.latitude, location.longitude);

  void _selectPosition(osm.LatLng position) {
    setState(() => _selectedPosition = position);
    widget.onLocationSelected(position);
  }

  void _selectAccessibleLocation(AccessibleLocation location) {
    final position = _positionFor(location)!;
    setState(() => _selectedPosition = position);
    widget.onAccessibleLocationSelected(location);
  }

  Future<void> _openExpandedMap() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('pin report location'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Done'),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: _OpenStreetMapView(
                  initialPosition: _selectedPosition ?? _cebuMapCenter,
                  initialSelection: _selectedPosition,
                  selectionMode: true,
                  locations: widget.locations,
                  onAccessibleLocationTapped: _selectAccessibleLocation,
                  onLocationSelected: _selectPosition,
                ),
              ),
              Positioned(
                left: NavAbleSpacing.md,
                right: NavAbleSpacing.md,
                bottom: NavAbleSpacing.md,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(NavAbleSpacing.md),
                    child: Text(
                      _selectedPosition == null
                          ? 'Tap the map to place the report pin, or choose an existing accessible location.'
                          : 'Pinned at ${_selectedPosition!.latitude.toStringAsFixed(6)}, ${_selectedPosition!.longitude.toStringAsFixed(6)}. Tap elsewhere to adjust.',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NavAbleRadius.small),
        child: Stack(
          children: [
            Positioned.fill(
              child: _OpenStreetMapView(
                initialPosition: _selectedPosition ?? _cebuMapCenter,
                initialSelection: _selectedPosition,
                selectionMode: true,
                locations: widget.locations,
                onAccessibleLocationTapped: _selectAccessibleLocation,
                onLocationSelected: _selectPosition,
                borderRadius: BorderRadius.circular(NavAbleRadius.small),
              ),
            ),
            Positioned(
              top: NavAbleSpacing.xs,
              right: NavAbleSpacing.xs,
              child: Material(
                color: Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Expand map',
                  visualDensity: VisualDensity.compact,
                  onPressed: _openExpandedMap,
                  icon: Icon(Icons.open_in_full_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
