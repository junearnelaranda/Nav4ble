# Contributor points and levels: design

Date: 2026-11-07
Status: draft, waiting for review

## 1. Goal

Make contributing to NavAble feel like a game. Contributors earn points when an
admin approves their contribution, points raise their level, and a Top
Contributors page shows who helps the most. Real rewards from partner places may
come later; this design leaves room for them without building them.

### In scope

- Points awarded by admins, using three preset boxes (Small, Regular, Big) and
  one Custom box.
- Admin-editable point box values and level thresholds.
- Levels: Newcomer (no level), Explorer, Bronze, Silver, Gold, Platinum.
- Top Contributors page with This month and All-time rankings.
- An alert for every award, and a one-time celebration on reaching a new level.
- A "Rewards — coming soon" notice.

### Out of scope

- Money of any kind. Points can't be spent, traded or redeemed, and they never
  go down except when an admin removes an award.
- A rewards catalogue, wallet or redemption flow. That gets its own design if
  partners sign on.
- Automatic points (for example for submitting a report or for an AI
  detection). Every point comes from an admin.

## 2. Decisions

| Topic | Decision |
|---|---|
| What points are | Reputation for fun. Lifetime total only, no spending. |
| How points are earned | Admin approval only, one award per report or review (already enforced). |
| Award options | Preset boxes Small, Regular and Big (values editable anytime) plus one Custom amount (1–1,000). |
| Past awards | Keep the points they were given. Changing a box's value affects new awards only. |
| Levels | Newcomer below 30; Explorer (1) 30; Bronze (2) 100; Silver (3) 300; Gold (4) 750; Platinum (5) 1,500. |
| Level changes | Thresholds editable in the admin app, with a warning when people would move down. Names fixed. |
| Leaderboard names | Full name, profile picture and level badge. |
| Leaderboard periods | This month (Philippine time) and All-time tabs. Top 20, plus your own rank. |
| Who is ranked | Active accounts with the User role. Admins and deactivated accounts are left out. |
| Where it lives | Profile page, plus a trophy button in the top bar. |
| Feedback | Alert for every award, plus a full-screen celebration once per new level. |
| Rewards | "Coming soon" card with a clear notice that rewards aren't available yet. |
| Who builds what | Database and phone app: Claude. Admin web app: June (section 5). |

## 3. Architecture

The database is the single source of truth. Point box values, level thresholds,
level math, rankings and alerts all live there, so the phone app and the admin
app always agree and nobody has to remember to send an alert.

```
Admin web app ──awards──▶ contribution_points ──trigger──▶ notifications
      │                          │                              │
      ├─edits─▶ point_presets    │                              ▼
      └─edits─▶ contributor_levels                     Phone app Alerts tab
                                 │
                 get_leaderboard / get_my_standing ──▶ Phone app Profile,
                                                       Top Contributors
```

Users never read other users' rows directly. The leaderboard functions run with
elevated rights and return only rank, name, picture, points and level.

## 4. Database

One migration, applied only after June approves it.

### 4.1 Already in place (no change)

- `contribution_points`: `point_id, user_id, points (1–1000), tier, source_type
  ('Report' | 'Review'), report_id, review_id, awarded_by, created_at`.
- One award per report and per review: unique indexes
  `contribution_points_report_once` and `contribution_points_review_once`.
- Users can read their own awards: policy `points_select_own`.
- `user_point_totals` view: `user_id, total_points, awards, last_awarded_at`.

### 4.2 Changes

1. **Custom tier.** Replace `contribution_points_tier_check` so `tier` allows
   `'Small' | 'Regular' | 'Big' | 'Custom'`.

2. **`point_presets` table**, one row per box:

   | Column | Type | Notes |
   |---|---|---|
   | `tier` | text, primary key | `'Small' | 'Regular' | 'Big'` |
   | `points` | int | 1–1,000 |
   | `updated_at` | timestamptz | default `now()` |
   | `updated_by` | uuid | references `users(user_id)` |

   Seeded with Small 5, Regular 10, Big 25.

3. **`contributor_levels` table**, one row per level:

   | Column | Type | Notes |
   |---|---|---|
   | `level` | int, primary key | 1–5 |
   | `name` | text, unique | Explorer, Bronze, Silver, Gold, Platinum |
   | `min_points` | int | at least 1 |
   | `updated_at` | timestamptz | default `now()` |
   | `updated_by` | uuid | references `users(user_id)` |

   Seeded 30, 100, 300, 750, 1,500. Newcomer is "below level 1" and isn't stored.

