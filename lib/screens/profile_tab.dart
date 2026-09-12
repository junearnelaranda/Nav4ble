part of '../home.dart';

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.user,
    required this.contributionPoints,
    required this.reportCount,
    required this.savedPlaceCount,
    required this.submissions,
    required this.voiceGuidance,
    required this.onVoiceGuidanceChanged,
    required this.onEditProfile,
    required this.onOpenInfo,
    required this.onSignOut,
  });

  final NavAbleUser? user;
  final int contributionPoints;
  final int reportCount;
  final int savedPlaceCount;
  final List<AccessibilitySubmission> submissions;
  final bool voiceGuidance;
  final ValueChanged<bool> onVoiceGuidanceChanged;
  final VoidCallback onEditProfile;
  final void Function(String title, String body) onOpenInfo;
  final VoidCallback onSignOut;

  String get _displayName {
    final name = user?.fullName.trim() ?? '';
    if (name.isNotEmpty) return name;

    final email = user?.email.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'NavAble Traveler';
  }

  String get _initials {
    final words = _displayName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'NA';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  void _openAccessibilitySettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsScreen(
          voiceGuidance: voiceGuidance,
          onVoiceGuidanceChanged: onVoiceGuidanceChanged,
          submissions: submissions,
          onOpenInfo: onOpenInfo,
          onSignOut: onSignOut,
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
        title: const Text('Are you sure you want to sign out?'),
        content: const Text(
          'You will need to log in again to access your NavAble profile.',
          textAlign: TextAlign.center,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = user?.profileImageBytes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.md,
        NavAbleSpacing.xxl,
      ),
      children: [
        Center(
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
                                color: kNavAbleNavy,
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
                      child: const Icon(
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
                style: const TextStyle(
                  color: kNavAbleNavy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: NavAbleSpacing.xxs),
              const Text(
                'NavAble Gold Member • Verified Contributor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kNavAbleText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (user?.email.isNotEmpty ?? false) ...[
                const SizedBox(height: NavAbleSpacing.xxs),
                Text(
                  user!.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kNavAbleText, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xl),
        NavAbleSurface(
          width: double.infinity,
          padding: const EdgeInsets.all(NavAbleSpacing.md),
          borderRadius: NavAbleRadius.control,
          enableHover: true,
          onTap: () => onOpenInfo(
            'Accessibility Contributions',
            'Your verified reports, route confirmations, and accessibility updates help other NavAble travelers move with confidence.',
          ),
          child: Row(
            children: [
              const _ProfileMetricIcon(
                icon: Icons.workspace_premium_rounded,
                foreground: Colors.white,
                background: kNavAbleNavy,
              ),
              const SizedBox(width: NavAbleSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCESSIBILITY CONTRIBUTIONS',
                      style: TextStyle(
                        color: kNavAbleText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$contributionPoints',
                      style: const TextStyle(
                        color: kNavAbleNavy,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kNavAbleText),
            ],
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ProfileStatCard(
                icon: Icons.assignment_turned_in_outlined,
                value: reportCount,
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
                label: 'Saved Places',
                foreground: kNavAbleNavy,
                background: const Color(0xFFDDEEFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: NavAbleSpacing.lg),
        Tooltip(
          message: 'Edit profile',
          child: SizedBox(
            height: NavAbleSize.primaryButton,
            child: FilledButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 19),
              label: const Text('Edit Profile'),
            ),
          ),
        ),
        const SizedBox(height: NavAbleSpacing.sm),
        SizedBox(
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
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: NavAbleSpacing.xl),
        NavAbleSurface(
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
                icon: Icons.map_outlined,
                label: 'Offline Maps',
                onTap: () => onOpenInfo(
                  'Offline Maps',
                  'Offline map downloads will become available after the map provider and local storage services are connected.',
                ),
              ),
              const Divider(indent: 52),
              _ProfileMenuTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () => onOpenInfo(
                  'Help & Support',
                  'Support contact tools are ready as Flutter screens. A real support email, chat, or ticketing service can be connected later.',
                ),
              ),
            ],
          ),
        ),
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
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final int value;
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
            '$value',
            style: const TextStyle(
              color: kNavAbleNavy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kNavAbleText,
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
        leading: Icon(icon, color: kNavAbleNavy, size: 20),
        title: Text(
          label,
          style: const TextStyle(
            color: kNavAbleNavy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: kNavAbleText,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
