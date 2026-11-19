import 'package:flutter/material.dart';

import '../navable_design.dart';

/// One page in the side menu.
class SideMenuItem {
  const SideMenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Unread count shown beside the item; hidden when 0.
  final int badge;
}

/// The navy menu on the left of wide windows: the pages, Top Contributors,
/// and the signed-in user (or a sign-in button for guests).
/// Focus and hover tints that stay visible on the navy menu.
final _focusColor = Colors.white.withValues(alpha: 0.24);
final _hoverColor = Colors.white.withValues(alpha: 0.10);

class NavAbleSideMenu extends StatelessWidget {
  const NavAbleSideMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.extended,
    required this.onLeaderboard,
    this.userName,
    this.userPhoto,
    this.onOpenProfile,
    this.onSignIn,
  });

  static const extendedWidth = 220.0;
  static const compactWidth = 80.0;

  final List<SideMenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Labels beside the icons; otherwise icons only, with tooltips.
  final bool extended;
  final VoidCallback onLeaderboard;
  final String? userName;
  final ImageProvider? userPhoto;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final name = userName;
    return Material(
      color: NavAblePalette.navy,
      child: SizedBox(
        width: extended ? extendedWidth : compactWidth,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                  children: [
                    _Brand(extended: extended),
                    const SizedBox(height: 18),
                    for (final (index, item) in items.indexed)
                      _MenuEntry(
                        key: ValueKey('side-menu-$index'),
                        icon: index == selectedIndex
                            ? item.selectedIcon
                            : item.icon,
                        label: item.label,
                        badge: item.badge,
                        selected: index == selectedIndex,
                        extended: extended,
                        onTap: () => onSelected(index),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white24, height: 1),
                    ),
                    _MenuEntry(
                      key: const ValueKey('side-menu-leaderboard'),
                      icon: Icons.emoji_events_outlined,
                      label: 'Top Contributors',
                      selected: false,
                      extended: extended,
                      onTap: onLeaderboard,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                child: name != null
                    ? _UserEntry(
                        name: name,
                        photo: userPhoto,
                        extended: extended,
                        onTap: onOpenProfile,
                      )
                    : onSignIn == null
                    ? const SizedBox.shrink()
                    : extended
                    ? FilledButton.icon(
                        onPressed: onSignIn,
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Sign in'),
                      )
                    : IconButton(
                        tooltip: 'Sign in',
                        onPressed: onSignIn,
                        color: Colors.white,
                        icon: const Icon(Icons.login_rounded),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset(
        'lib/img/logOnly.png',
        errorBuilder: (_, _, _) => const SizedBox(),
      ),
    );
    return Semantics(
      label: 'NavAble',
      excludeSemantics: true,
      child: extended
          ? Row(
              children: [
                logo,
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'NavAble',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            )
          : Center(child: logo),
    );
  }
}

class _MenuEntry extends StatelessWidget {
  const _MenuEntry({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xFFC9D6E3);
    final count = badge > 9 ? '9+' : '$badge';
    final iconWidget = Badge(
      isLabelVisible: badge > 0 && !extended,
      label: Text(count),
      backgroundColor: const Color(0xFFE5484D),
      child: Icon(icon, color: color),
    );
    Widget entry = Material(
      color: selected
          ? NavAblePalette.green.withValues(alpha: 0.18)
          : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // The theme's green tints barely show on navy.
        focusColor: _focusColor,
        hoverColor: _hoverColor,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? NavAblePalette.green : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: extended ? 12 : 0,
            vertical: 10,
          ),
          child: extended
              ? Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5484D),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                )
              : Center(child: iconWidget),
        ),
      ),
    );
    if (!extended) entry = Tooltip(message: label, child: entry);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      // One clear announcement: the page name, the unread count, and whether
      // it is the page being shown.
      child: Semantics(
        button: true,
        selected: selected,
        label: badge > 0 ? '$label, $count unread' : label,
        excludeSemantics: true,
        onTap: onTap,
        child: entry,
      ),
    );
  }
}

class _UserEntry extends StatelessWidget {
  const _UserEntry({
    required this.name,
    required this.photo,
    required this.extended,
    required this.onTap,
  });

  final String name;
  final ImageProvider? photo;
  final bool extended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: NavAblePalette.green.withValues(alpha: 0.5),
      foregroundImage: photo,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: NavAblePalette.navy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final entry = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // The theme's green tints barely show on navy.
        focusColor: _focusColor,
        hoverColor: _hoverColor,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(horizontal: extended ? 8 : 0),
          child: extended
              ? Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(child: avatar),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: 'Profile, $name',
      excludeSemantics: true,
      onTap: onTap,
      child: extended ? entry : Tooltip(message: name, child: entry),
    );
  }
}
