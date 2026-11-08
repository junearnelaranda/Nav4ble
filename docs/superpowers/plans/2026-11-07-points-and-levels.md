# Contributor Points and Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the database side and the phone-app side of NavAble's contributor points, levels, leaderboard, alerts and level-up celebration.

**Architecture:** One Supabase migration adds point presets, level thresholds, the Custom tier, leaderboard/standing functions, admin-only update functions and an alert trigger. The Flutter app gets a pure level-math file, a `PointsApi` that calls those functions, and new UI on Profile, a Top Contributors page, the top bar, the Alerts tab and a level-up screen. The admin web app is out of scope (June builds it from spec section 5).

**Tech Stack:** Supabase Postgres (SQL migration, RLS, SECURITY DEFINER functions), Flutter 3.44 / Dart 3.12, `supabase_flutter`, `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-11-07-points-and-levels-design.md`

## Global Constraints

- Points never involve money; no spending, wallet or redemption anywhere.
- Levels: Newcomer (level 0) below 30; Explorer 1 at 30; Bronze 2 at 100; Silver 3 at 300; Gold 4 at 750; Platinum 5 at 1500.
- Preset seeds: Small 5, Regular 10, Big 25. Custom points 1–1000.
- "This month" = awards with `created_at >= date_trunc('month', now() at time zone 'Asia/Manila')` (converted back to timestamptz).
- Leaderboard ranks only `users.role = 'User'` and `users.account_status = 'Active'`; full name = `user_profiles.first_name || ' ' || last_name`, trimmed.
- The migration is applied to project `bipsoacordrbcekzsdlr` only after June says yes to it. Database checks run in transactions that end in `rollback`.
- Do not commit unless June asks. Leave changes in the working tree.
- Flutter commands use the SDK junction: `F="$TEMP/claude/C--Flutter-Workspace-navable/f204b5dd-d689-4470-86d8-09b18098f78e/scratchpad/fsdk/bin"` then `"$F/flutter.bat" …` / `"$F/dart.bat" …`. Run unit tests as `"$F/flutter.bat" test $(ls test/*_test.dart | grep -v widget_test)` (the old widget tests need Supabase and already fail).
- UI copy is exact as written in spec section 6 (for example "Rewards aren't available yet. Keep contributing. Your points will count when they launch.").
- Respect "remove animations" (`MediaQuery.disableAnimations`) for every new animation.

## Review Focus

1. A user with exactly a threshold (30, 100 … 1500) or exactly 0 points: shows the right level and progress, never "Level 0", never a divide-by-zero bar. Tests in Task 2.
2. A month with no awards at all, or a signed-in user with no points: the leaderboard shows the empty state, the pinned row is hidden, nothing crashes on null rank. Tests in Task 3.
3. An admin lowers then raises thresholds while a user is mid-level: the celebration must not replay for a level already celebrated, and a drop in level must not celebrate. Tests in Task 7.
4. A report or review whose location was deleted: the alert trigger must still insert (place name falls back to "a place"), or the award insert would fail. Check in Task 1.
5. Two users with equal points: ranks are stable (earlier `last_awarded_at` wins), not random between refreshes. Check in Task 1.

---

## File Structure

| File | Responsibility |
|---|---|
| `supabase/migrations/20261107120000_points_and_levels.sql` (create) | All database changes from spec section 4.2 |
| `lib/points/levels.dart` (create) | Pure level math and level/badge models; no I/O |
| `lib/points/points_api.dart` (create) | Supabase calls and row parsing for standing, leaderboard, history, levels, alerts |
| `lib/points/celebration_store.dart` (create) | Per-account "last celebrated level" on the device |
| `lib/screens/points_section.dart` (create, `part of '../home.dart'`) | Profile points card, history, pending, rewards card |
| `lib/screens/leaderboard_screen.dart` (create, part) | Top Contributors page |
| `lib/screens/level_up_screen.dart` (create, part) | Full-screen celebration |
| `lib/screens/profile_tab.dart` (modify) | Swap hardcoded text and points card for the new section |
| `lib/screens/alerts_tab.dart` (modify) | Show database alerts next to report updates |
| `lib/home.dart` (modify) | Load points/alerts, trophy button, celebration check, part lines |
| `lib/profile_stats_api.dart` (modify) | Stop reading the missing `profiles` table |
| `test/levels_test.dart`, `test/points_api_test.dart`, `test/celebration_store_test.dart` (create) | Unit tests |

