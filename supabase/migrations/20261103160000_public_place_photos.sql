-- Let the app show admin-uploaded place photos.
--
-- public.images holds both admin place photos (location-photos bucket, or
-- links admins add) and users' report photos. Only the admin ones may be
-- public, and only for verified places, so the rule checks who uploaded the
-- photo. The check can't rely on the image URL: users can insert their own
-- images rows with any URL.

-- True when the given user is an active NavAble admin. SECURITY DEFINER so
-- the photo rule can look at public.users, which readers can't see.
create or replace function public.is_admin_user(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.users u
    where u.user_id = uid
      and u.role = 'Admin'
      and u.account_status = 'Active'
  );
$$;

revoke all on function public.is_admin_user(uuid) from public;
grant execute on function public.is_admin_user(uuid) to anon, authenticated;

create policy "public_read_admin_place_photos"
  on public.images
  for select
  to anon, authenticated
  using (
    upload_status = 'Uploaded'
    and (select public.is_admin_user(images.user_id))
    and exists (
      select 1 from public.locations l
      where l.location_id = images.location_id
        and l.verification_status = 'Verified'
    )
  );
