part of '../home.dart';

class _MySubmissionsScreen extends StatefulWidget {
  const _MySubmissionsScreen({required this.submissions});

  final List<AccessibilitySubmission> submissions;

  @override
  State<_MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<_MySubmissionsScreen> {
  SubmissionStatus _selectedStatus = SubmissionStatus.pending;

  List<AccessibilitySubmission> get _filteredSubmissions {
    return widget.submissions
        .where((submission) => submission.status == _selectedStatus)
        .toList();
  }

  int _countFor(SubmissionStatus status) {
    return widget.submissions
        .where((submission) => submission.status == status)
        .length;
  }

  void _openDetails(AccessibilitySubmission submission) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SubmissionDetailsScreen(submission: submission),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final approvedCount = _countFor(SubmissionStatus.approved);

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: NavAbleSpacing.sm),
            child: Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NavAbleSpacing.md,
            NavAbleSpacing.md,
            NavAbleSpacing.md,
            NavAbleSpacing.xxl,
          ),
          children: [
            const Text(
              'My Submissions',
              style: TextStyle(
                color: kNavAbleNavy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.xs),
            const Text(
              'Track the status of accessibility reports you’ve shared with the community.',
              style: TextStyle(color: kNavAbleText, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            _SubmissionStatusTabs(
              selectedStatus: _selectedStatus,
              countFor: _countFor,
              onSelected: (status) => setState(() => _selectedStatus = status),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            if (_filteredSubmissions.isEmpty)
              _EmptyState(
                icon: _selectedStatus.icon,
                title: 'No ${_selectedStatus.label.toLowerCase()} submissions',
                detail: 'Reports with this status will appear here.',
              )
            else
              for (final submission in _filteredSubmissions)
                Padding(
                  padding: const EdgeInsets.only(bottom: NavAbleSpacing.sm),
                  child: _SubmissionCard(
                    submission: submission,
                    onViewDetails: () => _openDetails(submission),
                  ),
                ),
            const SizedBox(height: NavAbleSpacing.xs),
            _ContributorProgressCard(reportCount: widget.submissions.length),
            const SizedBox(height: NavAbleSpacing.sm),
            _TrustScoreCard(approvedCount: approvedCount),
          ],
        ),
      ),
    );
  }
}

extension on SubmissionStatus {
  String get label => switch (this) {
    SubmissionStatus.pending => 'Pending',
    SubmissionStatus.approved => 'Approved',
    SubmissionStatus.rejected => 'Rejected',
  };

  IconData get icon => switch (this) {
    SubmissionStatus.pending => Icons.schedule_rounded,
    SubmissionStatus.approved => Icons.check_circle_outline_rounded,
    SubmissionStatus.rejected => Icons.cancel_outlined,
  };

  Color get foreground => switch (this) {
    SubmissionStatus.pending => const Color(0xFFB54708),
    SubmissionStatus.approved => NavAblePalette.greenDark,
    SubmissionStatus.rejected => const Color(0xFFB42318),
  };

  Color get background => switch (this) {
    SubmissionStatus.pending => const Color(0xFFFFF3D6),
    SubmissionStatus.approved => const Color(0xFFDDF9E3),
    SubmissionStatus.rejected => const Color(0xFFFEE4E2),
  };
}

class _SubmissionStatusTabs extends StatelessWidget {
  const _SubmissionStatusTabs({
    required this.selectedStatus,
    required this.countFor,
    required this.onSelected,
  });

