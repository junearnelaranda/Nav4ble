part of '../home.dart';

/// What the user chose on the AI result screen.
enum _DetectionAction { submit, retake }

/// "accessible_entrance" -> "Accessible entrance".
String _featureLabel(String raw) {
  final text = raw.replaceAll('_', ' ').trim();
  return text.isEmpty ? raw : text[0].toUpperCase() + text.substring(1);
}

/// Detections as (label, confidence 0..1, box in image pixels or null).
List<({String label, double confidence, Rect? box})> _detectionsOf(
  Map<String, dynamic> suggestion,
) {
  final detections = suggestion['detections'];
  if (detections is! List) return const [];
  return [
    for (final d in detections.whereType<Map>())
      if ((d['class'] ?? d['label'] ?? d['class_name']) case final String raw
          when d['confidence'] is num)
        (
          label: _featureLabel(raw),
          confidence: () {
            final c = (d['confidence'] as num).toDouble();
            return (c > 1 ? c / 100 : c).clamp(0.0, 1.0);
          }(),
          box: [d['x'], d['y'], d['width'], d['height']].every((v) => v is num)
              ? Rect.fromCenter(
                  center: Offset(
                    (d['x'] as num).toDouble(),
                    (d['y'] as num).toDouble(),
                  ),
                  width: (d['width'] as num).toDouble(),
                  height: (d['height'] as num).toDouble(),
                )
              : null,
        ),
  ];
}

class _DetectionResultScreen extends StatefulWidget {
  const _DetectionResultScreen({required this.photos, required this.analysis});

  final List<Uint8List> photos;
  final PhotoAnalysis analysis;

