# Accessibility Route Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users open any accessibility feature at a place and see where to find it, from contributor guides that admins approve.

**Architecture:** A new `feature_guides` table holds written locations, two photos and an optional pin. The app reads approved guides through a database function and shows them in a floating icon row above the place card; a temporary marker on its own map layer shows the spot. The admin site reviews guides on a new page.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12.2, flutter_map, Supabase (Postgres, RLS, Storage), plain JavaScript admin site on Cloudflare Pages.

**Spec:** `docs/superpowers/specs/2026-11-18-accessibility-route-guidance-design.md`

## Global Constraints

- **Existing map pins must not change.** Their colors, sizes, fading and tap behavior stay as they are.
- **Never run `git commit` or `git push`.** Each task ends by listing files for the user to commit. No Claude attribution anywhere.
- **The database migration needs the user's explicit yes at the moment it is applied.**
- Run Flutter from PowerShell through the short path: `C:\FLUTTE~1\flutter\bin\flutter.bat`.
- Build web zips only with `python C:\NavAble-deploy\make_zip.py navable-app navable-app.zip`, run in `C:\NavAble-deploy`.
- Two repos: app at `C:\Flutter Workspace\navable`, admin at `C:\AdminNav`.
- Limits: where text 200, floor 40, landmark 120, review note 300 characters; photos 700 KiB; pin within 500 m of the place.
- No contributor photo or text is public before approval. No contributor name or id appears on a guide.
- Never sign in with real accounts. Admin checks use a test admin the user signs in with themselves.

## Review Focus

1. **Feature names differ only in capitals** ("Accessible Restroom" vs "Accessible restroom"): the icon still finds its guides. Test in Task 2.
2. **User picks another place while guides are loading:** the late answer is ignored and any open guide closes. Test in Task 4.
3. **Submit tapped twice quickly:** exactly one guide is sent. Test in Task 5.
4. **A guide photo fails to load:** a "Photo unavailable" placeholder shows and nothing crashes. Test in Task 4.
5. **Narrow phone with large text:** the guide card and form scroll without overflow. Tests in Tasks 4 and 5.

---

### Task 1: Database

**Files:**
- Create: `supabase/migrations/20261118120000_feature_guides.sql`

**Interfaces:**
- Produces: table `public.feature_guides`; functions `public.get_location_guides(place uuid)` and `public.review_feature_guide(guide uuid, decision text, note text)`.

- [ ] **Step 1: Write the migration exactly as below**

