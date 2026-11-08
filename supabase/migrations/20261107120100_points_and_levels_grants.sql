-- Follow-up to 20261107120000_points_and_levels.sql.
-- Supabase grants EXECUTE on new public functions to anon and authenticated
-- by default, so "revoke ... from public" alone left every function callable.
-- Revoke explicitly, then grant only what the design allows.

revoke execute on function public.check_level_thresholds(int[]) from anon, authenticated;
revoke execute on function public.points_period_start(text) from anon, authenticated;
revoke execute on function public.ranked_contributors(text) from anon, authenticated;
revoke execute on function public.notify_points_awarded() from anon, authenticated;
revoke execute on function public.notifications_user_update_guard() from anon, authenticated;

-- Signed-in only (admin checks happen inside the admin functions).
revoke execute on function public.get_my_standing(text) from anon;
revoke execute on function public.set_point_presets(int, int, int) from anon;
revoke execute on function public.set_level_thresholds(int[]) from anon;
revoke execute on function public.preview_level_changes(int[]) from anon;

-- Guests may see levels and the leaderboard.
grant execute on function public.level_for_points(int) to anon, authenticated;
grant execute on function public.get_leaderboard(text, int) to anon, authenticated;
