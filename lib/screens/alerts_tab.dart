part of '../home.dart';

class _AlertsPage extends StatelessWidget {
  const _AlertsPage({
    required this.reports,
    required this.alerts,
    required this.onOpenReports,
  });

  /// The user's stored reports with their review status.
  final List<MyReport> reports;

  /// Alerts from the database (points, level ups, admin messages), newest
  /// first; shown after the reports.
  final List<AppAlert> alerts;
  final VoidCallback onOpenReports;

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
        Text(
          'Alerts',
          style: TextStyle(
            color: context.navAblePrimaryText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xs),
        Text(
          'Stay updated on your accessibility reports and community status.',
          style: TextStyle(
            color: context.navAbleSecondaryText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: NavAbleSpacing.lg),
        if (reports.isEmpty && alerts.isEmpty)
          _EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No alerts yet',
            detail: 'Updates about your reports will appear here.',
          )
        else
          for (final report in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: NavAbleSpacing.sm),
              child: _AlertCard(
                leading: _AlertStatusIcon(
                  icon: _reportStatusIcon(report.status),
                  foreground: context.navAblePrimaryText,
                  background: NavAblePalette.green.withValues(alpha: 0.16),
                ),
                title: report.status == ReportStatus.pending
                    ? 'Awaiting administrator review'
                    : 'Report ${report.status.label.toLowerCase()}',
                time: _alertTime(report.createdAt),
                body: '${report.title} · ${report.placeName}',
                onTap: onOpenReports,
              ),
            ),
        for (final alert in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: NavAbleSpacing.sm),
            child: _AlertCard(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  _AlertStatusIcon(
                    icon: switch (alert.type) {
                      'Points' => Icons.stars_rounded,
                      'Level Up' => Icons.military_tech_rounded,
                      _ => Icons.info_outline_rounded,
                    },
                    foreground: context.navAblePrimaryText,
                    background: NavAblePalette.green.withValues(alpha: 0.16),
                  ),
                  if (!alert.isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Semantics(
                        label: 'New',
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: NavAblePalette.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: alert.title,
              time: _alertTime(alert.createdAt),
              body: alert.message,
            ),
          ),
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
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String time;
  final String body;
  final VoidCallback? onTap;

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
                        style: TextStyle(
                          color: context.navAblePrimaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: NavAbleSpacing.xs),
                    Text(
                      time,
                      style: TextStyle(
                        color: context.navAbleSecondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: context.navAbleSecondaryText,
                    fontSize: 13,
                    height: 1.45,
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

/// "Just now", "5m", "3h", or "Nov 7".
String _alertTime(DateTime at) {
  final age = DateTime.now().difference(at);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  return _shortDate(at);
}
