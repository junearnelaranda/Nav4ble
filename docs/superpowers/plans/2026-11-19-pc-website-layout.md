# PC Website Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On wide windows, NavAble shows a navy menu on the left and website-style layouts for Explore, Reports, Alerts and Profile, while phones stay exactly as they are.

**Architecture:**
- A small public layout toolkit: window-size classes, a width cap, two columns and a card grid.
- A side menu widget, and a shell widget that picks the bottom bar or the side menu by window width.
- The four pages become public so they can be widget-tested at phone, tablet and PC widths. Each switches to its wide layout only when the window is wide enough.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12.2 (web and Android from one codebase).

**Spec:** `docs/superpowers/specs/2026-11-19-pc-website-layout-design.md`

## Global Constraints

- **Breakpoints:** below 640 px is a phone (bottom tab bar and today's layouts); 640 to 999 px is compact (icon-only menu); 1000 px and up is wide (menu with labels).
- **Phones must look and behave exactly as today,** apart from the Alerts filter chips.
- **Menu:** `NavAblePalette.navy` background in both themes; 220 px wide with labels, 80 px with icons only; items at least 48 px tall.
- **Maximum page widths:** Explore 1200 px, Reports 1200 px, Alerts 760 px, Profile 1100 px. The Profile left column is 320 px.
- **Text scale:** 0.8 to 1.2 must never overflow.
- **Commits:** never run `git commit` or `git push`. Each task lists files for the user to commit, with no Claude attribution.
- **Tools:**
  - Flutter: `C:\FLUTTE~1\flutter\bin\flutter.bat`, from PowerShell.
  - Web zip: `python C:\NavAble-deploy\make_zip.py navable-app navable-app.zip`, run in `C:\NavAble-deploy`.

## Review Focus

1. **Resizing the window across 640 or 1000 px while typing:** the same page stays open and typed text is kept. Test in Task 4.
2. **A guest on a wide window:** the menu shows only Map, Explore and Top Contributors, plus a Sign in button. Tests in Tasks 2 and 4.
3. **The largest text size (1.2) at exactly 640 and 1000 px:** no overflow. Tests in Tasks 2, 5, 6, 7 and 8.
4. **Dark theme:** the menu stays navy and its text stays readable. Test in Task 2.
5. **Unread count of 0 or more than 9:** the badge is hidden for 0 and shows "9+" above 9. Test in Task 2.

---

### Task 1: Layout toolkit

**Files:**
- Create: `lib/widgets/adaptive_layout.dart`
- Test: `test/adaptive_layout_test.dart`

**Interfaces:**
- Produces:
  - `enum ScreenSize { phone, compact, wide }`
  - `ScreenSize screenSizeFor(double width)`: `< 640` phone, `< 1000` compact, otherwise wide
  - `extension ScreenSizeOf on BuildContext { ScreenSize get screenSize; }`, using `MediaQuery.sizeOf(this).width`
  - `class PageWidth extends StatelessWidget { const PageWidth({required double maxWidth, required Widget child}); }`: centered, never wider than `maxWidth`
  - `class TwoColumns extends StatelessWidget { const TwoColumns({required Widget start, required Widget end, double? startWidth, int startFlex = 1, int endFlex = 1, double gap = 16, double breakAt = 900}); }`: a row when its own width is at least `breakAt`, otherwise `start` stacked above `end`
  - `class CardGrid extends StatelessWidget { const CardGrid({required List<Widget> children, double gap = 12}); }`: 3 columns at 900 px of its own width and up, 2 from 600 px, otherwise 1; rows top-aligned

- [ ] **Step 1: Write failing tests**

| Test | Assertion |
|---|---|
| `screen size thresholds` | 639 is phone, 640 compact, 999 compact, 1000 wide |
| `PageWidth caps the width` | Child width is 760 inside a 1440 px screen with `maxWidth: 760`, and 390 inside a 390 px screen |
| `TwoColumns sits side by side when wide` | At 1200 px, `start` and `end` have the same top, and `end` is to the right of `start` |
| `TwoColumns stacks when narrow` | At 390 px, `end` is below `start` |
| `TwoColumns honours a fixed start width` | `startWidth: 320` gives `start` a width of 320 at 1200 px |
| `CardGrid columns` | 7 children give 3, 2 and 1 per row at 1000, 700 and 390 px (compare child tops) |
| `no overflow at large text` | Each widget at 640 px with text scale 1.2: `tester.takeException()` is null |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/adaptive_layout_test.dart`. Expected: FAIL, file missing.
- [ ] **Step 3: Implement** `lib/widgets/adaptive_layout.dart`. `TwoColumns` and `CardGrid` use `LayoutBuilder`, so they respond to their own width rather than the screen's.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/widgets/adaptive_layout.dart`, `test/adaptive_layout_test.dart`

---

### Task 2: Side menu

**Files:**
- Create: `lib/widgets/side_menu.dart`
- Test: `test/side_menu_test.dart`

**Interfaces:**
- Produces:
  - `class SideMenuItem { const SideMenuItem({required IconData icon, required IconData selectedIcon, required String label, int badge = 0}); }`
  - `class NavAbleSideMenu extends StatelessWidget`: `const NavAbleSideMenu({required List<SideMenuItem> items, required int selectedIndex, required ValueChanged<int> onSelected, required bool extended, required VoidCallback onLeaderboard, String? userName, ImageProvider? userPhoto, VoidCallback? onOpenProfile, VoidCallback? onSignIn})`
  - The logo comes from `lib/img/logOnly.png`, with the text `NavAble` beside it when extended.
  - `Top Contributors` is a separate item under the page items, using `Icons.emoji_events_outlined`.
  - The bottom shows the user's photo and name when `userName` is set (tapping calls `onOpenProfile`), otherwise a `Sign in` button when `onSignIn` is set.

- [ ] **Step 1: Write failing tests**

| Test | Assertion |
|---|---|
| `shows labels when extended` | `extended: true` shows `Explore` and `Top Contributors` as text; the menu is 220 px wide |
| `icons only when compact` | `extended: false`: no `Explore` text, `find.byTooltip('Explore')` finds one, and the menu is 80 px wide |
| `marks the selected page` | The semantics of item 1 include selected; item 0's do not |
| `items are tall enough to tap` | Each item is at least 48 px tall |
| `tapping an item selects it` | Tap `Reports`: `onSelected(2)` |
| `top contributors opens` | Tap it: `onLeaderboard` is called once |
| `unread badge` | `badge: 0` shows no badge text, `badge: 3` shows `3`, `badge: 12` shows `9+` |
| `guest sign in` | With `userName: null` and `onSignIn` set: a `Sign in` button calls `onSignIn` |
| `signed-in user` | With `userName: 'June A.'`: shows `June A.`; tapping calls `onOpenProfile` |
| `stays navy in dark theme` | Under `NavAbleTheme.dark`, the menu's `Material` color is `NavAblePalette.navy`, and label text is white |
| `fits large text` | Height 600, text scale 1.2, extended and compact: no exception |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/side_menu_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `lib/widgets/side_menu.dart`:
  - The item list scrolls if the window is short.
  - The selected item has a background of `NavAblePalette.green` at 18% opacity, with a 3 px green bar on its left edge.
  - Every item is reachable with Tab and activates on Enter or Space.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/widgets/side_menu.dart`, `test/side_menu_test.dart`

---

### Task 3: Alerts filter rules

**Files:**
- Create: `lib/alerts_filter.dart`
- Test: `test/alerts_filter_test.dart`

**Interfaces:**
- Produces:
  - `enum AlertFilter { all, reports, points }`, each with a `label`: `All`, `Reports`, `Points`
  - `bool showsReportCards(AlertFilter filter)`: true for `all` and `reports`
  - `bool alertMatches(AlertFilter filter, String type)`:
    - `all` matches every type;
    - `reports` matches `Report Update`;
    - `points` matches `Points` and `Level Up`.

- [ ] **Step 1: Write failing tests** covering every filter with the types `Report Update`, `Points`, `Level Up`, `System Announcement` and `Accessibility Update`, plus the labels.
- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/alerts_filter_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `lib/alerts_filter.dart`.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/alerts_filter.dart`, `test/alerts_filter_test.dart`

---

### Task 4: Shell that switches menus, and public pages

**Files:**
- Create: `lib/widgets/navable_shell.dart`
- Modify:
  - `lib/home.dart:1700-1788`
  - rename the four page classes, and `_ReportKind` to `ReportKind`, in `lib/screens/explore_tab.dart`, `reports_tab.dart`, `alerts_tab.dart`, `profile_tab.dart`, plus their uses in `lib/home.dart`
- Test: `test/navable_shell_test.dart`

**Interfaces:**
- Consumes: Task 1 `ScreenSize`, Task 2 `NavAbleSideMenu`.
- Produces:
  - `class NavAbleShell extends StatelessWidget`: `const NavAbleShell({required Widget page, required PreferredSizeWidget appBar, required Widget bottomBar, required Widget Function(bool extended) sideMenu, Color? backgroundColor})`
    - phone: a `Scaffold` with `appBar`, `page` and `bottomNavigationBar: bottomBar`;
    - otherwise: a `Scaffold` whose body is a `Row` of `sideMenu(screenSize == ScreenSize.wide)` and the expanded `page`, with no app bar and no bottom bar;
    - `page` is wrapped in a `KeyedSubtree` with a `GlobalKey` held by the shell's caller, so its state survives a layout change.
  - Public page classes: `ExplorePage`, `ReportsPage`, `AlertsPage`, `ProfilePage`, and `enum ReportKind`.

- [ ] **Step 1: Write failing tests**

| Test | Assertion |
|---|---|
| `phone uses the bottom bar` | At 390 px: `bottomBar` and `appBar` are shown, and no `NavAbleSideMenu` |
| `compact uses the icon menu` | At 800 px: `sideMenu(false)` is built; `bottomBar` and `appBar` are absent |
| `wide uses the full menu` | At 1440 px: `sideMenu(true)` is built |
| `typing survives a resize` | A `page` containing a `TextField` keeps `'Ramp at gate 2'` after resizing 390 → 1440 → 800 |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/navable_shell_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** `lib/widgets/navable_shell.dart`.
- [ ] **Step 4: Rename the private page classes** to the public names (mechanical). `flutter analyze` must report no `library_private_types_in_public_api` issues.
- [ ] **Step 5: Use the shell in `_HomeScreenState.build`**
  - Move today's `NavigationBar` `onDestinationSelected` body into `void _selectTab(int index)`, used by both the bar and the menu.
  - Build `SideMenuItem`s from the same destinations, with `badge` set to the count of unread `_alerts` on Alerts.
  - Pass `onLeaderboard: _openLeaderboard`.
  - Pass the current user's name and photo, `onOpenProfile: () => _selectTab(4)`, and for guests `onSignIn`, which opens `LoginScreen` as the app bar does today.
- [ ] **Step 6: Run** `C:\FLUTTE~1\flutter\bin\flutter.bat analyze` and `C:\FLUTTE~1\flutter\bin\flutter.bat test`. Expected: No issues found; All tests passed.
- [ ] **Step 7: Files for the user to commit:** `lib/widgets/navable_shell.dart`, `test/navable_shell_test.dart`, `lib/home.dart`, `lib/screens/explore_tab.dart`, `lib/screens/reports_tab.dart`, `lib/screens/alerts_tab.dart`, `lib/screens/profile_tab.dart`

---

### Task 5: Explore on wide screens

**Files:**
- Modify: `lib/screens/explore_tab.dart:284-460`
- Test: `test/explore_page_test.dart`

**Interfaces:**
- Consumes: `PageWidth`, `CardGrid`, `ScreenSize`.

- [ ] **Step 1: Write failing tests**, pumping `ExplorePage` with 7 sample `AccessibleLocation`s and no-op callbacks.

| Test | Assertion |
|---|---|
| `phone keeps the single list` | At 390 px: every place card has the same left edge, and no `Explore places` heading |
| `PC shows a heading and three columns` | At 1440 px: `Explore places` and `7 places in Cebu City` are shown, and the first three cards share one top |
| `PC caps the width` | At 1920 px, the content is at most 1200 px wide |
| `no overflow at the breakpoints` | At 640 and 1000 px with text scale 1.2: no exception |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/explore_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**
  - When `context.screenSize != ScreenSize.phone`, wrap the list content in `PageWidth(maxWidth: 1200)`, and place the NavAble and Google place cards in `CardGrid`.
  - Show the heading `Explore places` and a summary of the shape `N places in Cebu City`, or `N results` for a Google search.
  - Phones keep today's widgets in today's order.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/screens/explore_tab.dart`, `test/explore_page_test.dart`

---

### Task 6: Reports on wide screens

**Files:**
- Modify: `lib/screens/reports_tab.dart:354-520`
- Test: `test/reports_page_test.dart`

- [ ] **Step 1: Write failing tests**, pumping `ReportsPage` with 7 sample `MyReport`s.

| Test | Assertion |
|---|---|
| `phone keeps one column` | At 390 px: the choice cards stack, and the form's map sits between the fields, as today |
| `PC choices side by side` | At 1440 px, with no kind chosen: `Contribute Accessibility` and `Report an Issue` share one top |
| `PC form in two columns` | At 1440 px, with `initialKind: ReportKind.feature`: the location map is to the right of the `Feature Type` field |
| `PC shows five recent submissions` | At 1440 px in the form: exactly 5 submission rows and a `See all submissions` link, which calls `onOpenContributions` |
| `no overflow at the breakpoints` | At 640 and 1000 px with text scale 1.2: no exception |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/reports_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**
  - Split today's `ListView` children into named groups: fields, photos and scan, location map, submissions.
  - Phones keep today's order.
  - Wide windows use `PageWidth(maxWidth: 1200)` and `TwoColumns(startFlex: 5, endFlex: 4)`: fields, photos and scan on the left; the map, then up to 5 recent submissions and the link, on the right.
  - The choice step uses `TwoColumns(breakAt: 640)`.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/screens/reports_tab.dart`, `test/reports_page_test.dart`

---

### Task 7: Alerts filters and width

**Files:**
- Modify: `lib/screens/alerts_tab.dart`
- Test: `test/alerts_page_test.dart`

**Interfaces:**
- Consumes: `AlertFilter`, `showsReportCards` and `alertMatches` (Task 3); `PageWidth`.

- [ ] **Step 1: Write failing tests**, pumping `AlertsPage` with 2 `MyReport`s and alerts of types `Points`, `Level Up` and `System Announcement`.

| Test | Assertion |
|---|---|
| `filters on every size` | At 390 px: `All`, `Reports` and `Points` chips are shown |
| `All shows everything` | 5 alert cards |
| `Reports filter` | Tap `Reports`: the 2 report cards only |
| `Points filter` | Tap `Points`: the `Points` and `Level Up` alerts only |
| `empty filter message` | With no reports, the `Reports` filter shows `Nothing here yet.` |
| `PC caps the width` | At 1440 px, the list is at most 760 px wide and centered |
| `no overflow at the breakpoints` | At 640 and 1000 px with text scale 1.2: no exception |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/alerts_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** `AlertsPage` becomes a `StatefulWidget` holding the selected `AlertFilter` (default `all`). The chips go between the subtitle and the list. On wide windows, the content goes in `PageWidth(maxWidth: 760)`.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/screens/alerts_tab.dart`, `test/alerts_page_test.dart`

---

### Task 8: Profile on wide screens

**Files:**
- Modify: `lib/screens/profile_tab.dart:89-290`
- Test: `test/profile_page_test.dart`

- [ ] **Step 1: Write failing tests**, pumping `ProfilePage` with a sample user and stats. If `ProfilePage` reads Supabase while building, inject that data through its constructor first.

| Test | Assertion |
|---|---|
| `phone keeps one column` | At 390 px: `Edit Profile` is above `Accessibility Settings` with the same left edge |
| `PC two columns` | At 1440 px: the profile card is 320 px wide, and `Accessibility Settings` is to its right |
| `PC caps the width` | At 1920 px, the content is at most 1100 px wide |
| `no overflow at the breakpoints` | At 640 and 1000 px with text scale 1.2: no exception |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/profile_page_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement**
  - Wide windows use `PageWidth(maxWidth: 1100)` and `TwoColumns(startWidth: 320)`.
  - The left column holds the photo, name, level and progress, the stats and Edit Profile.
  - The right column holds the points section, then the settings links and Sign Out.
  - Phones keep today's order.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/screens/profile_tab.dart`, `test/profile_page_test.dart`

---

### Task 9: Full check, web build and visual check

- [ ] **Step 1: Run** `C:\FLUTTE~1\flutter\bin\flutter.bat analyze` and `C:\FLUTTE~1\flutter\bin\flutter.bat test`. Expected: No issues found; All tests passed.
- [ ] **Step 2: Build the website.** Run `C:\FLUTTE~1\flutter\bin\flutter.bat build web --release --dart-define-from-file=dart_defines.json`, copy `build\web` over `C:\NavAble-deploy\navable-app`, then run the zip script. Expected: `with backslashes: 0`.
- [ ] **Step 3: Check it in the browser.** Serve `build\web` with the `navable-web` preview. As a guest, take screenshots of Map and Explore at 390, 800 and 1440 px. Expected:
  - 390 px: the bottom bar.
  - 800 px: the icon menu.
  - 1440 px: the menu with labels and Explore in 3 columns.
  - No layout errors in the console.
- [ ] **Step 4: Hand over.** List every changed file for the user to commit, and ask them to upload the zip through **Create deployment**. Reports, Alerts and Profile need a signed-in test account, so the user checks those on a PC and a phone.
