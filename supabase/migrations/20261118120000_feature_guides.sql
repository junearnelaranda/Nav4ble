-- Accessibility Route Guidance: where to find each feature at a place.
-- Contributors submit guides, admins approve them, everyone reads approved ones.

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
