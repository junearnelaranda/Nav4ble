-- Contributor points and levels
-- Spec: docs/superpowers/specs/2026-11-07-points-and-levels-design.md (section 4)
--
-- Adds: the Custom award tier, admin-editable point boxes and level
-- thresholds, the leaderboard and "my standing" functions, an alert for
-- every award (plus one when a level is reached), and lets users read and
-- mark their own alerts.

-- 1. Custom tier --------------------------------------------------------------
alter table public.contribution_points
  drop constraint contribution_points_tier_check;
alter table public.contribution_points
  add constraint contribution_points_tier_check
  check (tier = any (array['Small', 'Regular', 'Big', 'Custom']));

-- 2. Point boxes --------------------------------------------------------------
create table public.point_presets (
  tier text primary key check (tier = any (array['Small', 'Regular', 'Big'])),
  points int not null check (points between 1 and 1000),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (user_id) on delete set null
);
insert into public.point_presets (tier, points)
values ('Small', 5), ('Regular', 10), ('Big', 25);

alter table public.point_presets enable row level security;
create policy "everyone_reads_point_presets"
  on public.point_presets for select to anon, authenticated using (true);
-- No write policies: changes go through set_point_presets().

-- 3. Levels -------------------------------------------------------------------
create table public.contributor_levels (
  level int primary key check (level between 1 and 5),
  name text not null unique,
  min_points int not null check (min_points >= 1),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (user_id) on delete set null
);
insert into public.contributor_levels (level, name, min_points)
values (1, 'Explorer', 30), (2, 'Bronze', 100), (3, 'Silver', 300),
       (4, 'Gold', 750), (5, 'Platinum', 1500);

alter table public.contributor_levels enable row level security;
create policy "everyone_reads_contributor_levels"
  on public.contributor_levels for select to anon, authenticated using (true);
-- No write policies: changes go through set_level_thresholds().

