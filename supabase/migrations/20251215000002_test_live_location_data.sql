-- =============================================
-- TEST DATA FOR LIVE LOCATION FEATURE
-- Run this in Supabase SQL Editor after running
-- the 20251215_update_live_users_function.sql
-- =============================================

-- STEP 1: First, let's see what users exist
-- Run this to find user IDs to update:
SELECT id, email, name FROM users LIMIT 10;

-- STEP 2: Update YOUR user with live location (Perth 6027 - Joondalup area)
-- Replace 'YOUR_EMAIL' with your actual email
UPDATE users 
SET 
  live_latitude = -31.745,      -- Joondalup area
  live_longitude = 115.766,
  live_location_updated_at = NOW(),
  live_location_privacy = 'all'
WHERE email = 'YOUR_EMAIL_HERE';

-- STEP 3: If you have OTHER test users, update them too
-- These locations are spread around Perth 6027 area
-- User 2 - nearby (green marker - just updated)
/*
UPDATE users 
SET 
  live_latitude = -31.750,
  live_longitude = 115.770,
  live_location_updated_at = NOW(),
  live_location_privacy = 'all'
WHERE email = 'test2@example.com';
*/

-- User 3 - 1.5 hours ago (orange marker)
/*
UPDATE users 
SET 
  live_latitude = -31.738,
  live_longitude = 115.760,
  live_location_updated_at = NOW() - INTERVAL '90 minutes',
  live_location_privacy = 'all'
WHERE email = 'test3@example.com';
*/

-- User 4 - 3.5 hours ago (red marker)
/*
UPDATE users 
SET 
  live_latitude = -31.755,
  live_longitude = 115.780,
  live_location_updated_at = NOW() - INTERVAL '210 minutes',
  live_location_privacy = 'all'
WHERE email = 'test4@example.com';
*/

-- STEP 4: Verify the data was inserted correctly
SELECT 
  u.id,
  u.name,
  u.live_latitude,
  u.live_longitude,
  u.live_location_privacy,
  u.live_location_updated_at,
  d.name as dog_name,
  d.main_photo_url as dog_photo
FROM users u
LEFT JOIN dogs d ON d.user_id = u.id
WHERE u.live_latitude IS NOT NULL
  AND u.live_location_privacy != 'off';

-- STEP 5: Test the RPC function directly
-- Replace the UUID with your actual user ID from STEP 1
/*
SELECT * FROM get_nearby_live_users(
  'YOUR-USER-UUID-HERE'::UUID,
  -31.745,  -- Your latitude
  115.766,  -- Your longitude
  10.0      -- 10km radius
);
*/
