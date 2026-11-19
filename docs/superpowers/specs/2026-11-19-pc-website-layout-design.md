# NavAble on a PC: website layout

Status: waiting for approval. Nothing here is built yet.

## Why

On a PC, `navable-app.pages.dev` looks like a phone app stretched across a wide
screen. The user's words: Explore, Reports, Alerts and Profile "look like a big
mobile", and they want them to look like a website.

## Goals

- On wide screens, a navy menu on the left side replaces the bottom tab bar.
- Explore, Reports, Alerts and Profile use the width well, as in the approved
  mockups, instead of one long phone column.
- The Map page keeps its current look. The user confirmed it looks good on a PC;
  it only gains the side menu.

## Non-goals

- No change to phones. Below 640 px wide, the app keeps the bottom tab bar and
  today's layouts, including the Android app.
- No new pages or features beyond those listed in "Additions".
- No change to the admin website.

## Anti-goals

- A PC layout that hides anything a phone user can do.
- Breaking guest mode: guests still see only Map and Explore, plus a way to sign in.
- Text cut off or overflowing at large text sizes or narrow windows.

## Approaches considered

1. **Top menu bar** (logo, links and avatar across the top). The most
   "website-like", and the assistant's recommendation.
2. **Menu on the left side** (navy sidebar, like the admin site). **Chosen by
   the user.**
3. **Keep the bottom bar and only limit page width.** Rejected: it still looks
   like a phone app.

## Window sizes

| Window width | Navigation | Page layouts |
|---|---|---|
| Below 640 px (phones) | Bottom tab bar, as today | As today |
| 640 to 999 px (tablets, small windows) | Left menu with icons only; labels show as tooltips | Wide layouts where they fit, otherwise as today |
| 1000 px and wider (PCs) | Left menu with icons and labels | Wide layouts as below |

## The left menu

- Navy background (`NavAblePalette.navy`), 220 px wide with labels, about 80 px
  with icons only.
- From top to bottom:
  - the NavAble logo and name;
  - Map, Explore, Reports, Alerts, Profile (same icons as the bottom bar);
  - Top Contributors;
  - at the bottom, the signed-in user's photo and name, which opens Profile.
- **Selected item:** a light green background with a green bar on its left edge, matching the admin site.
- **Alerts unread count:** a red badge showing how many alerts are unread.
- **Guests** see Map, Explore and Top Contributors, with a **Sign in** button at the bottom.
- **Keyboard and screen readers:** every item is reachable with Tab, says which page is selected, and is at least 48 px tall.
- **The top app bar** is not shown on wide screens: its trophy and avatar move into the menu. The Map page keeps its own search bar.

## Pages on wide screens

Content stays inside a centered column with a maximum width, so very wide
screens do not stretch it.

### Map
Unchanged. The map fills the space to the right of the menu.

### Explore (maximum width 1200 px)
- Title "Explore places" and a short summary line, such as "25 places in Cebu City".
- The search field and accessibility filter chips across the top.
- Places in a grid of equal cards: 3 columns at 1000 px and up, 2 columns below.
  Each card shows the cover photo, name, category, rating and up to 3 feature tags.
- Google search results use the same grid.
- Place details keep opening as today.

### Reports (maximum width 1200 px)
- The first step (choosing "Contribute accessibility" or "Report an issue") shows
  the two choices side by side.
- The form uses two columns:
  - **Left:** the form fields, photos and scan button.
  - **Right:** the location map, and below it the user's most recent submissions
    (up to 5) with their status, and a link to all submissions.
- The submit and scan flow does not change.

### Alerts (maximum width 760 px)
- A centered list in today's order (report updates, then other alerts).
- **New:** filter chips **All**, **Reports** and **Points** above the list.
  Reports shows report updates; Points shows Points and Level Up alerts.

### Profile (maximum width 1100 px)
- **Left column, 320 px:** photo, name, level, level progress, the three stats, and Edit profile.
- **Right column:** points history, then the settings links and Sign out.

## Additions the user approved with the mockups

1. Alerts filter chips (All, Reports, Points). On a phone they appear above the
   list too, so both stay the same.
2. An unread count badge on the Alerts menu item, counting unread alerts the way
   the app already does.
3. The menu narrowing to icons between 640 and 999 px.

## Constraints

- **One codebase:** the wide layouts switch on window width, never on platform.
- **Light and dark themes:** both keep working. The menu stays navy in both.
- **Text size:** the app's text scale (0.8 to 1.2) must not cause overflow at any width.
- **Testing:** widget tests at 390, 800 and 1440 px for each changed page and for the menu, plus a check with the largest text size.
- **Deployment:** web zips are built with `C:\NavAble-deploy\make_zip.py`. The user makes all commits.

## Left to the builder

- Exact spacing, card heights and shadows, within the existing NavAble design
  tokens (`NavAbleRadius`, `NavAbleSpacing`, `NavAblePalette`).
- How to share the width checks, for example one helper for "wide" and "compact".
- Whether to use Flutter's `NavigationRail` or a custom menu, as long as it
  matches the mockup and the accessibility rules above.
