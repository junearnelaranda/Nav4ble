-- Run in the shared Supabase project's SQL editor after reviewing existing tables.
-- This is a bootstrap schema for a new project; adapt it before applying to existing data.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  contribution_points integer not null default 0
);

create table if not exists public.locations (
  id text primary key,
  name text not null,
  address text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  status text not null default 'pending',
  rating double precision
);

create table if not exists public.accessibility_features (
  id text primary key,
  name text not null,
  status text not null default 'approved'
);

create table if not exists public.location_features (
  location_id text not null references public.locations(id) on delete cascade,
  feature_id text not null references public.accessibility_features(id) on delete cascade,
  status text not null default 'approved',
  primary key (location_id, feature_id)
);

create table if not exists public.reports (
  id text primary key,
  user_id uuid not null references auth.users(id),
  title text not null,
  detail text not null,
  category text not null,
  location text not null,
  location_id text,
  latitude double precision,
  longitude double precision,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  ai_analysis_status text not null default 'failed' check (ai_analysis_status in ('completed', 'partial', 'failed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  review_note text
);

create table if not exists public.photo_submissions (
  id bigint generated always as identity primary key,
  report_id text not null references public.reports(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  photo_index integer not null check (photo_index between 0 and 4),
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/webp')),
  detections jsonb not null default '[]'::jsonb,
  image jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (report_id, photo_index)
);

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  location_id text not null references public.locations(id) on delete cascade,
  unique (user_id, location_id)
);

create index if not exists reports_user_id_idx on public.reports(user_id);
create index if not exists photo_submissions_user_id_idx on public.photo_submissions(user_id);
create index if not exists favorites_user_id_idx on public.favorites(user_id);

create or replace function public.navable_create_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(
    nullif(trim(concat_ws(' ', new.raw_user_meta_data ->> 'first_name',
      new.raw_user_meta_data ->> 'last_name')), ''),
    new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do update
    set full_name = excluded.full_name;
  return new;
end;
$$;

drop trigger if exists navable_user_created on auth.users;
create trigger navable_user_created
after insert or update of raw_user_meta_data on auth.users
for each row execute function public.navable_create_profile();

insert into public.profiles (id, full_name)
select id, coalesce(
  nullif(trim(concat_ws(' ', raw_user_meta_data ->> 'first_name',
    raw_user_meta_data ->> 'last_name')), ''),
  raw_user_meta_data ->> 'full_name', '')
from auth.users
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.locations enable row level security;
alter table public.accessibility_features enable row level security;
alter table public.location_features enable row level security;
alter table public.reports enable row level security;
alter table public.photo_submissions enable row level security;
alter table public.favorites enable row level security;

-- Administrator and moderator roles must be assigned in app_metadata server side.
create or replace function public.navable_is_moderator()
returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator'), false);
$$;

revoke all on public.profiles, public.locations, public.accessibility_features,
  public.location_features, public.reports, public.photo_submissions,
  public.favorites from anon, authenticated;
grant select on public.locations, public.accessibility_features,
  public.location_features to anon, authenticated;
grant select on public.profiles, public.reports, public.photo_submissions,
  public.favorites to authenticated;
grant insert on public.reports, public.photo_submissions, public.favorites to authenticated;
grant update on public.reports, public.locations, public.accessibility_features,
  public.location_features to authenticated;
grant insert on public.locations, public.accessibility_features,
  public.location_features to authenticated;
grant delete on public.reports, public.favorites, public.locations,
  public.accessibility_features, public.location_features to authenticated;
grant usage, select on sequence public.photo_submissions_id_seq to authenticated;
grant execute on function public.navable_is_moderator() to authenticated;

create policy "read own profile" on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select public.navable_is_moderator()));
create policy "read approved locations" on public.locations for select to anon, authenticated
using (status = 'approved' or (select public.navable_is_moderator()));
create policy "read approved features" on public.accessibility_features for select to anon, authenticated
using (status = 'approved' or (select public.navable_is_moderator()));
create policy "read approved location features" on public.location_features for select to anon, authenticated
using (status = 'approved' or (select public.navable_is_moderator()));
create policy "moderators update locations" on public.locations for update to authenticated
using ((select public.navable_is_moderator())) with check ((select public.navable_is_moderator()));
create policy "moderators create locations" on public.locations for insert to authenticated
with check ((select public.navable_is_moderator()));
create policy "moderators delete locations" on public.locations for delete to authenticated
using ((select public.navable_is_moderator()));
create policy "moderators update features" on public.accessibility_features for update to authenticated
using ((select public.navable_is_moderator())) with check ((select public.navable_is_moderator()));
create policy "moderators create features" on public.accessibility_features for insert to authenticated
with check ((select public.navable_is_moderator()));
create policy "moderators delete features" on public.accessibility_features for delete to authenticated
using ((select public.navable_is_moderator()));
create policy "moderators update location features" on public.location_features for update to authenticated
using ((select public.navable_is_moderator())) with check ((select public.navable_is_moderator()));
create policy "moderators create location features" on public.location_features for insert to authenticated
with check ((select public.navable_is_moderator()));
create policy "moderators delete location features" on public.location_features for delete to authenticated
using ((select public.navable_is_moderator()));
create policy "read own reports" on public.reports for select to authenticated
using (user_id = (select auth.uid()) or (select public.navable_is_moderator()));
create policy "submit own pending reports" on public.reports for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'pending'
  and reviewed_at is null and reviewed_by is null and review_note is null);
create policy "moderators review reports" on public.reports for update to authenticated
using ((select public.navable_is_moderator())) with check ((select public.navable_is_moderator()));
create policy "remove own pending reports" on public.reports for delete to authenticated
using (user_id = (select auth.uid()) and status = 'pending');
create policy "read own photos" on public.photo_submissions for select to authenticated
using (user_id = (select auth.uid()) or (select public.navable_is_moderator()));
create policy "submit photos for own report" on public.photo_submissions for insert to authenticated
with check (
  user_id = (select auth.uid())
  and storage_path like (select auth.uid())::text || '/' || report_id || '/%'
  and exists (select 1 from public.reports r
    where r.id = report_id and r.user_id = (select auth.uid()) and r.status = 'pending')
);
create policy "read own favorites" on public.favorites for select to authenticated
using (user_id = (select auth.uid()));
create policy "save own favorites" on public.favorites for insert to authenticated
with check (user_id = (select auth.uid()));
create policy "remove own favorites" on public.favorites for delete to authenticated
using (user_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-photos', 'report-photos', false, 716800,
  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "users upload own report photos" on storage.objects for insert to authenticated
with check (bucket_id = 'report-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] is not null
  and (storage.filename(name)) ~ '^photo_[0-4]\.(jpg|png|webp)$'
  and exists (select 1 from public.reports r
    where r.id = (storage.foldername(name))[2]
      and r.user_id = (select auth.uid()) and r.status = 'pending'));
create policy "users and moderators read report photos" on storage.objects for select to authenticated
using (bucket_id = 'report-photos'
  and ((storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.navable_is_moderator())));
create policy "users remove own report photos" on storage.objects for delete to authenticated
using (bucket_id = 'report-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text);