---

### Task 1: Database migration

**Files:**
- Create: `supabase/migrations/20261107120000_points_and_levels.sql`

**Interfaces:**
- Produces (SQL, all in `public`):
  - table `point_presets(tier text pk check in ('Small','Regular','Big'), points int not null check 1..1000, updated_at timestamptz default now(), updated_by uuid references users(user_id))`, seeded 5/10/25.
  - table `contributor_levels(level int pk check 1..5, name text unique not null, min_points int not null check >= 1, updated_at, updated_by)`, seeded Explorer 30, Bronze 100, Silver 300, Gold 750, Platinum 1500.
  - `contribution_points_tier_check` allows `'Custom'`.
  - `level_for_points(points int) returns table(level int, name text)` — level 0 / `'Newcomer'` below the lowest threshold. `stable`, `security definer`, `set search_path = ''`.
  - `set_point_presets(small int, regular int, big int) returns void` — raises `'Only admins can change point values.'` unless `is_admin()`; raises `'Point values must be 1 to 1,000.'`.
  - `set_level_thresholds(thresholds int[]) returns void` — admin only; exactly 5 values, first ≥ 1, strictly increasing, else raises `'Levels need 5 values, each higher than the one before.'`.
  - `preview_level_changes(thresholds int[]) returns table(user_id uuid, full_name text, total_points int, current_level text, new_level text)` — admin only; rows only where the new level number is lower.
  - `get_leaderboard(period text, max_rows int default 20) returns table(rank int, user_id uuid, full_name text, profile_picture text, points int, level int, level_name text)` — `period` `'month'` or `'all'`, else raises; level from lifetime total; order `points desc, last_awarded_at asc`; granted to `anon, authenticated`.
  - `get_my_standing(period text) returns table(rank int, points int, level int, level_name text, next_level_name text, next_level_min_points int)` — for `auth.uid()`; `rank` null when no points in period; granted to `authenticated`.
  - notification types extended with `'Points'`, `'Level Up'`; trigger `award_points_notify` after insert on `contribution_points` inserting the alerts from spec 4.2 item 8 (place name from `locations.location_name` via the report or review; `'a place'` when missing).
  - policies: `point_presets` and `contributor_levels` select for `anon, authenticated`; `notifications` `users_read_own` (select own) and `users_mark_own_read` (update own, with check own). Column grant: `revoke update on notifications from authenticated; grant update (is_read) on notifications to authenticated`.

- [ ] **Step 1: Write the migration file** with the objects above, in this order: tier check, tables + seeds + RLS, functions (revoke from public, grant as listed), notification type check, trigger function + trigger, notification policies and column grant.

- [ ] **Step 2: Ask June to approve applying it.** Show the file path and a one-paragraph summary. Stop until June says yes.

- [ ] **Step 3: Apply** with the Supabase `apply_migration` tool, name `points_and_levels`.

