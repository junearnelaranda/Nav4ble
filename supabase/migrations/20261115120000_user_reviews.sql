-- Lets signed-in users rate and review NavAble locations.
-- Before this, only admins could write to public.reviews and the table
-- was empty, so the admin Ratings & Reviews page had nothing to show.

-- One review per user per place; they edit it instead of adding another.
create unique index if not exists reviews_one_per_user_location
  on public.reviews (user_id, location_id);

alter table public.reviews
  add constraint reviews_comment_length
  check (comment is null or char_length(comment) <= 500);

-- Users see their own reviews (also when an admin has hidden one).
-- Other people's reviews are read through get_location_reviews below,
-- which never exposes user ids, full names or emails.
create policy users_read_own_reviews on public.reviews
  for select to authenticated
  using (user_id = (select auth.uid()));

-- New reviews are the user's own and published straight away.
create policy users_add_own_reviews on public.reviews
  for insert to authenticated
  with check (
    user_id = (select auth.uid()) and review_status = 'Published'
  );

-- A user can change their own published review, but not un-hide one an
-- admin has hidden or hand it to someone else.
create policy users_edit_own_reviews on public.reviews
  for update to authenticated
  using (user_id = (select auth.uid()) and review_status = 'Published')
  with check (user_id = (select auth.uid()) and review_status = 'Published');

create policy users_delete_own_reviews on public.reviews
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- A place's published reviews, newest first, plus the caller's own review
-- whatever its status. The reviewer shows as first name and last initial.
create or replace function public.get_location_reviews(place uuid)
returns table (
  review_id uuid,
  rating integer,
  comment text,
  review_date timestamptz,
  review_status text,
  reviewer text,
  is_mine boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.review_id,
    r.rating,
    r.comment::text,
    r.review_date,
    r.review_status,
    coalesce(
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
    ) as reviewer,
    coalesce(r.user_id = (select auth.uid()), false) as is_mine
  from public.reviews r
  left join public.user_profiles p on p.user_id = r.user_id
  where r.location_id = place
    and (
      r.review_status = 'Published'
      or r.user_id = (select auth.uid())
    )
  order by r.review_date desc
  limit 100;
$$;

revoke all on function public.get_location_reviews(uuid) from public;
grant execute on function public.get_location_reviews(uuid)
  to anon, authenticated;