-- 4. Level math ---------------------------------------------------------------
-- Level for a lifetime total: 0 / Newcomer below the first threshold.
create or replace function public.level_for_points(points int)
returns table (level int, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(l.level, 0), coalesce(l.name, 'Newcomer')
  from (select 1) as one
  left join lateral (
    select cl.level, cl.name
    from public.contributor_levels cl
    where cl.min_points <= coalesce($1, 0)
    order by cl.min_points desc
    limit 1
  ) as l on true;
$$;

-- Shared check for new thresholds: 5 values, first at least 1, each higher
-- than the one before.
create or replace function public.check_level_thresholds(thresholds int[])
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  i int;
begin
  if thresholds is null
     or coalesce(array_length(thresholds, 1), 0) <> 5
     or array_position(thresholds, null) is not null
     or thresholds[1] < 1 then
    raise exception 'Levels need 5 values, each higher than the one before.'
      using errcode = '22023';
  end if;
  for i in 2..5 loop
    if thresholds[i] <= thresholds[i - 1] then
      raise exception 'Levels need 5 values, each higher than the one before.'
        using errcode = '22023';
    end if;
  end loop;
end;
$$;

-- 5. Admin-only updates -------------------------------------------------------
create or replace function public.set_point_presets(small int, regular int, big int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can change point values.' using errcode = '42501';
  end if;
  if small is null or regular is null or big is null
     or least(small, regular, big) < 1 or greatest(small, regular, big) > 1000 then
    raise exception 'Point values must be 1 to 1,000.' using errcode = '22023';
  end if;
  update public.point_presets
  set points = case tier when 'Small' then small when 'Regular' then regular else big end,
      updated_at = now(),
      updated_by = auth.uid();
end;
$$;

create or replace function public.set_level_thresholds(thresholds int[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can change levels.' using errcode = '42501';
  end if;
  perform public.check_level_thresholds(thresholds);
  update public.contributor_levels
  set min_points = thresholds[level],
      updated_at = now(),
      updated_by = auth.uid();
end;
$$;

-- Contributors whose level would go down with the new thresholds. Changes
-- nothing; the admin app shows these before saving.
create or replace function public.preview_level_changes(thresholds int[])
returns table (user_id uuid, full_name text, total_points int,
               current_level text, new_level text)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Only admins can change levels.' using errcode = '42501';
  end if;
  perform public.check_level_thresholds(thresholds);
  return query
  with totals as (
    select t.user_id, t.total_points,
           (select count(*) from public.contributor_levels cl
             where cl.min_points <= t.total_points)::int as cur_num,
           (select count(*) from unnest(thresholds) x
             where x <= t.total_points)::int as new_num
    from public.user_point_totals t
  )
  select t.user_id,
         coalesce(nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
                  'NavAble contributor'),
         t.total_points,
         coalesce((select cl.name from public.contributor_levels cl
                    where cl.level = t.cur_num), 'Newcomer'),
         coalesce((select cl.name from public.contributor_levels cl
                    where cl.level = t.new_num), 'Newcomer')
  from totals t
  left join public.user_profiles p on p.user_id = t.user_id
  where t.new_num < t.cur_num
  order by t.total_points desc;
end;
$$;

-- 6. Leaderboard --------------------------------------------------------------
-- Start of "This month" in Philippine time, as a timestamp.
create or replace function public.points_period_start(period text)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
begin
  if period = 'all' then
    return '-infinity'::timestamptz;
  elsif period = 'month' then
    return date_trunc('month', now() at time zone 'Asia/Manila')
           at time zone 'Asia/Manila';
  end if;
  raise exception 'Period must be month or all.' using errcode = '22023';
end;
$$;

-- Everyone ranked for a period: active accounts with the User role, most
-- points first; a tie goes to whoever reached the total first.
create or replace function public.ranked_contributors(period text)
returns table (rank int, user_id uuid, points int, lifetime_points int)
language sql
stable
security definer
set search_path = ''
as $$
  with period_totals as (
    select cp.user_id, sum(cp.points)::int as points, max(cp.created_at) as last_at
    from public.contribution_points cp
    where cp.created_at >= public.points_period_start($1)
    group by cp.user_id
  ),
  lifetime as (
    select cp.user_id, sum(cp.points)::int as total
    from public.contribution_points cp
    group by cp.user_id
  )
  select (row_number() over (order by pt.points desc, pt.last_at asc, pt.user_id))::int,
         pt.user_id, pt.points, l.total
  from period_totals pt
  join public.users u
    on u.user_id = pt.user_id and u.role = 'User' and u.account_status = 'Active'
  join lifetime l on l.user_id = pt.user_id;
$$;

create or replace function public.get_leaderboard(period text, max_rows int default 20)
returns table (rank int, user_id uuid, full_name text, profile_picture text,
               points int, level int, level_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.rank, r.user_id,
         coalesce(nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
                  'NavAble contributor'),
         p.profile_picture, r.points, lv.level, lv.name
  from public.ranked_contributors($1) r
  left join public.user_profiles p on p.user_id = r.user_id
  cross join lateral public.level_for_points(r.lifetime_points) lv
  order by r.rank
  limit greatest(1, least(coalesce($2, 20), 100));
$$;

-- The signed-in user's rank and level. Lifetime points decide the level;
-- the period only changes rank and points.
create or replace function public.get_my_standing(period text)
returns table (rank int, points int, level int, level_name text,
               next_level_name text, next_level_min_points int)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  lifetime int;
  period_points int;
  my_rank int;
begin
  if me is null then
    return;
  end if;
  select coalesce(sum(cp.points), 0)::int into lifetime
  from public.contribution_points cp where cp.user_id = me;
  select coalesce(sum(cp.points), 0)::int into period_points
  from public.contribution_points cp
  where cp.user_id = me and cp.created_at >= public.points_period_start(period);
  select r.rank into my_rank
  from public.ranked_contributors(period) r where r.user_id = me;

  return query
  select my_rank, period_points, lv.level, lv.name, nx.name, nx.min_points
  from public.level_for_points(lifetime) lv
  left join lateral (
    select cl.name, cl.min_points from public.contributor_levels cl
    where cl.min_points > lifetime
    order by cl.min_points
    limit 1
  ) nx on true;
end;
$$;

-- 7. Alerts -------------------------------------------------------------------
alter table public.notifications
  drop constraint notifications_notification_type_check;
alter table public.notifications
  add constraint notifications_notification_type_check
  check (notification_type = any (array['Report Update', 'Verification',
    'Accessibility Update', 'System Announcement', 'Points', 'Level Up']));

-- "+10 points / For your report at Ayala Center Cebu", plus "You're now
-- Silver / Level 3" when the award crosses a threshold.
create or replace function public.notify_points_awarded()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  place text;
  what text;
  total int;
  old_level int;
  new_level int;
  new_name text;
begin
  if new.source_type = 'Report' then
    what := 'report';
    select l.location_name into place
    from public.reports r
    left join public.locations l on l.location_id = r.location_id
    where r.report_id = new.report_id;
  else
    what := 'review';
    select l.location_name into place
    from public.reviews v
    left join public.locations l on l.location_id = v.location_id
    where v.review_id = new.review_id;
  end if;
  place := coalesce(nullif(trim(place), ''), 'a place');

  insert into public.notifications (user_id, title, message, notification_type)
  values (new.user_id, '+' || new.points || ' points',
          'For your ' || what || ' at ' || place, 'Points');

  select coalesce(sum(cp.points), 0)::int into total
  from public.contribution_points cp where cp.user_id = new.user_id;
  select lv.level into old_level from public.level_for_points(total - new.points) lv;
  select lv.level, lv.name into new_level, new_name from public.level_for_points(total) lv;
  if new_level > old_level then
    insert into public.notifications (user_id, title, message, notification_type)
    values (new.user_id, 'You''re now ' || new_name, 'Level ' || new_level, 'Level Up');
  end if;
  return null;
end;
$$;

create trigger award_points_notify
  after insert on public.contribution_points
  for each row execute function public.notify_points_awarded();

-- Users read their own alerts and may only mark them read. Admins keep full
-- access through admins_manage_all.
create policy "users_read_own_notifications"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
create policy "users_mark_own_notifications_read"
  on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function public.notifications_user_update_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() and (
       new.user_id is distinct from old.user_id
    or new.title is distinct from old.title
    or new.message is distinct from old.message
    or new.notification_type is distinct from old.notification_type
    or new.created_at is distinct from old.created_at) then
    raise exception 'You can only mark alerts as read.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger notifications_user_update_guard
  before update on public.notifications
  for each row execute function public.notifications_user_update_guard();

-- 8. Who may call what -------------------------------------------------------
revoke all on function public.level_for_points(int) from public;
revoke all on function public.check_level_thresholds(int[]) from public;
revoke all on function public.set_point_presets(int, int, int) from public;
revoke all on function public.set_level_thresholds(int[]) from public;
revoke all on function public.preview_level_changes(int[]) from public;
revoke all on function public.points_period_start(text) from public;
revoke all on function public.ranked_contributors(text) from public;
revoke all on function public.get_leaderboard(text, int) from public;
revoke all on function public.get_my_standing(text) from public;
revoke all on function public.notify_points_awarded() from public;
revoke all on function public.notifications_user_update_guard() from public;

grant execute on function public.level_for_points(int) to anon, authenticated;
grant execute on function public.get_leaderboard(text, int) to anon, authenticated;
grant execute on function public.get_my_standing(text) to authenticated;
grant execute on function public.set_point_presets(int, int, int) to authenticated;
grant execute on function public.set_level_thresholds(int[]) to authenticated;
grant execute on function public.preview_level_changes(int[]) to authenticated;