4. **Admin-only update functions.** Both check `is_admin()`, validate, and save
   in one step, so the table never holds a half-edited state:
   - `set_point_presets(small int, regular int, big int)`: each 1–1,000.
   - `set_level_thresholds(thresholds int[])`: exactly 5 values, each greater
     than the one before, the first at least 1.
   - `preview_level_changes(thresholds int[])`: returns the contributors whose
     level would go **down** (`user_id, full_name, total_points, current_level,
     new_level`), for the admin warning. Changes nothing.

5. **Level math**: `level_for_points(points int)` returns `level` (0 for
   Newcomer) and `name` from `contributor_levels`. Used by the functions below
   and the alert trigger.

6. **`get_leaderboard(period text, max_rows int default 20)`**:
   `period` is `'month'` or `'all'`. "This month" counts awards with
   `created_at` on or after the first day of the current month in
   `Asia/Manila` time. Returns `rank, user_id, full_name, profile_picture,
   points, level, level_name`, highest points first; a tie goes to whoever
   reached the total first. Ranks only active accounts with the `User` role.
   Callable by guests and signed-in users.

7. **`get_my_standing(period text)`**: for the signed-in user, returns
   `rank` (null with no points in that period), `points`, `level`,
   `level_name`, `next_level_name`, `next_level_min_points` (both null at
   Platinum). Lifetime points decide the level in both periods; `period` only
   changes `rank` and `points`.

8. **Alerts.**
   - Extend `notifications_notification_type_check` with `'Points'` and
     `'Level Up'`.
   - Trigger after insert on `contribution_points`:
     - adds a `'Points'` alert: title "+10 points", message
       "For your report at Ayala Center Cebu" (or "your review at …"; the place
       name comes from the report's or review's location);
     - if the user's lifetime total crosses a level threshold, also adds a
       `'Level Up'` alert: title "You're now Silver", message "Level 3".
   - Removing an award creates no alert.

9. **Access rules.**
   - `point_presets`, `contributor_levels`: readable by everyone (guests
     included); changed only through the admin functions.
   - `notifications`: new policies let users read their own alerts and mark
     their own alerts read (`is_read` only). Admins keep full access.
   - The leaderboard and standing functions run with elevated rights and
     return only the columns listed above.

## 5. Admin web app (June's part)

Everything the admin pages need, read from or written to the database above.
The database also enforces the important rules, so a missed check in the UI
can't save bad data.

### 5.1 Award panel (Reports and Ratings detail views)

- [ ] Load the boxes: `select tier, points from point_presets` and show
      "Small · +5", "Regular · +10", "Big · +25".
- [ ] Clicking a box inserts into `contribution_points`:
      `{ user_id, points, tier, source_type, report_id | review_id }`.
      `awarded_by` is the signed-in admin (as today).
- [ ] Custom box: a number field (1–1,000) and an Award button; insert with
      `tier: 'Custom'` and the typed `points`. Show "Enter 1–1,000 points" for
      anything else.
- [ ] One award per contribution is enforced by the database. When an award
      exists, show it ("+10 points · Regular") with Remove, as today.
- [ ] Nothing extra for alerts: the database sends them.

### 5.2 New page: Points & Levels

- [ ] **Point boxes card.** Three number fields loaded from `point_presets`.
      Save calls `rpc('set_point_presets', { small, regular, big })`. Note under
      the card: "Applies to new awards only. Past awards keep their points."
- [ ] **Levels card.** Five rows (name fixed, points editable) loaded from
      `contributor_levels` ordered by `level`.
- [ ] Before saving levels, call
      `rpc('preview_level_changes', { thresholds: [..5 numbers..] })`. If it
      returns rows, show a warning such as "This moves 3 contributors down a
      level (Gold → Silver). Save anyway?" and list them.
- [ ] Save calls `rpc('set_level_thresholds', { thresholds: [...] })`. Show the
      database's message if it refuses (for example, numbers not increasing).

### 5.3 Users page

- [ ] Next to each user's total (already loaded from `user_point_totals`), show
      their level. Either compute it from the `contributor_levels` rows
      (highest level whose `min_points` ≤ total, otherwise Newcomer) or call
      `rpc('level_for_points', { points })`.
- [ ] The user detail view keeps its current points history.