```sql
create table public.feature_guides (
  guide_id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.locations (location_id) on delete cascade,
  feature_id uuid not null references public.accessibility_features (feature_id) on delete cascade,
  user_id uuid references public.users (user_id) on delete set null,
  where_text varchar(200) not null check (length(trim(where_text)) > 0),
  floor varchar(40),
  landmark varchar(120),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  feature_photo_url text not null,
  nearby_photo_url text not null,
  status text not null default 'Pending' check (status in ('Pending', 'Approved', 'Rejected')),
  review_note varchar(300),
  reviewed_by uuid references public.users (user_id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint feature_guides_pin_complete check ((latitude is null) = (longitude is null))
);
create index feature_guides_location_status on public.feature_guides (location_id, status);

alter table public.feature_guides enable row level security;

create policy admins_manage_all on public.feature_guides for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy users_read_own_guides on public.feature_guides for select to authenticated
  using (user_id = (select auth.uid()));

create policy users_add_own_guides on public.feature_guides for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'Pending'
    and review_note is null and reviewed_by is null and reviewed_at is null
    and exists (
      select 1 from public.locations l
      where l.location_id = feature_guides.location_id
        and (l.verification_status = 'Verified'
          or (l.verification_status = 'Pending' and l.created_by = (select auth.uid())))
    )
    and position('..' in feature_photo_url) = 0
    and position('..' in nearby_photo_url) = 0
    and starts_with(feature_photo_url, 'https://bipsoacordrbcekzsdlr.supabase.co/storage/v1/object/public/report-photos/' || (select auth.uid()) || '/')
    and starts_with(nearby_photo_url, 'https://bipsoacordrbcekzsdlr.supabase.co/storage/v1/object/public/report-photos/' || (select auth.uid()) || '/')
  );

create policy users_delete_own_pending_guides on public.feature_guides for delete to authenticated
  using (user_id = (select auth.uid()) and status = 'Pending');

-- An approved guide proves the feature exists at that place.
create function public.feature_guide_mark_feature() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.location_features (location_id, feature_id, availability, verified_by, verified_at)
  values (new.location_id, new.feature_id, true, new.reviewed_by, now())
  on conflict (location_id, feature_id) do update
    set availability = true, verified_by = excluded.verified_by, verified_at = excluded.verified_at;
  return new;
end $$;
revoke all on function public.feature_guide_mark_feature() from public, anon, authenticated;

create trigger feature_guides_mark_feature
  after insert or update of status on public.feature_guides
  for each row when (new.status = 'Approved')
  execute function public.feature_guide_mark_feature();

-- Approved guides for everyone; never exposes who wrote or reviewed them.
create function public.get_location_guides(place uuid)
returns table (
  guide_id uuid, feature_id uuid, feature_name text, where_text text, floor text,
  landmark text, latitude double precision, longitude double precision,
  feature_photo_url text, nearby_photo_url text
)
language sql stable security definer set search_path = '' as $$
  select g.guide_id, g.feature_id, f.feature_name::text, g.where_text::text, g.floor::text,
         g.landmark::text, g.latitude, g.longitude, g.feature_photo_url, g.nearby_photo_url
  from public.feature_guides g
  join public.locations l on l.location_id = g.location_id
  join public.accessibility_features f on f.feature_id = g.feature_id
  join public.location_features lf on lf.location_id = g.location_id and lf.feature_id = g.feature_id
  where g.location_id = place and g.status = 'Approved'
    and l.verification_status = 'Verified' and f.status = 'Active' and lf.availability
  order by f.feature_name, g.created_at
$$;
revoke all on function public.get_location_guides(uuid) from public;
grant execute on function public.get_location_guides(uuid) to anon, authenticated;

-- One step for the admin page: decide and notify together.
create function public.review_feature_guide(guide uuid, decision text, note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  row_guide public.feature_guides;
  place_name text;
  feature text;
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if decision not in ('Approved', 'Rejected') then raise exception 'Unknown decision'; end if;
  if decision = 'Rejected' and length(trim(coalesce(note, ''))) = 0 then
    raise exception 'A reason is required to reject a guide';
  end if;
  update public.feature_guides
     set status = decision, review_note = nullif(trim(note), ''),
         reviewed_by = (select auth.uid()), reviewed_at = now()
   where guide_id = guide and status = 'Pending'
   returning * into row_guide;
  if not found then raise exception 'This guide was already reviewed'; end if;
  select location_name into place_name from public.locations where location_id = row_guide.location_id;
  select feature_name into feature from public.accessibility_features where feature_id = row_guide.feature_id;
  if row_guide.user_id is not null then
    insert into public.notifications (user_id, title, message, notification_type)
    values (
      row_guide.user_id,
      case decision when 'Approved' then 'Your guide is live' else 'Your guide was not approved' end,
      left(case decision
        when 'Approved' then format('Your guide for %s at %s is now visible to everyone. Thank you!', feature, place_name)
        else format('Your guide for %s at %s was not approved. Reason: %s', feature, place_name, trim(note))
      end, 500),
      'Accessibility Update'
    );
  end if;
end $$;
revoke all on function public.review_feature_guide(uuid, text, text) from public, anon;
grant execute on function public.review_feature_guide(uuid, text, text) to authenticated;
```

- [ ] **Step 2: Ask the user for a clear yes, then apply the migration** with the Supabase `apply_migration` tool, name `feature_guides`.

- [ ] **Step 3: Prove the rules in one transaction ending in `rollback`**

Using two non-admin users, one verified place and one active feature, acting as `authenticated` through `set_config('request.jwt.claims', ...)`, confirm:

