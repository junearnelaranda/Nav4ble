part of '../home.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.contributionPoints,
    required this.reportCount,
    required this.savedPlaceCount,
    required this.statsLoading,
    required this.submissions,
    required this.onEditProfile,
    required this.onOpenInfo,
    required this.onSignOut,
    required this.onReportPlace,
    required this.pointsSection,
  });

  final NavAbleUser? user;
  final int? contributionPoints;
  final int? reportCount;
  final int? savedPlaceCount;
  final bool statsLoading;
  final List<AccessibilitySubmission> submissions;
  final VoidCallback onEditProfile;
  final void Function(String title, String body) onOpenInfo;
  final VoidCallback onSignOut;

  /// Opens the Reports tab to report a problem at a place.
  final VoidCallback onReportPlace;

  /// Level, points, history and the way to Top Contributors.
  final Widget pointsSection;

  String get _displayName {
    final name = user?.fullName.trim() ?? '';
    if (name.isNotEmpty) return name;

    final email = user?.email.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'NavAble Traveler';
  }

  String get _initials => initialsOf(_displayName, fallback: 'NA');

  void _openAccessibilitySettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsScreen(
          submissions: submissions,
          reportCount: reportCount,
          onOpenInfo: onOpenInfo,
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const CircleAvatar(
          radius: 26,
          backgroundColor: Color(0xFFFEE4E2),
          child: Icon(Icons.logout_rounded, color: Color(0xFFB42318), size: 27),
        ),
        title: Text('Are you sure you want to sign out?'),
        content: Text(
          'You will need to log in again to access your NavAble profile.',
          textAlign: TextAlign.center,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            icon: Icon(Icons.logout_rounded, size: 18),
            label: Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = user?.profileImageBytes;

    final header = Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 104,
                height: 104,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [kNavAbleGreen, NavAblePalette.greenDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFE8F3EC),
                  foregroundImage: profileImage == null
                      ? null
                      : MemoryImage(profileImage),
                  child: profileImage == null
                      ? Text(
                          _initials,
                          style: const TextStyle(
                            color: NavAblePalette.navy,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                right: 1,
                bottom: 3,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: NavAblePalette.greenDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NavAbleSpacing.sm),
          Text(
            _displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (user?.email.isNotEmpty ?? false) ...[
            const SizedBox(height: NavAbleSpacing.xxs),
            Text(
              user!.email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
    final stats = Row(
      children: [
        Expanded(
          child: _ProfileStatCard(
            icon: Icons.assignment_turned_in_outlined,
            value: reportCount,
            loading: statsLoading,
            label: 'Reports Submitted',
            foreground: NavAblePalette.greenDark,
            background: const Color(0xFFDDF9E3),
          ),
        ),
        const SizedBox(width: NavAbleSpacing.sm),
        Expanded(
          child: _ProfileStatCard(
            icon: Icons.bookmark_border_rounded,
            value: savedPlaceCount,
            loading: statsLoading,
            label: 'Saved Places',
            foreground: NavAblePalette.navy,
            background: const Color(0xFFDDEEFF),
          ),
        ),
      ],
    );
    final editButton = Tooltip(
      message: 'Edit profile',
      child: SizedBox(
        height: NavAbleSize.primaryButton,
        child: FilledButton.icon(
          onPressed: onEditProfile,
          icon: Icon(Icons.edit_outlined, size: 19),
          label: Text('Edit Profile'),
        ),
      ),
    );
    final logOutButton = SizedBox(
      height: NavAbleSize.control,
      child: OutlinedButton.icon(
        onPressed: () => _confirmSignOut(context),
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(Color(0xFFB42318)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFFFECDCA);
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFFFEE4E2);
            }
            return NavAblePalette.surface;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFFB42318), width: 1.3),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NavAbleRadius.button),
            ),
          ),
          animationDuration: const Duration(milliseconds: 160),
        ),
        icon: Icon(Icons.logout_rounded, size: 19),
        label: Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
    final settings = NavAbleSurface(
      width: double.infinity,
      padding: EdgeInsets.zero,
      borderRadius: NavAbleRadius.control,
      child: Column(
        children: [
          _ProfileMenuTile(
            icon: Icons.accessibility_new_rounded,
            label: 'Accessibility Settings',
            onTap: () => _openAccessibilitySettings(context),
          ),
          const Divider(indent: 52),
          _ProfileMenuTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    _HelpSupportScreen(onReportPlace: onReportPlace),
              ),
            ),
          ),
        ],
      ),
    );

    if (context.screenSize != ScreenSize.phone) {
      // Wide windows: the profile card on the left; points, settings and
      // logging out on the right.
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          PageWidth(
            maxWidth: 1100,
            child: TwoColumns(
              startWidth: 320,
              gap: NavAbleSpacing.lg,
              breakAt: 700,
              start: NavAbleSurface(
                key: const ValueKey('profile-card'),
                width: double.infinity,
                padding: const EdgeInsets.all(NavAbleSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: NavAbleSpacing.lg),
                    stats,
                    const SizedBox(height: NavAbleSpacing.lg),
                    editButton,
                  ],
                ),
              ),
              end: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  pointsSection,
                  const SizedBox(height: NavAbleSpacing.lg),
                  settings,
                  const SizedBox(height: NavAbleSpacing.lg),
                  logOutButton,
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Phones: today's order.
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.xxl,
      ),
      children: [
        header,
        const SizedBox(height: NavAbleSpacing.xl),
        pointsSection,
        const SizedBox(height: NavAbleSpacing.sm),
        stats,
        const SizedBox(height: NavAbleSpacing.lg),
        editButton,
        const SizedBox(height: NavAbleSpacing.sm),
        logOutButton,
        const SizedBox(height: NavAbleSpacing.xl),
        settings,
      ],
    );
  }
}

class _ProfileMetricIcon extends StatelessWidget {
  const _ProfileMetricIcon({
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
      child: Icon(icon, color: foreground, size: 22),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.loading,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final int? value;
  final bool loading;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      padding: const EdgeInsets.all(NavAbleSpacing.md),
      borderRadius: NavAbleRadius.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileMetricIcon(
            icon: icon,
            foreground: foreground,
            background: background,
          ),
          const SizedBox(height: NavAbleSpacing.sm),
          Text(
            value?.toString() ?? (loading ? '...' : '--'),
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.navAbleSecondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        minTileHeight: NavAbleSize.control,
        leading: Icon(icon, color: context.navAblePrimaryText, size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: context.navAblePrimaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.navAbleSecondaryText,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