- [ ] **Step 4: Verify in rolled-back transactions** (`execute_sql`, each block `begin; … rollback;`, impersonating with `set_config('request.jwt.claims', …)` and `set local role authenticated`). Expected results:
  - As a regular user: `select set_point_presets(6,10,25)` errors "Only admins…"; `insert into contribution_points …` errors (RLS).
  - As admin: `select set_level_thresholds(array[30,100,100,750,1500])` errors "Levels need 5 values…".
  - As admin: insert a 10-point award for a test report whose user has 25 points → that user gets one `'Points'` row and one `'Level Up'` row titled "You're now Explorer".
  - Same insert with the report's location deleted → still succeeds, message contains "a place".
  - An award with `created_at` set to last month: counted by `get_leaderboard('all')`, not by `get_leaderboard('month')`.
  - Two users with equal points: the one with the earlier `last_awarded_at` has the lower rank number.
  - Admin rows are absent from `get_leaderboard('all', 100)`.
  - As user A: `select count(*) from notifications where user_id <> auth.uid()` = 0; `update notifications set title = 'x'` errors (column grant); `update notifications set is_read = true where user_id = auth.uid()` succeeds.

- [ ] **Step 5: Run the Supabase security advisors** (`get_advisors`, type `security`) and confirm no new warnings for the new tables or functions.

---

### Task 2: Level math

**Files:**
- Create: `lib/points/levels.dart`
- Test: `test/levels_test.dart`

**Interfaces:**
- Produces:
  - `class ContributorLevel { final int level; final String name; final int minPoints; }` with `static const defaults` = the five seeded levels, and `factory ContributorLevel.fromRow(Map<String, dynamic> row)` (`level`, `name`, `min_points`).
  - `class LevelProgress { final int points; final int level; final String name; final ContributorLevel? next; final int pointsToNext; final double fraction; bool get isTop; }`
  - `LevelProgress progressFor(int points, List<ContributorLevel> levels)` — level 0 / "Newcomer" below the first threshold; `fraction` is progress from the current level's threshold (0 for Newcomer) to the next, clamped 0..1; at the top level `next == null`, `pointsToNext == 0`, `fraction == 1`. Sorts `levels` by `minPoints` itself.
  - `enum LevelBadge { newcomer, explorer, bronze, silver, gold, platinum }` and `LevelBadge badgeFor(int level)`, used by UI for colors.

- [ ] **Step 1: Write the failing tests** in `test/levels_test.dart`:

```dart
final levels = ContributorLevel.defaults;
test('newcomer below 30', () {
  final p = progressFor(0, levels);
  expect([p.level, p.name, p.next!.name, p.pointsToNext], [0, 'Newcomer', 'Explorer', 30]);
  expect(p.fraction, 0);
  expect(progressFor(29, levels).level, 0);
});
test('exact thresholds reach the level', () {
  expect([30, 100, 300, 750, 1500].map((v) => progressFor(v, levels).name),
      ['Explorer', 'Bronze', 'Silver', 'Gold', 'Platinum']);
});
test('progress between levels', () {
  final p = progressFor(420, levels);
  expect([p.level, p.name, p.next!.name, p.pointsToNext], [3, 'Silver', 'Gold', 330]);
  expect(p.fraction, closeTo(120 / 450, 1e-9));
});
test('top level', () {
  final p = progressFor(5000, levels);
  expect([p.isTop, p.next, p.pointsToNext, p.fraction], [true, null, 0, 1.0]);
});
test('unsorted or edited thresholds', () {
  final edited = [...levels.reversed, ]
      .map((l) => l.level == 4 ? ContributorLevel(level: 4, name: 'Gold', minPoints: 1000) : l)
      .toList();
  expect(progressFor(800, edited).name, 'Silver');
});
```

- [ ] **Step 2: Run** `"$F/flutter.bat" test test/levels_test.dart` — expected FAIL (missing file).

- [ ] **Step 3: Implement** `lib/points/levels.dart` with the interfaces above.

- [ ] **Step 4: Run** the same command — expected PASS.

---

### Task 3: Points API

**Files:**
- Create: `lib/points/points_api.dart`
- Modify: `lib/profile_stats_api.dart` (delete the `profiles` lookup; `contributionPoints` is filled from `PointsApi.myStanding` by the caller instead)
- Test: `test/points_api_test.dart`