  final SubmissionStatus selectedStatus;
  final int Function(SubmissionStatus status) countFor;
  final ValueChanged<SubmissionStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(NavAbleRadius.control),
      ),
      child: Row(
        children: [
          for (final status in SubmissionStatus.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  button: true,
                  selected: selectedStatus == status,
                  child: InkWell(
                    onTap: () => onSelected(status),
                    borderRadius: BorderRadius.circular(NavAbleRadius.tile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: NavAbleSize.compactControl,
                      decoration: BoxDecoration(
                        color: selectedStatus == status
                            ? status == SubmissionStatus.pending
                                  ? const Color(0xFF82F39A)
                                  : status.background
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(NavAbleRadius.tile),
                      ),
                      child: Center(
                        child: Text(
                          '${status.label} (${countFor(status)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selectedStatus == status
                                ? kNavAbleNavy
                                : kNavAbleText,
                            fontSize: 11,
                            fontWeight: selectedStatus == status
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    required this.onViewDetails,
  });

  final AccessibilitySubmission submission;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.md),
      borderRadius: NavAbleRadius.control,
      enableHover: true,
      onTap: onViewDetails,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE9FF),
                  borderRadius: BorderRadius.circular(NavAbleRadius.small),
                ),
                child: Icon(submission.icon, color: kNavAbleNavy, size: 23),
              ),
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
                            submission.title,
                            style: const TextStyle(
                              color: kNavAbleNavy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: NavAbleSpacing.xs),
                        _SubmissionStatusPill(status: submission.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted on ${submission.submittedOn}',
                      style: const TextStyle(color: kNavAbleText, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NavAbleSpacing.md),
          const Divider(),
          const SizedBox(height: NavAbleSpacing.sm),
          Row(
            children: [
              Icon(
                submission.status.icon,
                color: submission.status.foreground,
                size: 16,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  submission.statusDetail,
                  style: TextStyle(
                    color: submission.status.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onViewDetails,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: kNavAbleNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(48, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmissionStatusPill extends StatelessWidget {
  const _SubmissionStatusPill({required this.status});

  final SubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(NavAbleRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status.label,
          style: TextStyle(
            color: status.foreground,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ContributorProgressCard extends StatelessWidget {
  const _ContributorProgressCard({required this.reportCount});

  final int reportCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NavAbleSpacing.lg),
      decoration: BoxDecoration(
        color: kNavAbleNavy,
        borderRadius: BorderRadius.circular(NavAbleRadius.control),
        boxShadow: [
          BoxShadow(
            color: kNavAbleNavy.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: Color(0xFF9CB5D0)),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(NavAbleRadius.pill),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  child: Text(
                    'Level 4 Contributor',
                    style: TextStyle(
                      color: Color(0xFFBFD0E0),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NavAbleSpacing.lg),
          Text(
            '$reportCount Reports',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Helping thousands find their way.',
            style: TextStyle(color: Color(0xFFBFD0E0), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard({required this.approvedCount});

  final int approvedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NavAbleSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF83F293),
        borderRadius: BorderRadius.circular(NavAbleRadius.control),
        boxShadow: [
          BoxShadow(
            color: NavAblePalette.green.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: kNavAbleNavy,
              ),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(NavAbleRadius.pill),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  child: Text(
                    'Trust Score: 98%',
                    style: TextStyle(
                      color: kNavAbleNavy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NavAbleSpacing.lg),
          Text(
            '$approvedCount Approved',
            style: const TextStyle(
              color: kNavAbleNavy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Your contributions are highly accurate.',
            style: TextStyle(color: kNavAbleNavy, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SubmissionDetailsScreen extends StatelessWidget {
  const _SubmissionDetailsScreen({required this.submission});

  final AccessibilitySubmission submission;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(NavAbleSpacing.lg),
          children: [
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE9FF),
                          borderRadius: BorderRadius.circular(
                            NavAbleRadius.tile,
                          ),
                        ),
                        child: Icon(submission.icon, color: kNavAbleNavy),
                      ),
                      const SizedBox(width: NavAbleSpacing.sm),
                      Expanded(
                        child: Text(
                          submission.title,
                          style: const TextStyle(
                            color: kNavAbleNavy,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NavAbleSpacing.lg),
                  _SubmissionStatusPill(status: submission.status),
                  const SizedBox(height: NavAbleSpacing.md),
                  Text(
                    submission.statusDetail,
                    style: TextStyle(
                      color: submission.status.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: NavAbleSpacing.xs),
                  Text(
                    'Submitted on ${submission.submittedOn}',
                    style: const TextStyle(color: kNavAbleText),
                  ),
                  const SizedBox(height: NavAbleSpacing.lg),
                  const Text(
                    'Community reviewers check the location, accessibility details, and supporting photo before updating this status.',
                    style: TextStyle(color: kNavAbleText, height: 1.5),
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
