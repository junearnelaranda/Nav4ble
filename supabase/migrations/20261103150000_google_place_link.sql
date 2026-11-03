-- Link NavAble places to Google places.
--
-- Explore shows Google search results live (Google's terms allow storing only
-- the place id). NavAble's own data for a place (accessibility features,
-- ratings, reports) hangs off the NavAble location that carries that id.
-- Not unique: two users may suggest the same Google place before an admin
-- approves one; the admin keeps one and rejects the other.

alter table public.locations
  add column if not exists google_place_id text;

create index if not exists idx_locations_google_place_id
  on public.locations (google_place_id);
