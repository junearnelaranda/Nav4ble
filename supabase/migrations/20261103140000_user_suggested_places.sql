-- Let users contribute at places that aren't in NavAble yet.
--
-- A user pins a spot and names it; the app creates the place as Pending and
-- saves the contribution with it. An admin approves the place (sets it to
-- Verified) in the admin app before it appears on everyone's map.

-- Who suggested the place; filled automatically from the signed-in user.
alter table public.locations
  add column if not exists created_by uuid
    default auth.uid()
    references public.users (user_id) on delete set null;

-- Users may add places only as Pending, unscored, in their own name.
create policy "users_suggest_locations"
  on public.locations
  for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and verification_status = 'Pending'
    and accessibility_score = 0
  );

-- Users see the places they suggested (the ownership checks below need it).
create policy "users_read_own_suggested_locations"
  on public.locations
  for select
  to authenticated
  using (created_by = (select auth.uid()));

-- Lets the app remove its own suggestion if the submission fails halfway.
create policy "users_delete_own_pending_locations"
  on public.locations
  for delete
  to authenticated
  using (created_by = (select auth.uid()) and verification_status = 'Pending');

-- Photos and reports may now point at a verified place or at the user's own
-- pending suggestion.
drop policy "users_insert_own_images" on public.images;
create policy "users_insert_own_images"
  on public.images
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and upload_status = 'Uploaded'
    and exists (
      select 1 from public.locations l
      where l.location_id = images.location_id
        and (
          l.verification_status = 'Verified'
          or (l.verification_status = 'Pending' and l.created_by = (select auth.uid()))
        )
    )
  );

drop policy "users_insert_own_reports" on public.reports;
create policy "users_insert_own_reports"
  on public.reports
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'Pending'
    and priority_level = 'Medium'
    and (
      image_id is null
      or exists (
        select 1 from public.images i
        where i.image_id = reports.image_id
          and i.user_id = (select auth.uid())
      )
    )
    and exists (
      select 1 from public.locations l
      where l.location_id = reports.location_id
        and (
          l.verification_status = 'Verified'
          or (l.verification_status = 'Pending' and l.created_by = (select auth.uid()))
        )
    )
  );

create index if not exists idx_locations_created_by on public.locations (created_by);
