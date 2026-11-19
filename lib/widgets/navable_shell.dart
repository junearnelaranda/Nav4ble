import 'package:flutter/material.dart';

import 'adaptive_layout.dart';

/// The app frame: on phones the top app bar and bottom tab bar, on wider
/// windows the side menu (icons only, or with labels from 1000 px).
///
/// [page] keeps its state when the window is resized across a breakpoint,
/// because it always sits under the same [pageKey].
class NavAbleShell extends StatelessWidget {
  const NavAbleShell({
    super.key,
    required this.pageKey,
    required this.page,
    required this.appBar,
    required this.bottomBar,
    required this.sideMenu,
    this.backgroundColor,
  });

  final GlobalKey pageKey;
  final Widget page;
  final PreferredSizeWidget appBar;
  final Widget bottomBar;
  final Widget Function(bool extended) sideMenu;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final size = context.screenSize;
    final body = KeyedSubtree(key: pageKey, child: page);
    if (size == ScreenSize.phone) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        body: SafeArea(child: body),
        bottomNavigationBar: bottomBar,
      );
    }
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sideMenu(size == ScreenSize.wide),
          Expanded(child: SafeArea(left: false, child: body)),
        ],
      ),
    );
  }
}
