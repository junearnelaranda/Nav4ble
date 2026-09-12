part of '../home.dart';

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen({
    required this.voiceGuidance,
    required this.onVoiceGuidanceChanged,
    required this.submissions,
    required this.onOpenInfo,
    required this.onSignOut,
  });

  final bool voiceGuidance;
  final ValueChanged<bool> onVoiceGuidanceChanged;
  final List<AccessibilitySubmission> submissions;
  final void Function(String title, String body) onOpenInfo;
  final VoidCallback onSignOut;

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  late bool _darkMode;
  late bool _voiceGuidance;
  late double _textScale;
  late String _language;

  @override
  void initState() {
    super.initState();
    _darkMode = NavAblePreferences.themeMode.value == ThemeMode.dark;
    _voiceGuidance = widget.voiceGuidance;
    _textScale = NavAblePreferences.textScale.value;
    _language = NavAblePreferences.language.value;
  }

  Color _surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? NavAblePalette.darkSurface
        : NavAblePalette.surface;
  }

  Color _primaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : kNavAbleNavy;
  }

  Color _secondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? NavAblePalette.darkText
        : kNavAbleText;
  }

  Future<void> _chooseLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NavAbleRadius.card),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          NavAbleSpacing.md,
          NavAbleSpacing.xs,
          NavAbleSpacing.md,
          NavAbleSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Language',
              style: TextStyle(
                color: _primaryText(context),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.sm),
            RadioGroup<String>(
              groupValue: _language,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                children: [
                  for (final language in const [
                    'English (United States)',
                    'Filipino',
                    'Cebuano',
                  ])
                    RadioListTile<String>(
                      value: language,
                      activeColor: NavAblePalette.greenDark,
                      title: Text(language),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() => _language = selected);
    NavAblePreferences.language.value = selected;
  }

  void _openSubmissions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            _MySubmissionsScreen(submissions: widget.submissions),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure you want to sign out?'),
        content: const Text(
          'You will return to the welcome screen. Your local demo data will remain available until the app closes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final secondaryText = _secondaryText(context);

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
            NavAbleSpacing.xs,
            NavAbleSpacing.md,
            NavAbleSpacing.xxl,
          ),
          children: [
            const _SettingsSectionLabel(label: 'GENERAL SETTINGS'),
            const SizedBox(height: NavAbleSpacing.xs),
            _SettingsCard(
              color: _surface(context),
              child: _SettingsSwitchTile(
                icon: Icons.dark_mode_outlined,
                iconBackground: const Color(0xFFE7EAEE),
                title: 'Dark Mode',
                subtitle: 'Switch to high-contrast dark theme',
                value: _darkMode,
                onChanged: (value) {
                  setState(() => _darkMode = value);
                  NavAblePreferences.themeMode.value = value
                      ? ThemeMode.dark
                      : ThemeMode.light;
                },
              ),
            ),
            const SizedBox(height: NavAbleSpacing.xs),
            _SettingsCard(
              color: _surface(context),
              child: _SettingsNavigationTile(
                icon: Icons.language_rounded,
                iconBackground: const Color(0xFFE7EAEE),
                title: 'Language',
                subtitle: _language,
                onTap: _chooseLanguage,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            const _SettingsSectionLabel(label: 'ACCESSIBILITY OPTIONS'),
            const SizedBox(height: NavAbleSpacing.xs),
            _SettingsCard(
              color: _surface(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NavAbleSpacing.sm,
                  NavAbleSpacing.sm,
                  NavAbleSpacing.sm,
                  NavAbleSpacing.xs,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const _SettingsIcon(
                          icon: Icons.text_fields_rounded,
                          background: kNavAbleNavy,
                          foreground: Colors.white,
                        ),
                        const SizedBox(width: NavAbleSpacing.sm),
                        Text(
                          'Text Size',
                          style: TextStyle(
                            color: _primaryText(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _textScale,
                      min: 0.8,
                      max: 1.2,
                      divisions: 8,
                      activeColor: NavAblePalette.greenDark,
                      label: '${(_textScale * 100).round()}%',
                      onChanged: (value) {
                        setState(() => _textScale = value);
                        NavAblePreferences.textScale.value = value;
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Small',
                          style: TextStyle(color: secondaryText, fontSize: 10),
                        ),
                        Text(
                          'Normal',
                          style: TextStyle(color: secondaryText, fontSize: 10),
                        ),
                        Text(
                          'Large',
                          style: TextStyle(color: secondaryText, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.xs),
            _SettingsCard(
              color: _surface(context),
              child: _SettingsSwitchTile(
                icon: Icons.record_voice_over_outlined,
                iconBackground: const Color(0xFFDDF9E3),
                iconForeground: NavAblePalette.greenDark,
                title: 'Voice Navigation',
                subtitle: 'Step-by-step audio cues',
                value: _voiceGuidance,
                onChanged: (value) {
                  setState(() => _voiceGuidance = value);
                  widget.onVoiceGuidanceChanged(value);
                },
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            const _SettingsSectionLabel(label: 'COMMUNITY'),
            const SizedBox(height: NavAbleSpacing.xs),
            _SettingsCard(
              color: _surface(context),
              child: _SettingsNavigationTile(
                icon: Icons.assignment_turned_in_outlined,
                iconBackground: kNavAbleNavy,
                iconForeground: Colors.white,
                title: 'My Submissions',
                subtitle: 'Track your accessibility reports',
                onTap: _openSubmissions,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            const _SettingsSectionLabel(label: 'PRIVACY & INFORMATION'),
            const SizedBox(height: NavAbleSpacing.xs),
            _SettingsCard(
              color: _surface(context),
              child: Column(
                children: [
                  _SettingsNavigationTile(
                    icon: Icons.privacy_tip_outlined,
                    iconBackground: Colors.transparent,
                    title: 'Privacy Policy',
                    trailing: Icons.open_in_new_rounded,
                    onTap: () => widget.onOpenInfo(
                      'Privacy Policy',
                      'This front-end prototype stores account, report, and saved-place data only in memory while the app is running.',
                    ),
                  ),
                  const Divider(indent: 54),
                  _SettingsNavigationTile(
                    icon: Icons.info_outline_rounded,
                    iconBackground: Colors.transparent,
                    title: 'About NavAble',
                    onTap: () => widget.onOpenInfo(
                      'About NavAble',
                      'NavAble is an accessibility-first navigation prototype designed to make every route clearer and more inclusive.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            SizedBox(
              height: NavAbleSize.control,
              child: FilledButton.icon(
                onPressed: _confirmSignOut,
                style: FilledButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor: const Color(0xFFFEE4E2),
                  foregroundColor: const Color(0xFFB42318),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: dark ? NavAblePalette.green : NavAblePalette.greenDark,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: EdgeInsets.zero,
      borderRadius: NavAbleRadius.control,
      color: color,
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: background,
      child: Icon(icon, color: foreground, size: 19),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconBackground,
    this.iconForeground = kNavAbleNavy,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      minTileHeight: 66,
      contentPadding: const EdgeInsets.symmetric(horizontal: NavAbleSpacing.sm),
      secondary: _SettingsIcon(
        icon: icon,
        background: iconBackground,
        foreground: iconForeground,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: dark ? Colors.white : kNavAbleNavy,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: dark ? NavAblePalette.darkText : kNavAbleText,
          fontSize: 11,
        ),
      ),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: NavAblePalette.greenDark,
      onChanged: onChanged,
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.icon,
    required this.iconBackground,
    this.iconForeground = kNavAbleNavy,
    required this.title,
    this.subtitle,
    this.trailing = Icons.chevron_right_rounded,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String title;
  final String? subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconForeground = dark && iconBackground == Colors.transparent
        ? NavAblePalette.darkText
        : iconForeground;
    return ListTile(
      minTileHeight: 66,
      contentPadding: const EdgeInsets.symmetric(horizontal: NavAbleSpacing.sm),
      leading: _SettingsIcon(
        icon: icon,
        background: iconBackground,
        foreground: effectiveIconForeground,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: dark ? Colors.white : kNavAbleNavy,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: dark ? NavAblePalette.darkText : kNavAbleText,
                fontSize: 11,
              ),
            ),
      trailing: Icon(
        trailing,
        color: dark ? NavAblePalette.darkText : kNavAbleText,
        size: 19,
      ),
      onTap: onTap,
    );
  }
}