  @override
  State<_DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<_DetectionResultScreen> {
  int _page = 0;

  Map<String, dynamic> _suggestionFor(int index) => widget
      .analysis
      .photoSuggestions
      .firstWhere((s) => s['photoIndex'] == index, orElse: () => const {});

  @override
  Widget build(BuildContext context) {
    final all = [
      for (var i = 0; i < widget.photos.length; i++)
        ..._detectionsOf(_suggestionFor(i)),
    ];
    final features = {for (final d in all) d.label}.toList()..sort();
    final average = all.isEmpty
        ? null
        : all.map((d) => d.confidence).reduce((a, b) => a + b) / all.length;
    final scanned = widget.analysis.status != 'failed';

    return Scaffold(
      appBar: AppBar(title: const Text('AI Detection Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              'Review the accessibility features identified in your photo.',
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.md),
            SizedBox(
              height: 280,
              child: PageView.builder(
                itemCount: widget.photos.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => _DetectionPhoto(
                  photo: widget.photos[index],
                  suggestion: _suggestionFor(index),
                ),
              ),
            ),
            if (widget.photos.length > 1) ...[
              const SizedBox(height: NavAbleSpacing.xs),
              Text(
                'Photo ${_page + 1} of ${widget.photos.length} · swipe to see more',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.navAbleSecondaryText,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: NavAbleSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ResultInfoCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Detected features',
                      child: features.isEmpty
                          ? Text(
                              scanned ? 'None recognized' : 'Not scanned',
                              style: TextStyle(
                                color: context.navAbleSecondaryText,
                                fontSize: 13,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final feature in features)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: NavAblePalette.greenDark,
                                          size: 17,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            feature,
                                            style: TextStyle(
                                              color: context.navAblePrimaryText,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: NavAbleSpacing.sm),
                  Expanded(
                    child: _ResultInfoCard(
                      icon: Icons.insights_rounded,
                      title: 'Confidence level',
                      child: average == null
                          ? Text(
                              '—',
                              style: TextStyle(
                                color: context.navAbleSecondaryText,
                                fontSize: 13,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(average * 100).round()}%',
                                  style: const TextStyle(
                                    color: NavAblePalette.green,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: average,
                                    minHeight: 7,
                                    color: NavAblePalette.green,
                                    backgroundColor: NavAblePalette.green
                                        .withValues(alpha: 0.18),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Average of ${all.length} '
                                  'detection${all.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: context.navAbleSecondaryText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NavAbleSpacing.sm),
            _ResultNotice(
              icon: Icons.verified_user_outlined,
              title: 'Pending admin verification',
              body: scanned
                  ? 'AI results are suggestions. An administrator reviews '
                        'every submission, usually within 24 hours.'
                  : widget.analysis.message ??
                        'AI scanning was unavailable. An administrator will '
                            'review your photos instead.',
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            SizedBox(
              height: NavAbleSize.primaryButton,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_DetectionAction.submit),
                icon: const Icon(Icons.send_rounded, size: 19),
                label: const Text('Confirm and Submit'),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.sm),
            SizedBox(
              height: NavAbleSize.control,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_DetectionAction.retake),
                icon: const Icon(Icons.replay_rounded, size: 19),
                label: const Text('Retake Photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photo with its detection boxes and labels drawn on top.
class _DetectionPhoto extends StatefulWidget {
  const _DetectionPhoto({required this.photo, required this.suggestion});

  final Uint8List photo;
  final Map<String, dynamic> suggestion;

  @override
  State<_DetectionPhoto> createState() => _DetectionPhotoState();
}

class _DetectionPhotoState extends State<_DetectionPhoto> {
  late final Future<Size> _size = decodeImageFromList(
    widget.photo,
  ).then((image) => Size(image.width.toDouble(), image.height.toDouble()));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Size>(
      future: _size,
      builder: (context, snapshot) {
        final shown = snapshot.data;
        if (shown == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // Boxes are in the analyzed image's pixels; fall back to the shown
        // photo's size when the service didn't report it.
        final image = widget.suggestion['image'];
        final width = image is Map && image['width'] is num
            ? (image['width'] as num).toDouble()
            : shown.width;
        final height = image is Map && image['height'] is num
            ? (image['height'] as num).toDouble()
            : shown.height;
        final detections = _detectionsOf(widget.suggestion);
        return Center(
          child: AspectRatio(
            aspectRatio: shown.width / shown.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NavAbleRadius.tile),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    widget.photo,
                    fit: BoxFit.fill,
                    semanticLabel: detections.isEmpty
                        ? 'Report photo, no features detected'
                        : 'Report photo showing ${detections.map((d) => d.label).join(', ')}',
                  ),
                  CustomPaint(
                    painter: _DetectionBoxPainter(
                      detections: detections,
                      imageSize: Size(width, height),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetectionBoxPainter extends CustomPainter {
  _DetectionBoxPainter({required this.detections, required this.imageSize});

  final List<({String label, double confidence, Rect? box})> detections;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty) return;
    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;
    final stroke = Paint()
      ..color = NavAblePalette.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final d in detections) {
      final box = d.box;
      if (box == null) continue;
      final rect = Rect.fromLTRB(
        box.left * sx,
        box.top * sy,
        box.right * sx,
        box.bottom * sy,
      ).intersect(Offset.zero & size);
      if (rect.isEmpty) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        stroke,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${d.label} (${(d.confidence * 100).round()}%)',
          style: const TextStyle(
            color: NavAblePalette.navy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 8);
      // Label sits above the box, or inside it when there's no room above.
      final top = rect.top - text.height - 6 >= 0
          ? rect.top - text.height - 6
          : rect.top + 2;
      final left = rect.left.clamp(0.0, size.width - text.width - 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, text.width + 12, text.height + 6),
          const Radius.circular(4),
        ),
        Paint()..color = NavAblePalette.green,
      );
      text.paint(canvas, Offset(left + 6, top + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionBoxPainter oldDelegate) =>
      oldDelegate.detections != detections ||
      oldDelegate.imageSize != imageSize;
}

class _ResultInfoCard extends StatelessWidget {
  const _ResultInfoCard({
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
      padding: const EdgeInsets.all(14),
      borderRadius: NavAbleRadius.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NavAblePalette.greenDark, size: 20),
          const SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: context.navAbleSecondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ResultNotice extends StatelessWidget {
  const _ResultNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.isNavAbleDark
            ? NavAblePalette.darkSurface
            : const Color(0xFFF1F7F3),
        borderRadius: BorderRadius.circular(NavAbleRadius.tile),
        border: Border.all(
          color: context.isNavAbleDark
              ? NavAblePalette.darkBorder
              : const Color(0xFFD5E9DB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: NavAblePalette.green.withValues(alpha: 0.18),
            child: Icon(icon, color: NavAblePalette.green, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.navAblePrimaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: context.navAbleSecondaryText,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSubmittedScreen extends StatelessWidget {
  const _ReportSubmittedScreen({
    required this.onBackToHome,
    required this.onViewContributions,
  });

  final VoidCallback onBackToHome;
  final VoidCallback onViewContributions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: NavAblePalette.green.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NavAblePalette.green.withValues(alpha: 0.55),
                    width: 6,
                  ),
                ),
                child: const Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: NavAblePalette.greenDark,
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            Text(
              'Thank You for Contributing!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.navAblePrimaryText,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.xs),
            Text(
              'Your report has been submitted. Our team will verify the '
              'accessibility update to help others navigate safely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            NavAbleSurface(
              borderRadius: NavAbleRadius.tile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: NavAblePalette.greenDark,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Next Steps',
                        style: TextStyle(
                          color: context.navAblePrimaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NavAbleSpacing.sm),
                  const _NextStep(
                    icon: Icons.schedule_rounded,
                    text: 'Admin verification (usually within 24 hours)',
                  ),
                  const _NextStep(
                    icon: Icons.fact_check_outlined,
                    text: 'AI suggestions are checked by a person',
                  ),
                  const _NextStep(
                    icon: Icons.map_outlined,
                    text: 'Verified updates appear on the map for all users',
                  ),
                ],
              ),
            ),
            const SizedBox(height: NavAbleSpacing.md),
            ExcludeSemantics(
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NavAbleRadius.tile),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [NavAblePalette.navy, NavAblePalette.darkCanvas],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.where_to_vote_rounded,
                    color: NavAblePalette.green,
                    size: 84,
                  ),
                ),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            SizedBox(
              height: NavAbleSize.primaryButton,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onBackToHome();
                },
                child: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.xs),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onViewContributions();
              },
              child: Text(
                'View My Contributions',
                style: TextStyle(
                  color: context.navAblePrimaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.navAbleSecondaryText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