**Interfaces:**
- Consumes: `ContributorLevel`, `progressFor` (Task 2).
- Produces:
  - `enum LeaderboardPeriod { month, all }` (`wire` getter → `'month'` / `'all'`).
  - `class LeaderboardEntry { rank, userId, fullName, Uint8List? picture, points, level, levelName }` with `static LeaderboardEntry? fromRow(Map row)` (null when `rank` or `user_id` missing; picture via `ProfilePicture.decode`).
  - `class MyStanding { int? rank; int points; LevelProgress progress; }`
  - `class PointsAward { int points; String tier; String sourceType; String placeName; DateTime createdAt; }` with `static PointsAward? fromRow(Map row)`; place name from the nested `reports(locations(location_name))` or `reviews(locations(location_name))`, `'a place'` when absent.
  - `class PendingContribution { String kind; String placeName; DateTime createdAt; }`
  - `class AppAlert { String id; String title; String message; String type; bool isRead; DateTime createdAt; }` with `fromRow`.
  - `abstract final class PointsApi` with static methods:
    - `Future<List<ContributorLevel>> levels()` — falls back to `ContributorLevel.defaults` on error.
    - `Future<List<LeaderboardEntry>> leaderboard(LeaderboardPeriod period, {int maxRows = 20})`
    - `Future<MyStanding?> myStanding(LeaderboardPeriod period)` — null for guests.
    - `Future<List<PointsAward>> myAwards()` — newest first.
    - `Future<List<PendingContribution>> myPending()` — own reports with `status = 'Pending'` and own reviews with pending `review_status` (check the live value with a read-only query first and use it), each with no award.
    - `Future<List<AppAlert>> myAlerts()` and `Future<void> markAlertsRead()`.
  - Errors surface as `PointsApiException(String message)`.

- [ ] **Step 1: Write failing parsing tests** (pure, no network):

```dart
test('leaderboard row', () {
  final e = LeaderboardEntry.fromRow({'rank': 1, 'user_id': 'u1', 'full_name': 'Maria Reyes',
      'profile_picture': null, 'points': 320, 'level': 3, 'level_name': 'Silver'})!;
  expect([e.rank, e.fullName, e.points, e.levelName, e.picture], [1, 'Maria Reyes', 320, 'Silver', null]);
  expect(LeaderboardEntry.fromRow({'full_name': 'x'}), isNull);
});
test('award row takes the place from a report or a review', () {
  final r = PointsAward.fromRow({'points': 10, 'tier': 'Regular', 'source_type': 'Report',
      'created_at': '2026-11-07T03:00:00Z', 'reports': {'locations': {'location_name': 'Ayala Center Cebu'}}})!;
  expect([r.points, r.placeName], [10, 'Ayala Center Cebu']);
  final v = PointsAward.fromRow({'points': 25, 'tier': 'Big', 'source_type': 'Review',
      'created_at': '2026-11-07T03:00:00Z', 'reviews': null})!;
  expect(v.placeName, 'a place');
});
test('alert row', () {
  final a = AppAlert.fromRow({'notification_id': 'n1', 'title': '+10 points', 'message': 'For your report at X',
      'notification_type': 'Points', 'is_read': false, 'created_at': '2026-11-07T03:00:00Z'})!;
  expect([a.type, a.isRead], ['Points', false]);
});
test('period wire values', () {
  expect(LeaderboardPeriod.values.map((p) => p.wire), ['month', 'all']);
});
```

- [ ] **Step 2: Run** `"$F/flutter.bat" test test/points_api_test.dart` — expected FAIL.

- [ ] **Step 3: Implement** `lib/points/points_api.dart` (RPC names exactly as Task 1; `myAwards` selects `points, tier, source_type, created_at, reports(locations(location_name)), reviews(locations(location_name))`) and trim `ProfileStatsApi`.

- [ ] **Step 4: Run** the test and `"$F/dart.bat" analyze lib test` — expected PASS, "No issues found!".

---

### Task 4: Profile points section