| Action | Expected |
|---|---|
| User inserts a Pending guide with photos in their own folder | Allowed |
| User inserts with `status = 'Approved'` | Refused, 42501 |
| User inserts as another `user_id` | Refused, 42501 |
| User inserts a photo URL in another user's folder, or containing `..` | Refused, 42501 |
| User updates their own guide | 0 rows changed |
| User calls `review_feature_guide` | Refused, 42501 |
| `get_location_guides` while Pending | 0 rows |
| Admin calls `review_feature_guide(id, 'Rejected', '')` | Error: reason required |
| Admin approves | `get_location_guides` returns the guide without `user_id`; `location_features.availability` true; one notification row |
| Admin approves the same guide again | Error: already reviewed |
| Other user deletes the guide | 0 rows deleted |

Run `get_advisors` (security) and confirm no new finding names `feature_guides` beyond the intentional public read function.

- [ ] **Step 4: Files for the user to commit:** `supabase/migrations/20261118120000_feature_guides.sql`

---

### Task 2: Guide data layer

**Files:**
- Create: `lib/guides_api.dart`
- Test: `test/guides_api_test.dart`

**Interfaces:**
- Consumes: `get_location_guides`, `GoogleMapsLauncher.isValidCoordinate`, `ReportsApi.maxPhotoBytes`.
- Produces:
  - `class GuidesApiException implements Exception { final String message; }`
  - `class GuideFeature { final String id; final String name; }`
  - `class FeatureGuide { id, featureId, featureName, whereText, floor (String?), landmark (String?), latitude (double?), longitude (double?), featurePhotoUrl, nearbyPhotoUrl; bool get hasPin; static FeatureGuide? fromRow(Map row); }`
  - `Map<String, List<FeatureGuide>> guidesByFeature(Iterable<FeatureGuide> guides)`, keyed by `featureKey(name)`
  - `String featureKey(String name)`: trimmed lowercase
  - `GuideFeature? featureForDetection(String detected, List<GuideFeature> features)`
  - `abstract final class GuidesApi` with `maxWhere = 200`, `maxFloor = 40`, `maxLandmark = 120`, `maxPinMeters = 500`, and:
    - `static String? validate({required String whereText, String floor = '', String landmark = '', required bool hasFeaturePhoto, required bool hasNearbyPhoto, LatLng? pin, required LatLng place})`
    - `static String? photoProblem(Uint8List bytes)`
    - `static Future<List<FeatureGuide>> forLocation(String locationId)`
    - `static Future<List<GuideFeature>> activeFeatures()`
    - `static Future<void> submit(GuideSubmission submission)`
  - `class GuideSubmission { locationId, featureId, whereText, floor, landmark, LatLng? pin, Uint8List? featurePhoto, String? featurePhotoUrl, Uint8List nearbyPhoto }`

- [ ] **Step 1: Write the failing tests**

```dart
test('fromRow reads a guide and treats a bad pin as no pin', () {
  final guide = FeatureGuide.fromRow(row(latitude: 0, longitude: 0))!;
  expect(guide.hasPin, isFalse);
  expect(FeatureGuide.fromRow(row(latitude: 10.29, longitude: 123.88))!.hasPin, isTrue);
});
test('fromRow rejects rows missing text or photos', () {
  expect(FeatureGuide.fromRow(row(whereText: ' ')), isNull);
  expect(FeatureGuide.fromRow(row(nearbyPhoto: 'http://not-secure/x.jpg')), isNull);
});
test('guidesByFeature ignores capitals and spaces', () {
  final map = guidesByFeature([guide(feature: 'Accessible Restroom')]);
  expect(map[featureKey(' accessible restroom ')], hasLength(1));
});
test('validate enforces required fields and limits', () {
  expect(check(whereText: ' '), isNotNull);
  expect(check(whereText: 'a' * 201), isNotNull);
  expect(check(floor: 'a' * 41), isNotNull);
  expect(check(landmark: 'a' * 121), isNotNull);
  expect(check(hasFeaturePhoto: false), isNotNull);
  expect(check(hasNearbyPhoto: false), isNotNull);
  expect(check(), isNull);
});
test('validate limits the pin to 500 m from the place', () {
  expect(check(pin: const LatLng(10.3000, 123.9000)), isNull); // the place itself
  expect(check(pin: const LatLng(10.3040, 123.9000)), isNull); // about 445 m
  expect(check(pin: const LatLng(10.3060, 123.9000)), isNotNull); // about 667 m
});
test('photoProblem rejects photos over 700 KiB', () {
  expect(GuidesApi.photoProblem(Uint8List(700 * 1024)), isNull);
  expect(GuidesApi.photoProblem(Uint8List(700 * 1024 + 1)), isNotNull);
});
test('featureForDetection maps AI labels to features', () {
  expect(featureForDetection('ramp', all)?.name, 'Wheelchair ramp');
  expect(featureForDetection('Toilet', all)?.name, 'Accessible restroom');
  expect(featureForDetection('stairs', all), isNull);
});
```

