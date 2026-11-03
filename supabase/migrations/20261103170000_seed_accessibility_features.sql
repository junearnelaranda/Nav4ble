-- Starter accessibility feature catalog. Names line up with the app's
-- filters and with what Google Maps reports (entrance, restroom, parking,
-- seating), so NavAble and Google data use the same words.
-- Admins can rename, add or deactivate features in Accessibility Data.
insert into public.accessibility_features (feature_name, description)
select name, description
from (values
  ('Wheelchair ramp', 'Ramp or step-free access for wheelchairs'),
  ('Elevator', 'Working elevator or lift between floors'),
  ('Accessible entrance', 'Wheelchair-accessible entrance'),
  ('Accessible restroom', 'Wheelchair-accessible restroom or toilet'),
  ('Accessible parking', 'Wheelchair-accessible parking spaces'),
  ('Wheelchair seating', 'Seating that fits a wheelchair'),
  ('Tactile paving', 'Tactile paving for people with low vision'),
  ('Braille signage', 'Signs with braille'),
  ('Audio assistance', 'Audio guidance or announcements')
) as seed(name, description)
where not exists (
  select 1 from public.accessibility_features f
  where lower(f.feature_name) = lower(seed.name)
);