**Files:**
- Create: `lib/screens/points_section.dart` (`part of '../home.dart'`)
- Modify: `lib/screens/profile_tab.dart` (remove the "NavAble Gold Member • Verified Contributor" text and the "ACCESSIBILITY CONTRIBUTIONS" card; insert `_PointsSection`), `lib/home.dart` (add the part line; load standing, awards, pending in `_loadProfileStats`; pass them and `onOpenLeaderboard`)

**Interfaces:**
- Consumes: `MyStanding`, `PointsAward`, `PendingContribution`, `PointsApi` (Task 3), `badgeFor` (Task 2).
- Produces: `_PointsSection({required bool isGuest, required bool loading, MyStanding? standing, List<PointsAward> awards, List<PendingContribution> pending, required VoidCallback onOpenLeaderboard, required VoidCallback onSignIn})` and `_LevelBadge({required int level, required String name, double size})` (reused by Tasks 5 and 7). Badge colors: newcomer grey, explorer teal, bronze copper, silver grey-blue, gold amber, platinum violet; text always shows the name.

- [ ] **Step 1: Build `_PointsSection`** per spec 6.2 and 6.7: guests see "Sign in to earn points" with a Sign in button; signed-in users see badge + "Level 3 · Silver" ("No level yet" for Newcomer), points, `LinearProgressIndicator(value: progress.fraction)`, "420 / 750 to Gold" ("Top level reached" at Platinum), up to 10 history rows "+10 · Regular · Report at Ayala Center Cebu · Nov 7", pending rows "Pending review", the rewards card with the exact copy, and a "Top Contributors" button. Loading shows the existing `'...'` style; a load error shows "Points unavailable right now".

- [ ] **Step 2: Wire it** in `profile_tab.dart` and `home.dart`.