### 5.4 Dashboard (optional)

- [ ] "Top contributors this month" card:
      `rpc('get_leaderboard', { period: 'month', max_rows: 5 })`.

## 6. Phone app (Claude's part)

### 6.1 Data

- New `lib/points_api.dart`: loads standing, leaderboard, own points history
  (`contribution_points` with the report's or review's place name) and the
  level list; holds the level math as plain functions (level for points,
  progress to next level) so it can be unit tested.
- `ProfileStatsApi` stops reading the non-existent `profiles` table.

### 6.2 Profile page

Replaces the hardcoded "NavAble Gold Member • Verified Contributor" text with:

- level badge and "Level 3 · Silver" (Newcomer shows "No level yet");
- total points and a progress bar: "420 / 750 to Gold" ("Top level reached" at
  Platinum);
- points history: "+10 · Regular · Report at Ayala Center Cebu · Nov 7";
- "Pending review" for the user's reports and reviews that have no award yet
  and are still waiting for an admin (report or review status still pending).
  Rejected ones show nothing, so nothing stays "pending" forever;
- "Rewards — coming soon" card: "Rewards aren't available yet. Keep
  contributing. Your points will count when they launch.";
- a Top Contributors button.

Level badge colors: Explorer teal, Bronze copper, Silver grey, Gold amber,
Platinum violet. Each badge also shows its name, so color is never the only cue.

### 6.3 Top Contributors page

- This month / All-time tabs.
- Top 20 rows: rank (gold, silver and bronze medals for the top three), profile
  picture or initials, full name, level badge, points.
- The user's own row pinned at the bottom ("You · #47 · Bronze · 120 pts"),
  hidden for guests.
- Empty state: "No contributions yet this month. Be the first!"
- Pull down to refresh.

### 6.4 Top bar

- Trophy button next to the profile picture, opening Top Contributors. Shown
  for guests too.

### 6.5 Alerts tab

- Loads the user's alerts from `notifications`, newest first, alongside the
  existing report updates. "Points" alerts get a star icon, "Level Up" alerts
  a medal icon.
- Opening the tab marks them read.

### 6.6 Level-up celebration

- When the app starts or returns to the foreground, it compares the user's
  current level with the last celebrated level stored on the device for that
  account.
- If the level went up, a full-screen moment plays once: the new badge pops in
  with green confetti, "You're now Silver · Level 3", and a Continue button.
  Then the stored level updates.
- First run for an account stores the current level without celebrating, so
  existing contributors don't get a surprise celebration.
- With "remove animations" on, the screen shows without confetti or motion.

### 6.7 Guests

- See the leaderboard and the trophy button.
- Profile shows "Sign in to earn points" instead of points and level.

## 7. Error handling

- Offline or a failed load: Profile shows the last loaded values or "Points
  unavailable right now", and the leaderboard shows "Couldn't load the
  leaderboard" with a Retry button.
- Admin saves that break a rule are refused by the database with a readable
  message, which the admin app shows as is.
- If the alert trigger fails, the award insert fails too, so points and alerts
  never get out of step.

## 8. Testing

- Unit tests (phone app): level for points at every boundary (0, 29, 30, 99,
  100 … 1,500, above), progress and points-to-next, Platinum's "top level"
  case, Newcomer.
- Unit tests: leaderboard row parsing, and the "celebrate only on increase,
  once" rule.
- Database checks, run in rolled-back transactions:
  - a regular user can't change presets or levels or award points;
  - `set_level_thresholds` refuses non-increasing values;
  - an award creates a Points alert, and crossing a threshold also creates a
    Level Up alert;
  - "This month" ignores awards from last month;
  - admins and deactivated accounts don't appear in the leaderboard;
  - users can read and mark only their own alerts.

## 9. Order of work

1. Database migration (after June approves it).
2. In parallel: admin web app (June, section 5) and phone app (Claude,
   section 6).
3. Together: award points from the admin app and check the alert, level-up
   celebration and leaderboard on a phone.

## 10. Known limits

- Profile pictures are stored inside profile rows (about 20–40 KB each), so a
  top-20 list carries about 0.5 MB of pictures. Fine at this size; moving
  pictures to file storage is the fix if NavAble grows.
- Full names are public on the leaderboard. Users should be told this, for
  example in the terms or on the sign-up screen.
- Lowering a level threshold never takes points away, but raising one can move
  people down a level. The admin warning covers this.
