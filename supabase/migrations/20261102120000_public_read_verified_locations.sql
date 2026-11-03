-- Let guests and signed-in users read the map data.
--
-- Today the only policy on these tables is `admins_manage_all`, so the app's
-- map is empty for everyone except admins. These policies add read-only
-- access to published data. Admins keep full access through their existing
-- policy (Postgres combines policies with OR).
--
-- Written against the live schema (location_id / verification_status /
-- availability), not supabase/navable_schema.sql, which is out of date.

-- Only verified places appear on the map.
create policy "public_read_verified_locations"
  on public.locations
  for select
  to anon, authenticated
  using (verification_status = 'Verified');

-- Only active feature types (Ramp, Elevator, ...).
create policy "public_read_active_features"
  on public.accessibility_features
  for select
  to anon, authenticated
  using (status = 'Active');

-- A place's features: only available ones, on a verified place, of an
-- active feature type. The subqueries go through the two policies above,
-- so a hidden place or feature never leaks through this table.
create policy "public_read_available_location_features"
  on public.location_features
  for select
  to anon, authenticated
  using (
    availability
    and exists (
      select 1
      from public.locations l
      where l.location_id = location_features.location_id
        and l.verification_status = 'Verified'
    )
    and exists (
      select 1
      from public.accessibility_features f
      where f.feature_id = location_features.feature_id
        and f.status = 'Active'
    )
  );
