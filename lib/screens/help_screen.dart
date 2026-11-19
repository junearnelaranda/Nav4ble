part of '../home.dart';

const _supportEmail = 'nav4ble@gmail.com';

/// Help & Support: quick ways to get help, then common questions.
class _HelpSupportScreen extends StatelessWidget {
  const _HelpSupportScreen({required this.onReportPlace});

  /// Leaves this page and opens the Reports tab for a place problem.
  final VoidCallback onReportPlace;

  static const _questions = [
    (
      'How do I find accessible places?',
      'Open Explore, or search on the Map. Use the filters to show places '
          'with the features you need, like ramps, elevators or accessible '
          'toilets.',
    ),
    (
      'How do I add accessibility information?',
      'Open Reports and choose Contribute Accessibility. Take a photo of the '
          'ramp, elevator or other feature. The scanner suggests what it '
          'shows, and the NavAble team checks it before it appears on the map.',
    ),
    (
      'How do I know my report was checked?',
      'The NavAble team reviews every report and contribution. Updates about '
          'yours appear in the Alerts tab, and you can see them all under '
          'My Submissions.',
    ),
    (
      'How do points and levels work?',
      'You earn points when your contributions are approved. Points raise '
          'your level and can put you on Top Contributors.',
    ),
    (
      "Why can't NavAble find places near me?",
      'Allow location for NavAble in your phone or browser settings, then '
          'open the map again.',
    ),
    (
      'Do I need an internet connection?',
      'Yes. NavAble needs an internet connection to load the map, search '
          'places and plan routes. Places you save stay on your device.',
    ),
  ];

  Future<void> _emailTeam(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('mailto:$_supportEmail?subject=NavAble%20help'),
      );
    } catch (_) {}
    if (opened || !context.mounted) return;
    // No email app: give them the address instead.
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email address copied: $_supportEmail')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support'), elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NavAbleSpacing.md,
            NavAbleSpacing.md,
            NavAbleSpacing.md,
            NavAbleSpacing.xxl,
          ),
          children: [
            PageWidth(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'How can we help?',
                      style: TextStyle(
                        color: context.navAblePrimaryText,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: NavAbleSpacing.xxs),
                  Text(
                    'Pick what you need. The NavAble team reads every report.',
                    style: TextStyle(
                      color: context.navAbleSecondaryText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: NavAbleSpacing.lg),
                  _HelpActionCard(
                    icon: Icons.bug_report_outlined,
                    color: const Color(0xFFB42318),
                    title: 'Report a bug in the app',
                    detail: 'Something not working? Tell us what happened.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const _BugReportScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: NavAbleSpacing.sm),
                  _HelpActionCard(
                    icon: Icons.report_problem_outlined,
                    color: const Color(0xFFB54708),
                    title: 'Report a problem at a place',
                    detail:
                        'A broken ramp, a blocked entrance or an elevator '
                        'that is out of service.',
                    onTap: () {
                      Navigator.of(context).pop();
                      onReportPlace();
                    },
                  ),
                  const SizedBox(height: NavAbleSpacing.sm),
                  _HelpActionCard(
                    icon: Icons.mail_outline_rounded,
                    color: NavAblePalette.greenDark,
                    title: 'Email the NavAble team',
                    detail:
                        'Questions, feedback or a request about your '
                        'data: $_supportEmail',
                    onTap: () => _emailTeam(context),
                  ),
                  const SizedBox(height: NavAbleSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      'Common questions',
                      style: TextStyle(
                        color: context.navAblePrimaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: NavAbleSpacing.sm),
                  NavAbleSurface(
                    width: double.infinity,
                    padding: EdgeInsets.zero,
                    borderRadius: NavAbleRadius.control,
                    child: Material(
                      // Lets the questions show their tap ripples.
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final (index, (question, answer))
                              in _questions.indexed) ...[
                            if (index > 0) const Divider(height: 1),
                            _HelpQuestion(question: question, answer: answer),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: NavAbleSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: context.navAbleSecondaryText,
                      ),
                      const SizedBox(width: NavAbleSpacing.xs),
                      Expanded(
                        child: Text(
                          'Places can change after they are checked, so '
                          'confirm conditions on site.',
                          style: TextStyle(
                            color: context.navAbleSecondaryText,
                            fontSize: 13,
                            height: 1.4,
                          ),
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

/// A big tappable row: coloured icon, title, one line of detail.
class _HelpActionCard extends StatelessWidget {
  const _HelpActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$title. $detail',
      onTap: onTap,
      child: NavAbleSurface(
        width: double.infinity,
        padding: EdgeInsets.zero,
        borderRadius: NavAbleRadius.control,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(NavAbleRadius.control),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(NavAbleSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: NavAbleSpacing.md),
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
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: TextStyle(
                            color: context.navAbleSecondaryText,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: NavAbleSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.navAbleSecondaryText,
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

/// One question that opens to show its answer.
class _HelpQuestion extends StatelessWidget {
  const _HelpQuestion({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // No extra borders when the tile opens; the card already has dividers.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: NavAbleSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          NavAbleSpacing.md,
          0,
          NavAbleSpacing.md,
          NavAbleSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: context.navAblePrimaryText,
        collapsedIconColor: context.navAbleSecondaryText,
        title: Text(
          question,
          style: TextStyle(
            color: context.navAblePrimaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              color: context.navAbleSecondaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
