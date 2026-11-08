part of '../home.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _shortDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}';

/// Level badge: a colored pill with the level's name, so color is never the
/// only cue.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.name, this.size = 13});

  final int level;
  final String name;
  final double size;

  /// (background, foreground) in light mode, then dark mode.
  static (Color, Color) colorsFor(LevelBadge badge, bool dark) {
    final (lightBg, lightFg, darkBg, darkFg) = switch (badge) {
      LevelBadge.newcomer => (0xFFF1EFE8, 0xFF444441, 0xFF444441, 0xFFF1EFE8),
      LevelBadge.explorer => (0xFFE1F5EE, 0xFF085041, 0xFF085041, 0xFF9FE1CB),
      LevelBadge.bronze => (0xFFFAECE7, 0xFF712B13, 0xFF712B13, 0xFFF5C4B3),
      LevelBadge.silver => (0xFFE9EEF2, 0xFF3A4651, 0xFF3A4651, 0xFFDCE3E8),
      LevelBadge.gold => (0xFFFAEEDA, 0xFF633806, 0xFF633806, 0xFFFAC775),
      LevelBadge.platinum => (0xFFEEEDFE, 0xFF3C3489, 0xFF3C3489, 0xFFCECBF6),
    };
    return dark
        ? (Color(darkBg), Color(darkFg))
        : (Color(lightBg), Color(lightFg));
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colorsFor(
      badgeFor(level),
      context.isNavAbleDark,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: size * 0.75,
          vertical: size * 0.3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              level == 0
                  ? Icons.emoji_people_rounded
                  : Icons.military_tech_rounded,
              size: size + 3,
              color: foreground,
            ),
            SizedBox(width: size * 0.3),
            Text(
              name,
              style: TextStyle(
                color: foreground,
                fontSize: size,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile card for contributor points: level, progress, history, pending
/// contributions, the rewards notice and the way to the leaderboard.
class _PointsSection extends StatelessWidget {
  const _PointsSection({
    required this.isGuest,
    required this.loading,
    required this.failed,
    required this.standing,
    required this.awards,
    required this.pending,
    required this.onOpenLeaderboard,
    required this.onSignIn,
  });

  final bool isGuest;
  final bool loading;
  final bool failed;
  final MyStanding? standing;
  final List<PointsAward> awards;
  final List<PendingContribution> pending;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final leaderboardButton = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onOpenLeaderboard,
        icon: const Icon(Icons.emoji_events_outlined),
        label: const Text('Top Contributors'),
      ),
    );
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.md),
      borderRadius: NavAbleRadius.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isGuest)
            ..._guest(context)
          else if (standing case final standing?)
            ..._points(context, standing)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: NavAbleSpacing.sm),
              child: Text(
                loading && !failed
                    ? 'Loading your points…'
                    : 'Points unavailable right now',
                style: TextStyle(color: context.navAbleSecondaryText),
              ),
            ),
          const SizedBox(height: NavAbleSpacing.sm),
          const _RewardsComingSoon(),
          const SizedBox(height: NavAbleSpacing.sm),
          leaderboardButton,
        ],
      ),
    );
  }

  List<Widget> _guest(BuildContext context) => [
    Text(
      'Sign in to earn points',
      style: TextStyle(
        color: context.navAblePrimaryText,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    ),
    const SizedBox(height: 4),
    Text(
      'Share accessibility photos and reports to earn points, levels and a '
      'place on the leaderboard.',
      style: TextStyle(color: context.navAbleSecondaryText, height: 1.4),
    ),
    const SizedBox(height: NavAbleSpacing.sm),
    FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
  ];

  List<Widget> _points(BuildContext context, MyStanding standing) {
    final progress = standing.progress;
    final next = progress.next;
    return [
      Row(
        children: [
          _LevelBadge(level: progress.level, name: progress.name),
          const SizedBox(width: NavAbleSpacing.xs),
          Expanded(
            child: Text(
              progress.level == 0
                  ? 'No level yet'
                  : 'Level ${progress.level} · ${progress.name}',
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: NavAbleSpacing.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${progress.points}',
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'contribution points',
            style: TextStyle(color: context.navAbleSecondaryText, fontSize: 13),
          ),
        ],
      ),
      const SizedBox(height: NavAbleSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: progress.fraction,
          minHeight: 8,
          color: NavAblePalette.green,
          backgroundColor: NavAblePalette.green.withValues(alpha: 0.18),
          semanticsLabel: 'Level progress',
          // Must be a number in this Flutter version; the line below the bar
          // says the rest for screen readers.
          semanticsValue: '${(progress.fraction * 100).round()}',
        ),
      ),
      const SizedBox(height: 6),
      Text(
        next == null
            ? 'Top level reached'
            : '${progress.points} / ${next.minPoints} to ${next.name}',
        style: TextStyle(color: context.navAbleSecondaryText, fontSize: 12),
      ),
      const SizedBox(height: NavAbleSpacing.md),
      Text(
        'Points history',
        style: TextStyle(
          color: context.navAblePrimaryText,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      if (awards.isEmpty && pending.isEmpty)
        Text(
          'No points yet. Share an accessibility photo or report to earn '
          'your first points.',
          style: TextStyle(color: context.navAbleSecondaryText, height: 1.4),
        ),
      for (final item in pending.take(5))
        _HistoryRow(
          leading: Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: context.navAbleSecondaryText,
          ),
          text:
              '${item.kind} at ${item.placeName} · ${_shortDate(item.createdAt)}',
          trailing: 'Pending review',
        ),
      for (final award in awards.take(10))
        _HistoryRow(
          leading: Text(
            '+${award.points}',
            style: const TextStyle(
              color: NavAblePalette.green,
              fontWeight: FontWeight.w900,
            ),
          ),
          text:
              '${award.tier} · ${award.sourceType} at ${award.placeName} · '
              '${_shortDate(award.createdAt)}',
        ),
    ];
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.leading, required this.text, this.trailing});

  final Widget leading;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 40, child: leading),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.navAblePrimaryText, fontSize: 13),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
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

class _RewardsComingSoon extends StatelessWidget {
  const _RewardsComingSoon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.navAbleSecondaryText.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.card_giftcard_rounded,
            color: context.navAbleSecondaryText,
          ),
          const SizedBox(width: NavAbleSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rewards — coming soon',
                  style: TextStyle(
                    color: context.navAblePrimaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Rewards aren't available yet. Keep contributing. Your points "
                  'will count when they launch.',
                  style: TextStyle(
                    color: context.navAbleSecondaryText,
                    fontSize: 12,
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
