# Accessibility Route Guidance: design

Capstone objective 4. Status: waiting for approval. Nothing here is built yet.

## Why

NavAble can say that a mall has an elevator, but not where it is. A wheelchair
user arriving at a large place still has to search for the ramp, restroom or
elevator. This feature tells them where each accessibility feature is, in the
way a helpful person would: "right side of the main entrance, near the blue
sign", with photos, and a map point when the spot is outdoors.

## Goals

- From a selected place, a user can open any accessibility feature and see where
  to find it.
- Outdoor spots can be shown on the map and opened in Google Maps.
- Indoor spots are guided by written location, floor, landmark and photos.
- Contributors can submit guides. Admins approve them before anyone else sees
  them. Admins can also add guides directly.

## Non-goals

- Turn-by-turn indoor navigation, floor plans, or indoor positioning.
- Claiming a route is wheelchair-safe. Google Maps does not guarantee that.
- Awarding points for guides in this version. `contribution_points` only accepts
  reports and reviews today; this can be added later.
- Editing a guide after it is submitted. A contributor deletes a pending guide
  and submits again.

## Anti-goals

- **The existing map pins must not change.** Their colors, sizes, fading, tap
  behavior and the place selection flow stay exactly as they are.
- No contributor photo or text is public before an admin approves it.
- No contributor name or user id is exposed on a guide.

## Approaches considered

1. **Spot guide with pin (chosen).** Written location, 2 photos, optional pin,
   several spots per feature. Works indoors and outdoors.
2. **Text and photos only.** Quicker, but Directions could only reach the place
   itself, so it is weak as route guidance.
3. **Admin-written step-by-step routes.** Clearest guidance, but someone must walk
   and document every route, which is not realistic for 25 places.

Floating icon layouts considered: a ring around the pin (A), a row above the card
(B), and a row that also jumps to the exact spot (C). **C was chosen.**

## What the user sees

### 1. Selecting a place

Tapping a pin works as it does today. For a NavAble location that has features, a
row of floating round icons appears directly above the place card, one per
feature. The row scrolls sideways if the icons do not fit.

- Solid green outline: at least one approved guide exists.
- Dashed grey outline: the feature is listed, but has no guide yet.
- Places that come only from map search have no row.
- Icons bob gently. They stay still when the device's "remove animations" setting
  is on.
- Each icon is at least 48 px, with a screen reader label such as "Elevator, where
  to find it" or "Elevator, no guide yet".

### 2. Tapping an icon that has a guide

The guide replaces the place card, and the icon row stays visible above it.

- Title (feature name), location text, floor and landmark.
- Two photos: the feature, and what is near it. Tapping a photo enlarges it.
- "Verified by NavAble".
- With several spots: "Spot 1 of 2" with previous and next buttons.
- **With a pin:** the map moves to the spot and shows a temporary round marker with
  the feature's icon. **Go to this spot** opens Google Maps at that point in walking
  mode, with a short note that Google Maps may not show an accessible route.
- **Without a pin:** the map does not move, and the guide offers the normal
  **Directions** to the place.
- Closing the guide removes the marker, returns the map to the place and restores
  the place card.

### 3. Tapping an icon with no guide

A small card says nobody has shared where this feature is yet.

- Signed-in users see **Add where to find it**.
- Guests see "Sign in to add where to find it".

Approved guides also have **Add another spot**.

### 4. Adding a guide

The form "Where is this feature?" contains:

| Field | Rule |
|---|---|
| Feature | Preselected; can be changed when opened from the scan flow |
| Where to find it | Required, up to 200 characters |
| Floor | Optional, up to 40 characters |
| Nearby sign or landmark | Optional, up to 120 characters |
| Photo of the feature | Required |
| Photo of what's nearby | Required |
| Pin the spot | Optional; must be within 500 m of the place |

Submitting shows "Thanks! An admin will review your guide." Neither photo is sent
to the AI scanner.

The form opens from:

- **Add where to find it** and **Add another spot** on the Home map.
- The same actions in Explore place details.
- The thank-you screen after a scan or feature submission for a NavAble location,
  with the detected feature preselected and the already uploaded scan photo reused as
  the feature photo.

### 5. Explore place details

`_ExplorePlaceDetails` gains a **Where to find it** section listing the approved
guides by feature. Opening one shows the same guide content and **Go to this spot**
when it has a pin. It does not jump a map, because Explore has none.

### 6. Admin website

- **New page, Route Guides (`datas/guides.html`):** a queue of pending guides,
  showing the place, feature, written location, both photos, a link that opens the pin
  in OpenStreetMap, and the submit date. Filters: Pending, Approved, Rejected.
- **Approve:** the guide goes public, and the feature is marked as present at that
  place in `location_features` (`availability = true`, `verified_by`, `verified_at`).
