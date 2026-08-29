-- Optional seed: run AFTER you have at least one real user (signup once).
-- Replace OWNER_UUID with that user's id from auth.users / profiles.

-- Example (do not run until you replace the UUID):
/*
insert into public.properties (
  owner_id, title, description, property_type, listing_type, price_usd,
  bedrooms, bathrooms, area_sqm, country, city, address, lat, lng, status, payment_status, published_at
) values
(
  'OWNER_UUID',
  '3-Bedroom Villa, Kiyovu',
  'Modern villa with garden in Kigali.',
  'Villa', 'For Sale', 145000,
  3, 3, 240, 'Rwanda', 'Kigali', 'Kiyovu', -1.9441, 30.0619,
  'published', 'paid', now()
),
(
  'OWNER_UUID',
  'Marina Condo, Dubai Marina',
  'Sea-view condo in Dubai Marina.',
  'Condo', 'For Sale', 410000,
  2, 2, 130, 'United Arab Emirates', 'Dubai', 'Dubai Marina', 25.0805, 55.1403,
  'published', 'paid', now()
);
*/