`check(...)` wraps `GuidesApi.validate` with valid defaults and `place: LatLng(10.3, 123.9)`.

- [ ] **Step 2: Run and see it fail**

Run: `C:\FLUTTE~1\flutter\bin\flutter.bat test test/guides_api_test.dart`
Expected: FAIL, `guides_api.dart` not found.

- [ ] **Step 3: Implement `lib/guides_api.dart`**

- `featureForDetection` matches keyword groups: ramp; elevator or lift; entrance or door; restroom, toilet or comfort room; tactile; parking; seat; braille.
- `submit` requires a signed-in user. It uploads with `FileOptions(contentType: ...)` to `report-photos` at `{userId}/guides/{uuid}/feature.jpg` and `nearby.jpg`, skipping the feature upload when `featurePhotoUrl` is given, then inserts the row. If the insert fails, it removes the files uploaded in this attempt and throws `GuidesApiException("Couldn't send your guide. Try again.")`.
- Copy: `'Tell people where to find it.'`, `'Add a photo of the feature.'`, `'Add a photo of what is nearby.'`, `'Pin a spot within 500 m of this place.'`, `'This photo is over 700 KiB. Choose a smaller photo.'`

- [ ] **Step 4: Run and see it pass**

Run: `C:\FLUTTE~1\flutter\bin\flutter.bat test test/guides_api_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Files for the user to commit:** `lib/guides_api.dart`, `test/guides_api_test.dart`

---

### Task 3: Walking directions to a spot

**Files:**
- Modify: `lib/services/google_maps_launcher.dart`
- Test: `test/google_maps_launcher_test.dart`

**Interfaces:**
- Produces: `directionsUri({latitude, longitude, String travelMode = 'driving'})` and `openDirections({latitude, longitude, String travelMode = 'driving'})`.

- [ ] **Step 1: Add failing tests**

```dart
test('directions default to driving', () {
  final uri = GoogleMapsLauncher.directionsUri(latitude: 10.3, longitude: 123.9)!;
  expect(uri.queryParameters['travelmode'], 'driving');
});
test('a guide spot can ask for walking directions', () {
  final uri = GoogleMapsLauncher.directionsUri(latitude: 10.3, longitude: 123.9, travelMode: 'walking')!;
  expect(uri.queryParameters['travelmode'], 'walking');
});
```

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/google_maps_launcher_test.dart`. Expected: FAIL, no parameter `travelMode`.
- [ ] **Step 3: Add the parameter to both methods.**
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/services/google_maps_launcher.dart`, `test/google_maps_launcher_test.dart`

---

### Task 4: Floating icons and guide panel

The spec lists one file `part of home.dart`. These widgets are a separate public library instead, because private `home.dart` classes cannot be widget-tested.

**Files:**
- Create: `lib/widgets/feature_guide_widgets.dart`
- Test: `test/feature_guide_widgets_test.dart`

**Interfaces:**
- Consumes: Task 2 types.
- Produces:
  - `IconData iconForFeature(String name)`: ramp `accessible_forward_rounded`, elevator `elevator_outlined`, entrance `meeting_room_outlined`, restroom or toilet `wc_rounded`, tactile `blind_rounded`, parking `local_parking_rounded`, seating `event_seat_outlined`, otherwise `accessible_rounded`.
  - `class GuideSpot { final LatLng point; final IconData icon; }`
  - `class GuideSpotMarker extends StatelessWidget { const GuideSpotMarker({required IconData icon}); }`
  - `class FeatureGuideView extends StatefulWidget`: `FeatureGuideView({required String featureName, required List<FeatureGuide> guides, required ValueChanged<FeatureGuide> onGuideShown, required ValueChanged<FeatureGuide> onGoToSpot, required VoidCallback onDirections, required VoidCallback onAddAnother, required bool isGuest, VoidCallback? onClose})`
  - `class FeatureGuideEmptyView extends StatelessWidget`: `({required String featureName, required bool isGuest, required VoidCallback onAdd, VoidCallback? onClose})`
  - `class PlaceGuidePanel extends StatefulWidget`: `({required String locationId, required List<String> features, required bool isGuest, required Widget placeCard, required Future<List<FeatureGuide>> Function(String) loadGuides, required ValueChanged<GuideSpot?> onSpotChanged, required ValueChanged<String> onAddGuide, required ValueChanged<FeatureGuide> onGoToSpot, required VoidCallback onDirections})`

- [ ] **Step 1: Write the failing widget tests**

| Test | Assertion |
|---|---|
| `shows only the place card while guides load` | No label ending `where to find it` or `no guide yet` before the future completes |
| `hides the row when loading fails` | `loadGuides` throws; place card shown; no icon labels |
| `labels icons with and without guides` | `find.bySemanticsLabel('Elevator, where to find it')` and `find.bySemanticsLabel('Parking, no guide yet')` each find one |
| `icons are at least 48 px` | `tester.getSize` of each icon is at least `Size(48, 48)` |
| `icons stay still with animations off` | With `disableAnimations: true`, `tester.hasRunningAnimations` is false after `pump()` |
| `a guide with a pin moves the map` | Tap icon: `onSpotChanged` receives a `GuideSpot` at the pin; `Go to this spot` shown; place card gone |
| `closing a guide restores the card` | Tap close: `onSpotChanged` receives null; place card shown |
| `a guide without a pin offers Directions` | `onSpotChanged` receives null; `Directions` shown; `Go to this spot` absent |
| `several spots can be stepped through` | `Spot 1 of 2`; tap next; `Spot 2 of 2`; `onSpotChanged` receives the second pin |
| `guests are asked to sign in` | Empty view shows `Sign in to add where to find it`, not `Add where to find it` |
| `signed-in users can add a guide` | Tap `Add where to find it`: `onAddGuide('Parking')` |
| `a late answer for the previous place is ignored` | Pump place A with a pending completer, pump place B, complete A: A's icons never appear |
| `changing place closes an open guide` | Open guide, pump a new `locationId`: `onSpotChanged(null)`; place card shown |
| `a broken photo shows a placeholder` | Network image fails in the test: `Photo unavailable` appears twice; `tester.takeException()` is null |
| `the guide fits a narrow phone with large text` | At `Size(320, 568)` and text scale 1.3: `tester.takeException()` is null |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/feature_guide_widgets_test.dart`. Expected: FAIL, file not found.

