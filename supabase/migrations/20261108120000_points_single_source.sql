-- One source of truth for point values: preset awards take their value from
-- point_presets (the table the app, leaderboard and alerts use), not the
-- older point_tiers table the admin app used first.
create or replace function public.set_contribution_points_owner()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare
  preset integer;
begin
  if new.report_id is not null then
    select r.user_id into new.user_id from public.reports r where r.report_id = new.report_id;
  elsif new.review_id is not null then
    select v.user_id into new.user_id from public.reviews v where v.review_id = new.review_id;
  end if;
  if new.tier <> 'Custom' then
    select p.points into preset from public.point_presets p where p.tier = new.tier;
    new.points := coalesce(preset, new.points);
  end if;
  new.awarded_by := coalesce(new.awarded_by, (select auth.uid()));
  return new;
end;
$function$;

-- Signed-out visitors don't need to know who is an admin.
-- (Undone by 20261108120100: the guest photo rule needs this function.)
revoke execute on function public.is_admin_user(uuid) from anon;
