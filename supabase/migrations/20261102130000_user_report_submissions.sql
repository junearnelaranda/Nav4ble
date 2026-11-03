-- Let signed-in users submit accessibility reports from the mobile app into
-- the tables the admin app reads: reports, images and ai_results.
--
-- Before this, only admins could write to these tables and there was no
-- photo storage, so every report submission from the app failed.

-- Photo storage --------------------------------------------------------------

-- Public read: the admin app shows a photo only when images.image_url is a
-- web link. Paths contain the user id and random ids, so they can't be
-- guessed, and there is no listing policy, so nobody can browse the bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'report-photos',
  'report-photos',
  true,
  716800, -- 700 KiB, same limit the app enforces
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Users upload only into their own folder: <user-id>/<report-id>/photo_N.ext
create policy "users_upload_own_report_photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Lets the app remove its own uploads if a submission fails halfway.
create policy "users_delete_own_report_photos"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- images ---------------------------------------------------------------------

-- Own photos only, and only for a verified NavAble location.
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
        and l.verification_status = 'Verified'
    )
  );

create policy "users_read_own_images"
  on public.images
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "users_delete_own_images"
  on public.images
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- reports --------------------------------------------------------------------

-- New reports always start as Pending / Medium; admins change those.
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
        and l.verification_status = 'Verified'
    )
  );

create policy "users_read_own_reports"
  on public.reports
  for select
  to authenticated
  using (user_id = (select auth.uid()));

-- Only while still Pending, so users can't remove reports admins acted on.
create policy "users_delete_own_pending_reports"
  on public.reports
  for delete
  to authenticated
  using (user_id = (select auth.uid()) and status = 'Pending');

-- ai_results -----------------------------------------------------------------

-- AI suggestions for the user's own photos. They always arrive unverified
-- and "Needs Verification", so an admin must confirm them.
create policy "users_insert_ai_results_for_own_images"
  on public.ai_results
  for insert
  to authenticated
  with check (
    verified = false
    and detection_status = 'Needs Verification'
    and exists (
      select 1 from public.images i
      where i.image_id = ai_results.image_id
        and i.user_id = (select auth.uid())
    )
  );

create policy "users_read_ai_results_for_own_images"
  on public.ai_results
  for select
  to authenticated
  using (
    exists (
      select 1 from public.images i
      where i.image_id = ai_results.image_id
        and i.user_id = (select auth.uid())
    )
  );

-- Speeds up the ownership checks above and the admin app's joins.
create index if not exists idx_reports_image on public.reports (image_id);
