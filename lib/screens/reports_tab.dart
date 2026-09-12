part of '../home.dart';

class _ReportsPage extends StatefulWidget {
  const _ReportsPage({
    required this.reports,
    required this.onSubmitReport,
    required this.onOpenReport,
  });

  final List<AccessReport> reports;
  final ValueChanged<AccessReport> onSubmitReport;
  final ValueChanged<AccessReport> onOpenReport;

  @override
  State<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<_ReportsPage> {
  final TextEditingController _locationController = TextEditingController(
    text: 'Siquijor Rd, Cebu City, 6000 Cebu',
  );
  final TextEditingController _descriptionController = TextEditingController();
  String? _category;
  String? _photoSource;

  static const _categories = <String>[
    'Blocked pathway',
    'Broken or missing ramp',
    'Elevator unavailable',
    'Inaccessible entrance',
    'Accessible toilet issue',
    'Missing tactile paving',
    'Audio assistance issue',
    'Other accessibility issue',
  ];

  @override
  void dispose() {
    _locationController.dispose();
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

  void _choosePhoto(String source) {
    setState(() => _photoSource = source);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$source selected for this local prototype.')),
    );
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();

    if (location.isEmpty || _category == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the location, issue category, and description.'),
        ),
      );
      return;
    }

    widget.onSubmitReport(
      AccessReport(
        title: location,
        detail: description,
        category: _category!,
        icon: _selectedCategoryIcon,
      ),
    );
    setState(() {
      _category = null;
      _photoSource = null;
      _descriptionController.clear();
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
        const Text(
          'Report an Issue',
          style: TextStyle(
            color: kNavAbleNavy,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xs),
        const Text(
          'Your reports help make the city more accessible for everyone.',
          style: TextStyle(color: kNavAbleText, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: NavAbleSpacing.lg),
        _ReportFormCard(
          icon: Icons.location_on_outlined,
          title: 'Issue Location',
          child: Column(
            children: [
              const _ReportMapPlaceholder(),
              const SizedBox(height: NavAbleSpacing.sm),
              SizedBox(
                height: NavAbleSize.compactControl,
                child: TextField(
                  controller: _locationController,
                  style: const TextStyle(fontSize: 13),
                  decoration: _reportFieldDecoration(
                    hintText: 'Add the issue location',
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
              hint: const Text('Select issue type...'),
              decoration: _reportFieldDecoration(
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
              hintText: 'Provide details about the accessibility problem...',
            ),
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        _ReportFormCard(
          icon: Icons.add_a_photo_outlined,
          title: 'Add Photos',
          child: Row(
            children: [
              Expanded(
                child: _PhotoSourceButton(
                  icon: Icons.photo_camera_outlined,
                  label: 'Take Photo',
                  selected: _photoSource == 'Camera',
                  onTap: () => _choosePhoto('Camera'),
                ),
              ),
              const SizedBox(width: NavAbleSpacing.sm),
              Expanded(
                child: _PhotoSourceButton(
                  icon: Icons.photo_library_outlined,
                  label: 'From Gallery',
                  selected: _photoSource == 'Gallery',
                  onTap: () => _choosePhoto('Gallery'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: NavAbleSize.primaryButton,
          child: FilledButton.icon(
            onPressed: _submit,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text('Submit Report'),
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 14, color: kNavAbleText),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Reports are verified by the community within 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kNavAbleText, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: NavAbleSpacing.xxl),
        const Text(
          'Accessibility Reports',
          style: TextStyle(
            color: kNavAbleNavy,
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
              Icon(icon, size: 19, color: kNavAbleNavy),
              const SizedBox(width: NavAbleSpacing.xs),
              Text(
                title,
                style: const TextStyle(
                  color: kNavAbleNavy,
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

InputDecoration _reportFieldDecoration({
  required String hintText,
  IconData? icon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF7B8794), fontSize: 13),
    prefixIcon: icon == null ? null : Icon(icon, size: 18),
    filled: true,
    fillColor: const Color(0xFFF1F4F6),
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
  final VoidCallback onTap;

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
                    color: selected ? NavAblePalette.greenDark : kNavAbleText,
                    size: 24,
                  ),
                  const SizedBox(height: NavAbleSpacing.xs),
                  Text(
                    selected ? '$label added' : label,
                    style: TextStyle(
                      color: selected ? NavAblePalette.greenDark : kNavAbleNavy,
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

class _ReportMapPlaceholder extends StatelessWidget {
  const _ReportMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NavAbleRadius.small),
      child: SizedBox(
        height: 132,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _ReportMapPainter()),
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kNavAbleNavy,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x330F2B4D),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xEFFFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Map preview',
                    style: TextStyle(
                      color: kNavAbleText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7ECEF),
    );

    final blockPaint = Paint()..color = const Color(0xFFDCE5DE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-12, 12, size.width * .42, 42),
        const Radius.circular(8),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .62, 72, size.width * .42, 46),
        const Radius.circular(8),
      ),
      blockPaint,
    );

    final roadPaint = Paint()
      ..color = const Color(0xFFFAFCFC)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-10, size.height * .82),
      Offset(size.width + 10, size.height * .18),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * .18, -8),
      Offset(size.width * .76, size.height + 8),
      roadPaint,
    );
    canvas.drawLine(
      Offset(-8, size.height * .35),
      Offset(size.width + 8, size.height * .68),
      roadPaint..strokeWidth = 8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
