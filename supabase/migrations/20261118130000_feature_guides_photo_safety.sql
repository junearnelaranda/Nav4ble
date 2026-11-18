-- Route guide photo safety, from the final review of feature_guides.

-- Contributors may only link plain files in their own folder. Rejects encoded
-- paths such as %2e%2e, which a browser resolves into another user's folder.
drop policy users_add_own_guides on public.feature_guides;

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
    and feature_photo_url ~ ('^https://bipsoacordrbcekzsdlr\.supabase\.co/storage/v1/object/public/report-photos/' || (select auth.uid()) || '/[A-Za-z0-9_/-]+\.(jpg|png|webp)$')
    and nearby_photo_url ~ ('^https://bipsoacordrbcekzsdlr\.supabase\.co/storage/v1/object/public/report-photos/' || (select auth.uid()) || '/[A-Za-z0-9_/-]+\.(jpg|png|webp)$')
  );

-- Admins can remove the photos of guides they reject or delete.
create policy "report photos: admins delete" on storage.objects for delete to authenticated
  using (bucket_id = 'report-photos' and (select public.is_admin()));

-- A guide can only go public with photos in the admin-only bucket, where the
-- contributor cannot swap them and the link does not contain their user id.
create or replace function public.review_feature_guide(guide uuid, decision text, note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  row_guide public.feature_guides;
  place_name text;
  feature text;
  safe_prefix constant text := 'https://bipsoacordrbcekzsdlr.supabase.co/storage/v1/object/public/location-photos/';
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if decision not in ('Approved', 'Rejected') then raise exception 'Unknown decision'; end if;
  if decision = 'Rejected' and length(trim(coalesce(note, ''))) = 0 then
    raise exception 'A reason is required to reject a guide';
  end if;
  if decision = 'Approved' and exists (
    select 1 from public.feature_guides g
    where g.guide_id = guide
      and not (starts_with(g.feature_photo_url, safe_prefix) and starts_with(g.nearby_photo_url, safe_prefix))
  ) then
    raise exception 'Copy the photos to location-photos before approving';
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
