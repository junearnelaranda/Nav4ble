part of '../home.dart';

class _AlertsPage extends StatelessWidget {
  const _AlertsPage({required this.reports, required this.onOpenReport});

  final List<AccessReport> reports;
  final ValueChanged<AccessReport> onOpenReport;

  void _showBadge(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFFDDF9E3),
          child: Icon(
            Icons.workspace_premium_rounded,
            color: NavAblePalette.greenDark,
            size: 34,
          ),
        ),
        title: const Text('Community Verifier'),
        content: const Text(
          'You earned this badge and 50 points for submitting a verified accessibility report.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _retakePhoto(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Camera capture will be enabled when device services are connected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.xxl,
      ),
      children: [
        const Text(
          'Alerts',
          style: TextStyle(
            color: kNavAbleNavy,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xs),
        const Text(
          'Stay updated on your accessibility reports and community status.',
          style: TextStyle(color: kNavAbleText, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: NavAbleSpacing.lg),
        _AlertCard(
          leading: const _AlertStatusIcon(
            icon: Icons.verified_rounded,
            foreground: NavAblePalette.greenDark,
            background: Color(0xFFDDF9E3),
          ),
          title: 'Verification Approved',
          time: '2m ago',
          body:
              'Your accessibility contribution for “Main St. Ramp” has been verified and awarded 50 points.',
          actionLabel: 'View Badge',
          onAction: () => _showBadge(context),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        _AlertCard(
          leading: const _AlertStatusIcon(
            icon: Icons.map_rounded,
            foreground: kNavAbleNavy,
            background: Color(0xFFDDEEFF),
          ),
          title: 'Nearby Accessibility Updates',
          time: '1h ago',
          body:
              '3 new elevators were reported active at Downtown Station. Your route has been optimized.',
          preview: const _AlertRoutePreview(),
          onTap: reports.isEmpty ? null : () => onOpenReport(reports.first),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        _AlertCard(
          leading: const _AlertStatusIcon(
            icon: Icons.close_rounded,
            foreground: Color(0xFFB42318),
            background: Color(0xFFFEE4E2),
          ),
          title: 'Verification Rejected',
          time: '5h ago',
          body:
              'The photo for “Oak Library Entrance” was blurry. Please resubmit a clearer image for approval.',
          actionLabel: 'Retake Photo',
          actionColor: const Color(0xFFB42318),
          onAction: () => _retakePhoto(context),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        const _AlertCard(
          leading: _AdminAvatar(),
          title: 'Admin Feedback',
          time: 'Yesterday',
          body:
              '“Thanks for the detailed report on the construction at Pier 3. We’ve flagged this as closed for all wheelchair users until Friday.”',
          emphasizedBody: true,
        ),
        if (reports.isNotEmpty) ...[
          const SizedBox(height: NavAbleSpacing.xl),
          const Text(
            'Report activity',
            style: TextStyle(
              color: kNavAbleNavy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: NavAbleSpacing.sm),
          for (final report in reports.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: NavAbleSpacing.sm),
              child: _ReportCard(
                report: report,
                onTap: () => onOpenReport(report),
              ),
            ),
        ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.leading,
    required this.title,
    required this.time,
    required this.body,
    this.actionLabel,
    this.actionColor = NavAblePalette.greenDark,
    this.onAction,
    this.onTap,
    this.preview,
    this.emphasizedBody = false,
  });

  final Widget leading;
  final String title;
  final String time;
  final String body;
  final String? actionLabel;
  final Color actionColor;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final Widget? preview;
  final bool emphasizedBody;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.md),
      borderRadius: NavAbleRadius.control,
      enableHover: onTap != null,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: NavAbleSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: kNavAbleNavy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: NavAbleSpacing.xs),
                    Text(
                      time,
                      style: const TextStyle(
                        color: kNavAbleText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (emphasizedBody)
                  Container(
                    padding: const EdgeInsets.only(left: NavAbleSpacing.sm),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: kNavAbleNavy, width: 3),
                      ),
                    ),
                    child: Text(
                      body,
                      style: const TextStyle(
                        color: kNavAbleText,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  Text(
                    body,
                    style: const TextStyle(
                      color: kNavAbleText,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                if (preview != null) ...[
                  const SizedBox(height: NavAbleSpacing.sm),
                  preview!,
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: NavAbleSpacing.xs),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: actionColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: NavAbleSpacing.sm,
                        vertical: NavAbleSpacing.xs,
                      ),
                      minimumSize: const Size(
                        NavAbleSize.minimumTouchTarget,
                        NavAbleSize.compactControl,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertStatusIcon extends StatelessWidget {
  const _AlertStatusIcon({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: background,
      child: Icon(icon, size: 23, color: foreground),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: Color(0xFFDDEEFF),
          child: Icon(Icons.support_agent_rounded, color: kNavAbleNavy),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: kNavAbleNavy,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertRoutePreview extends StatelessWidget {
  const _AlertRoutePreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NavAbleRadius.small),
      child: SizedBox(
        height: 112,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _AlertRoutePainter()),
            const Positioned(
              left: 10,
              bottom: 8,
              child: Text(
                'Central Hub Area',
                style: TextStyle(
                  color: kNavAbleNavy,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7ECEF),
    );

    final streets = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-8, size.height * .75),
      Offset(size.width + 8, size.height * .25),
      streets,
    );
    canvas.drawLine(
      Offset(size.width * .22, -8),
      Offset(size.width * .55, size.height + 8),
      streets..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(size.width * .78, -8),
      Offset(size.width * .62, size.height + 8),
      streets,
    );

    final route = Path()
      ..moveTo(size.width * .17, size.height * .82)
      ..quadraticBezierTo(
        size.width * .42,
        size.height * .7,
        size.width * .47,
        size.height * .48,
      )
      ..quadraticBezierTo(
        size.width * .57,
        size.height * .22,
        size.width * .82,
        size.height * .18,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = kNavAbleGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    final pointPaint = Paint()..color = kNavAbleNavy;
    for (final point in [
      Offset(size.width * .17, size.height * .82),
      Offset(size.width * .47, size.height * .48),
      Offset(size.width * .82, size.height * .18),
    ]) {
      canvas.drawCircle(point, 5, pointPaint);
      canvas.drawCircle(point, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