- **Reject:** requires a short reason.
- Either decision sends the contributor a notification, following the pattern in
  `assets/js/pages/reports.js`. The admin must check photos for faces, plate numbers
  and other personal details, and the page says so.
- **Locations dialog (`assets/js/location-details.js`):** a **Route guides** section
  where admins add or delete guides for that place. Admin-added guides are approved
  immediately and use the `location-photos` bucket.
- The dashboard's "Needs your review" area includes the pending guide count.

## Data

### New table `public.feature_guides`

| Column | Type | Notes |
|---|---|---|
| `guide_id` | uuid, primary key | `gen_random_uuid()` |
| `location_id` | uuid, not null | References `locations`, cascade delete |
| `feature_id` | uuid, not null | References `accessibility_features`, cascade delete |
| `user_id` | uuid | References `users`, set null on delete |
| `where_text` | varchar(200), not null | |
| `floor` | varchar(40) | |
| `landmark` | varchar(120) | |
| `latitude`, `longitude` | double precision | Both set or both null; valid ranges |
| `feature_photo_url` | text, not null | |
| `nearby_photo_url` | text, not null | |
| `status` | text, not null | `Pending`, `Approved` or `Rejected`; default `Pending` |
| `review_note` | varchar(300) | Required by the admin page when rejecting |
| `reviewed_by` | uuid | References `users`, set null on delete |
| `reviewed_at` | timestamptz | |
| `created_at` | timestamptz, not null | `now()` |

Index on `(location_id, status)`.

### Access rules

- **Admins:** full access, using the existing `is_admin()` pattern.
- **Signed-in users:**
  - read their own guides;
  - insert only with their own `user_id`, `status = 'Pending'`, empty review fields,
    a location that is verified or that they created while pending (matching the
    `images` rule), and photo URLs inside their own `report-photos/{user id}/` folder;
  - delete only their own pending guides;
  - never update.
- **Everyone, including guests:** reads approved guides only through a new function
  `get_location_guides(place uuid)`. It is `security definer`, returns only approved
  guides for a verified place with an active feature, and never returns `user_id`,
  `reviewed_by` or `review_note`.

Contributor photos use the existing `report-photos` bucket and the existing 700 KiB
limit. No storage rule changes are needed.

The Terms and Privacy Policy already say that photos admins approve are shown to other
users, so no legal text change is needed.

## App structure

| File | Change |
|---|---|
| `lib/guides_api.dart` (new) | `FeatureGuide` model, load, submit, photo upload, validation |
| `lib/widgets/feature_guide_widgets.dart` (new) | Icon row, guide card, empty card, panel |
| `lib/screens/add_guide_screen.dart` (new) | Add-a-guide form |
| `lib/screens/home_tab.dart` | Shows the row and guide above or in place of the place card |
| `lib/widgets/open_street_map_view.dart` | New optional temporary spot marker on its own layer; pin code untouched |
| `lib/services/google_maps_launcher.dart` | Optional travel mode, defaulting to today's driving behavior |
| `lib/screens/explore_tab.dart` | **Where to find it** section |
| `lib/screens/report_result_screens.dart` | **Add where to find it** on the thank-you screen |

`_AutoCollapsePlaceCard` collapses after 4 seconds. The icon row and guide must not
be lost to that timer: the row stays visible while a place is selected, and the timer
is paused while a guide or form is open.

Feature icons match the Home filter chips. The feature list comes from
`AccessibleLocation.features`, matched by name to `accessibility_features`.

## Errors and edge cases

- Guides are still loading, or fail to load: the row stays hidden and the place card
  works as usual. It must never show "no guide yet" when the answer is simply unknown.
- A feature name that does not match `accessibility_features` gets no icon.
- Upload fails: the form keeps what was typed and shows a retry message. Any photo
  already uploaded for that attempt is removed.
- A guide's pin is invalid: treated as having no pin.
- A feature is removed from a place: its approved guides are not shown.
- Offline: the place card works as it does today.

## Testing

- Unit tests: guide parsing, validation limits, pin distance rule, grouping by feature.
- Widget tests: solid and dashed icons, guest and signed-in empty card, guide with and
  without a pin, spot switching, reduced motion, and a check that existing pin markers
  are unchanged.
- Database checks in a rolled-back transaction: a user cannot approve their own guide,
  insert as someone else, or use another user's photo folder; guests see approved guides
  only; hidden columns are never returned.
- Manual run-through on phone and web, including the admin approval path.

## Rollout

1. Apply the database migration, after explicit approval at that step.
2. Update the admin site. The user commits and pushes; Cloudflare deploys from GitHub.
3. Build the web app, zip it with `C:\NavAble-deploy\make_zip.py`, and upload it.
4. Admins add guides for the demo places.