- [ ] **Step 3: Verify** `"$F/dart.bat" analyze lib test` → "No issues found!", and render a throwaway preview (copy the pattern in the session scratchpad `zz_splash_preview_test.dart`: Roboto from the SDK's `material_fonts`, `RepaintBoundary.toImage`) of `_PointsSection` with sample data for 0, 420 and 5000 points, light and dark. Look at the PNGs: no overflow stripes, text readable in both modes. Delete the throwaway test from `test/` afterwards.

---

### Task 5: Top Contributors page and trophy button

**Files:**
- Create: `lib/screens/leaderboard_screen.dart` (part)
- Modify: `lib/home.dart` (part line; trophy `IconButton(tooltip: 'Top contributors', icon: Icon(Icons.emoji_events_outlined))` in the app bar before the profile avatar, shown for guests too; `_openLeaderboard()` pushes the page)

**Interfaces:**
- Consumes: `PointsApi.leaderboard`, `PointsApi.myStanding`, `LeaderboardEntry`, `_LevelBadge`.
- Produces: `_LeaderboardScreen({required bool isGuest})`.

- [ ] **Step 1: Build the page** per spec 6.3: `SegmentedButton` with This month / All-time; rows with rank (gold, silver, bronze medal icons for 1–3), avatar (picture or initials), full name, `_LevelBadge`, points; pinned own row "You · #47 · Bronze · 120 pts" hidden for guests and when `rank == null`; empty state "No contributions yet this month. Be the first!" (All-time: "No contributions yet. Be the first!"); `RefreshIndicator`; error state "Couldn't load the leaderboard" with Retry.

- [ ] **Step 2: Verify** analyze clean, then a throwaway preview of the page with three sample entries, with an empty list, and with a guest, by injecting data through a `@visibleForTesting` constructor parameter `initial` (a `({List<LeaderboardEntry> entries, MyStanding? me})` record) so no network is needed. Check the PNGs, then delete the throwaway test.

---

### Task 6: Alerts from the database

**Files:**
- Modify: `lib/screens/alerts_tab.dart`, `lib/home.dart`

**Interfaces:**
- Consumes: `AppAlert`, `PointsApi.myAlerts`, `PointsApi.markAlertsRead`.
- Produces: `_AlertsPage` gains `List<AppAlert> alerts` and keeps `reports`.

- [ ] **Step 1: Load alerts** in `home.dart` on start and on resume (reuse `didChangeAppLifecycleState`), skip for guests; when the Alerts tab is selected, call `markAlertsRead()` and refresh.

- [ ] **Step 2: Show them** in `_AlertsPage`, merged with report updates newest first: `Points` → `Icons.stars_rounded`, `Level Up` → `Icons.military_tech_rounded`, other types → the existing info icon. Unread alerts show a small green dot. The empty state stays "No alerts yet" only when both lists are empty.

- [ ] **Step 3: Verify** analyze clean and all unit tests pass.

---

### Task 7: Level-up celebration

**Files:**
- Create: `lib/points/celebration_store.dart`, `lib/screens/level_up_screen.dart` (part)
- Modify: `lib/home.dart`
- Test: `test/celebration_store_test.dart`

**Interfaces:**
- Consumes: `myStanding` (Task 3), `_LevelBadge` (Task 4).
- Produces:
  - `abstract final class CelebrationStore { static Future<int?> lastCelebrated(String userId); static Future<void> setLastCelebrated(String userId, int level); }` (key `celebrated_level.<userId>`, `SharedPreferences`).
  - `int? levelToCelebrate({required int? lastCelebrated, required int currentLevel})` — returns `currentLevel` only when `lastCelebrated != null && currentLevel > lastCelebrated`; otherwise null.
  - `_LevelUpScreen({required int level, required String name})` — badge pops in (`easeOutBack`), green confetti (simple `CustomPainter`, about 40 pieces, 1.4 s), "You're now Silver", "Level 3", "Thanks for making Cebu more accessible.", Continue button pops.

- [ ] **Step 1: Write failing tests:**

```dart
test('first run never celebrates', () => expect(levelToCelebrate(lastCelebrated: null, currentLevel: 3), isNull));
test('celebrates a higher level once', () => expect(levelToCelebrate(lastCelebrated: 2, currentLevel: 3), 3));
test('same or lower level does not celebrate', () {
  expect(levelToCelebrate(lastCelebrated: 3, currentLevel: 3), isNull);
  expect(levelToCelebrate(lastCelebrated: 4, currentLevel: 3), isNull);
});
test('store is per account', () async {
  SharedPreferences.setMockInitialValues({});
  await CelebrationStore.setLastCelebrated('a', 2);
  expect(await CelebrationStore.lastCelebrated('a'), 2);
  expect(await CelebrationStore.lastCelebrated('b'), isNull);
});
```

- [ ] **Step 2: Run** `"$F/flutter.bat" test test/celebration_store_test.dart` — expected FAIL.

- [ ] **Step 3: Implement** the store and `levelToCelebrate`; in `home.dart`, after standing loads (start and resume, signed-in only): read `lastCelebrated`; if null, store the current level silently; if `levelToCelebrate` returns a level, push `_LevelUpScreen` and then store it. When the level dropped below `lastCelebrated`, store the lower level so a later climb celebrates again.

- [ ] **Step 4: Run** the tests — expected PASS. Render a throwaway frame strip of `_LevelUpScreen` (0 ms, 400 ms, 1200 ms) and check it, then delete the throwaway test.

---

### Task 8: Final verification

- [ ] **Step 1:** `"$F/dart.bat" format lib test`, `"$F/dart.bat" analyze lib test` → "No issues found!".
- [ ] **Step 2:** All unit tests → "All tests passed!".
- [ ] **Step 3:** `"$F/flutter.bat" build apk --debug --dart-define-from-file=dart_defines.json` → "Built build\app\outputs\flutter-apk\app-debug.apk".
- [ ] **Step 4:** Tell June what to try on the phone together with the admin app: award points to a test user, then check the Points alert, the Profile progress, the leaderboard and the celebration after crossing a threshold.