- [ ] **Step 3: Implement the widgets**

- Layout: `PlaceGuidePanel` is a `Column` of the icon row, then the guide, the empty view or `placeCard`.
- Row: horizontal scroll, 8 px gap, 48 px white circles. Guides: solid `NavAblePalette.green` border and `NavAblePalette.greenDark` icon. No guide: dashed look with grey fill. Selected: `greenDark` fill and white icon. Bob 5 px over 3 s, off when `MediaQuery.disableAnimations` is true.
- Guide text: feature name, where text, `Floor: …`, `Near: …`, two photos, `✓ Verified by NavAble`.
- With a pin: `Go to this spot`, plus the note `Google Maps may not show an accessible route.`
- Without a pin: `Directions`.
- Always: `Add another spot` for signed-in users. Tapping a photo opens it full screen in a dialog with a close button.
- Empty text: `Nobody has shared where this feature is yet.`
- Long content scrolls inside a card capped at 55% of the screen height.
- Ignore stale loads with a request counter, and reset state in `didUpdateWidget` when `locationId` changes.

- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/widgets/feature_guide_widgets.dart`, `test/feature_guide_widgets_test.dart`

---

### Task 5: Add-a-guide form

**Files:**
- Create: `lib/screens/add_guide_screen.dart`
- Test: `test/add_guide_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 validation and `GuideSubmission`.
- Produces: `class AddGuideScreen extends StatefulWidget`: `({required String locationId, required String placeName, required LatLng placePoint, required List<GuideFeature> features, String? initialFeatureName, String? initialFeaturePhotoUrl, required Future<void> Function(GuideSubmission) onSubmit, required Widget Function(BuildContext, LatLng start, ValueChanged<LatLng>) pinPickerBuilder, Future<Uint8List?> Function(BuildContext)? pickPhoto})`. When `pickPhoto` is null it uses `ImagePicker` with `imageQuality: 60` and `maxWidth: 1024`, offering camera or gallery.

