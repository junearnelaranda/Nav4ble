-- Community place photos: when an admin verifies a user's report, the admin
-- site copies its photos into the admin-only location-photos bucket (so the
-- link no longer contains the user's account id) and marks them public.
-- Everyone then sees them in the place's photo gallery.

alter table public.images
  add column if not exists is_public boolean not null default false;

comment on column public.images.is_public is
  'Set by an admin when a verified report''s photo is shown on the place.';

-- Users can't publish their own photos: only admins set is_public.
drop policy if exists users_insert_own_images on public.images;
create policy users_insert_own_images on public.images
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and upload_status = 'Uploaded'
    and is_public = false
    and exists (
      select 1 from public.locations l
      where l.location_id = images.location_id
        and (
          l.verification_status = 'Verified'
          or (
            l.verification_status = 'Pending'
            and l.created_by = (select auth.uid())
          )
        )
    )
  );

-- Every verified place's gallery: admin photos first (oldest first, so the
-- cover stays the same), then published community photos. Community photos
-- must live in location-photos, which only admins can write to.
create or replace function public.get_place_photos()
returns table (
  location_id uuid,
  image_url text,
  contributor text
)
language sql
stable
security definer
set search_path to ''
as $$
  select
    i.location_id,
    i.image_url,
    case
      when public.is_admin_user(i.user_id) then null
      else coalesce(
        nullif(
          trim(
            concat_ws(
              ' ',
              nullif(trim(p.first_name), ''),
              case
                when nullif(trim(p.last_name), '') is not null
                  then left(trim(p.last_name), 1) || '.'
              end
            )
          ),
          ''
        ),
        'NavAble user'
      )
    end as contributor
  from public.images i
  join public.locations l on l.location_id = i.location_id
  left join public.user_profiles p on p.user_id = i.user_id
  where l.verification_status = 'Verified'
    and i.upload_status = 'Uploaded'
    and i.image_url like 'https://%/storage/v1/object/public/location-photos/%'
    and (public.is_admin_user(i.user_id) or i.is_public)
  order by
    i.location_id,
    public.is_admin_user(i.user_id) desc,
    i.upload_date,
    i.image_id
  limit 2000;
$$;

revoke all on function public.get_place_photos() from public;
grant execute on function public.get_place_photos() to anon, authenticated;
