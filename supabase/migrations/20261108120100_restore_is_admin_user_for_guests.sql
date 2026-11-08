-- The guest photo rule (public_read_admin_place_photos) calls is_admin_user,
-- so signed-out visitors need to be able to run it. Restores the grant
-- removed in 20261108120000_points_single_source.sql.
grant execute on function public.is_admin_user(uuid) to anon;