- [ ] **Step 1: Write the failing widget tests**

| Test | Assertion |
|---|---|
| `shows every field` | `Where to find it`, `Floor (optional)`, `Nearby sign or landmark (optional)`, `Photo of the feature`, `Photo of what's nearby`, `Pin the spot (optional)` |
| `preselects the feature` | `initialFeatureName: 'Elevator'` shows `Elevator` |
| `explains what is missing` | Submit empty: `Tell people where to find it.`; `onSubmit` not called |
| `sends the guide` | Fill the fields with a fake `pickPhoto`: `onSubmit` receives trimmed text; screen pops; `Thanks! An admin will review your guide.` shown |
| `submitting twice sends one guide` | Tap `Submit for review` twice while `onSubmit` is pending: called once |
| `reuses the scan photo` | With `initialFeaturePhotoUrl`, only the nearby photo is required; submission carries the URL |
| `keeps the form after a failure` | `onSubmit` throws `GuidesApiException('Try again')`: message shown, typed text kept, button enabled |
| `fits a narrow phone with large text` | `Size(320, 568)`, scale 1.3: no exception |

- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/add_guide_screen_test.dart`. Expected: FAIL, file not found.
- [ ] **Step 3: Implement the screen.** Use a scrolling form, `maxLength` matching `GuidesApi`, and show `GuidesApi.photoProblem` messages when a picked photo is too large.
- [ ] **Step 4: Run the same command.** Expected: All tests passed.
- [ ] **Step 5: Files for the user to commit:** `lib/screens/add_guide_screen.dart`, `test/add_guide_screen_test.dart`

---

### Task 6: Connect guides to the Home map

**Files:**
- Modify: `lib/widgets/open_street_map_view.dart`
- Modify: `lib/screens/home_tab.dart:357-378`
- Modify: `lib/home.dart`

**Interfaces:**
- Consumes: `PlaceGuidePanel`, `GuideSpot`, `GuideSpotMarker`, `AddGuideScreen`, `GuidesApi`.
- Produces: `_HomeScreenState._openAddGuide(AccessibleLocation location, {String? featureName, String? featurePhotoUrl})`, used by Task 7.

- [ ] **Step 1: Add the map marker with additions only**

Add optional `guideSpot` (`GuideSpot?`) and `guideReturnPoint` (`osm.LatLng?`) to `_OpenStreetMapView`. Add a **separate** `fm.MarkerLayer` after the existing marker layer, drawn only when `guideSpot` is set. In `didUpdateWidget`, after the first frame: a new spot moves the camera to it at zoom 18; a cleared spot moves to `guideReturnPoint` at zoom 16.

- [ ] **Step 2: Prove the pin code was not touched**

Run: `git diff -w --numstat -- lib/widgets/open_street_map_view.dart`
Expected: the second number (deleted lines) is `0`. Any deleted line must be restored.

- [ ] **Step 3: Show the panel**

In `_PlanPage`, when `place.accessibleLocation` is not null and has features, wrap `_AutoCollapsePlaceCard` as `placeCard` of `PlaceGuidePanel`, keyed by the location id. Every other place keeps the plain card.

In `_HomeScreenState`, hold `GuideSpot? _guideSpot`, clear it when the selected place changes, and pass it down. `onGoToSpot` calls `GoogleMapsLauncher.openDirections(..., travelMode: 'walking')` and shows `_showMessage("Couldn't open Google Maps.")` on failure.

- [ ] **Step 4: Add `_openAddGuide`**

Guests get `_showMessage('Sign in to add where to find it.')`. Otherwise load `GuidesApi.activeFeatures()` and push `AddGuideScreen`, with `pinPickerBuilder` returning `_OpenStreetMapView(selectionMode: true, ...)`.

- [ ] **Step 5: Check**

Run: `C:\FLUTTE~1\flutter\bin\flutter.bat analyze` then `C:\FLUTTE~1\flutter\bin\flutter.bat test`
Expected: No issues found; All tests passed.

- [ ] **Step 6: Files for the user to commit:** `lib/widgets/open_street_map_view.dart`, `lib/screens/home_tab.dart`, `lib/home.dart`

---

### Task 7: Explore details and the thank-you screen

**Files:**
- Modify: `lib/screens/explore_tab.dart:1127-1215`
- Modify: `lib/screens/report_result_screens.dart:477-610`
- Modify: `lib/screens/reports_tab.dart:332-341`
- Modify: `lib/reports_api.dart:20-29`
- Test: `test/reports_api_test.dart`

**Interfaces:**
- Consumes: `_openAddGuide`, `FeatureGuideView`, `FeatureGuideEmptyView`, `featureForDetection`.
- Produces: `SubmittedReport.firstPhotoUrl` (`String?`).

- [ ] **Step 1: Add a failing test** that `SubmittedReport(id: 'r', aiAnalysisStatus: 'completed', detections: const [], firstPhotoUrl: 'https://x/y.jpg').firstPhotoUrl` equals `'https://x/y.jpg'`, and that it defaults to null.
- [ ] **Step 2: Run:** `C:\FLUTTE~1\flutter\bin\flutter.bat test test/reports_api_test.dart`. Expected: FAIL.
- [ ] **Step 3: Set `firstPhotoUrl`** in `ReportsApi.submit` from the first uploaded image's public URL.
- [ ] **Step 4: Add the Explore section.** Below the feature list, add a **Where to find it** heading and one tappable row per feature, loading `GuidesApi.forLocation`. A row opens a bottom sheet with `FeatureGuideView` or `FeatureGuideEmptyView`. While loading or after a failure, hide the section. Pass `isGuest` and an `onAddGuide` callback into `_ExplorePlaceDetails`.
- [ ] **Step 5: Add the thank-you action.** `_ReportSubmittedScreen` gains optional `VoidCallback? onAddGuide`, shown as an outlined `Add where to find it` button above `Back to Home`. `reports_tab.dart` passes it only for a feature submission at an existing NavAble location, preselecting the top detection through `featureForDetection` and reusing `firstPhotoUrl`.
- [ ] **Step 6: Check:** run `analyze` and `test` as in Task 6. Expected: No issues found; All tests passed.
- [ ] **Step 7: Files for the user to commit:** `lib/screens/explore_tab.dart`, `lib/screens/report_result_screens.dart`, `lib/screens/reports_tab.dart`, `lib/reports_api.dart`, `test/reports_api_test.dart`

---

### Task 8: Admin Route Guides page

**Files (repo `C:\AdminNav`):**
- Create: `datas/guides.html`, based on `datas/verification.html`
- Create: `assets/js/pages/guides.js`
- Modify: `assets/js/admin.js:26-60`
- Modify: the sidebar in all 12 files in `datas/*.html`

**Interfaces:**
- Consumes: `feature_guides`, `review_feature_guide`, `window.NavAbleKit`.

- [ ] **Step 1: Register the page.** Add `guides.html` to `ADMIN_PAGES`, `NAV_ICONS` (`"signpost"`) and `PAGE_LABELS` (`"Route Guides"`). Add a sidebar link labelled `Route Guides` directly after `AI Verification` in every page.
- [ ] **Step 2: Build the queue.** Query `feature_guides` with `locations(location_name, address)`, `accessibility_features(feature_name)` and `users!feature_guides_user_id_fkey(email, user_profiles(first_name, last_name))`. Filters: Pending (default), Approved, Rejected. Pager size 12. Each item shows place, feature, written details, both photos, submit date, contributor and `Open pin in OpenStreetMap` when pinned.
- [ ] **Step 3: Add the decisions.** Show this reminder above the queue: `Check every photo for faces, plate numbers and other personal details before approving.` **Approve** calls `db.rpc('review_feature_guide', { guide, decision: 'Approved' })`. **Reject** opens a dialog with a required reason of up to 300 characters and calls the same function with `decision: 'Rejected'`. Use `K.withBusy` and `K.toast`, and reload the list after each decision.
- [ ] **Step 4: Check the syntax.** Run: `node --check assets/js/pages/guides.js && node --check assets/js/admin.js`. Expected: no output.
- [ ] **Step 5: Check in the browser.** Start preview `navable-admin` and ask the user to sign in with a test admin. Approve one test guide and reject another without a reason, then with one. Expected: rejecting without a reason is blocked, both decisions update the list, and no console errors appear.
- [ ] **Step 6: Files for the user to commit (admin repo):** `datas/guides.html`, `assets/js/pages/guides.js`, `assets/js/admin.js`, `datas/*.html`

---

### Task 9: Admin direct guides and dashboard count

**Files (repo `C:\AdminNav`):**
- Modify: `assets/js/location-details.js`
- Modify: `assets/js/pages/dashboard.js:159,223-225`
- Modify: `datas/dashboard.html:92-98`

- [ ] **Step 1: Add a Route guides section to the Locations dialog.** List this place's guides with status. **Add guide** has a feature select, the same text limits as the app, two required photo uploads to the `location-photos` bucket (reusing `uploadFiles`' type checks) and an optional latitude and longitude. Insert with `status: 'Approved'`, `user_id` and `reviewed_by` set to `window.NavAbleStaff.user_id`, and `reviewed_at: K.nowIso()`. **Delete** asks for confirmation first.
- [ ] **Step 2: Add the dashboard stat.** Add a `guidesToReview` metric card linking to `guides.html`, counting `feature_guides` where `status = 'Pending'`, labelled `Route guides to review`.
- [ ] **Step 3: Check the syntax.** Run: `node --check assets/js/location-details.js && node --check assets/js/pages/dashboard.js`. Expected: no output.
- [ ] **Step 4: Check in the browser** with the test admin. Add a guide to a test place. Expected: it appears through `get_location_guides`, the feature is marked present, and the dashboard count matches the Pending filter.
- [ ] **Step 5: Files for the user to commit (admin repo):** `assets/js/location-details.js`, `assets/js/pages/dashboard.js`, `datas/dashboard.html`

---

### Task 10: Full check and web build

**Files:** none new.

- [ ] **Step 1: Run everything.** Run: `C:\FLUTTE~1\flutter\bin\flutter.bat analyze` and `C:\FLUTTE~1\flutter\bin\flutter.bat test`. Expected: No issues found; All tests passed.
- [ ] **Step 2: Confirm the pins again.** Run the Task 6 Step 2 command. Expected: no deleted pin code.
- [ ] **Step 3: Build the website.** Run: `C:\FLUTTE~1\flutter\bin\flutter.bat build web --release --dart-define-from-file=dart_defines.json`. Copy `build\web` over `C:\NavAble-deploy\navable-app`, then run the zip script. Expected: `with backslashes: 0` and `index.html at top: True`.
- [ ] **Step 4: Hand over.** Tell the user to commit and push both repos and upload the zip through **Create deployment**. After upload, fetch `/assets/fonts/MaterialIcons-Regular.otf?nocache=1` and confirm it is a font, not HTML.
- [ ] **Step 5: Run through it with the user** on phone and web, as guest and as a test user: tap a pin, confirm pins look unchanged, open a guide, go to a spot, add a guide, approve it in the admin, and see it appear.
