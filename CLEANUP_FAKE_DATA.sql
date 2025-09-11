-- =================================================================
-- CLEANUP FAKE DATA FROM BARKDATE DATABASE
-- =================================================================
-- Run this script in your Supabase SQL Editor to remove all test/fake data

-- 1. REMOVE FAKE SAMPLE DATA FROM ENHANCED MAP FEATURES
-- -----------------------------------------------------

-- Remove sample featured parks (these are the 3 fake parks we added)
DELETE FROM featured_parks 
WHERE name IN (
  'Central Bark Dog Park',
  'Riverside Dog Run', 
  'Brooklyn Bridge Park Dog Run'
);

-- Alternative: Remove all featured parks if you want to start fresh
-- DELETE FROM featured_parks;

-- 2. REMOVE FAKE SAMPLE DATA FROM MAIN BARKDATE TABLES
-- ---------------------------------------------------

-- Remove fake users and their related data
-- First get the fake user IDs
DO $$
DECLARE
  fake_user_ids UUID[];
BEGIN
  -- Get all fake user IDs
  SELECT ARRAY(
    SELECT id FROM users 
    WHERE email IN (
      'alice@example.com',
      'bob@example.com', 
      'charlie@example.com',
      'diana@example.com',
      'eve@example.com'
    )
  ) INTO fake_user_ids;

  -- Remove fake data in dependency order
  IF array_length(fake_user_ids, 1) > 0 THEN
    -- Remove playdate participants
    DELETE FROM playdate_participants 
    WHERE user_id = ANY(fake_user_ids);
    
    -- Remove playdates
    DELETE FROM playdates 
    WHERE organizer_id = ANY(fake_user_ids) 
       OR participant_id = ANY(fake_user_ids);
    
    -- Remove playdate requests  
    DELETE FROM playdate_requests
    WHERE requester_id = ANY(fake_user_ids)
       OR invitee_id = ANY(fake_user_ids);
    
    -- Remove messages
    DELETE FROM messages 
    WHERE sender_id = ANY(fake_user_ids) 
       OR receiver_id = ANY(fake_user_ids);
    
    -- Remove matches
    DELETE FROM matches 
    WHERE user_id = ANY(fake_user_ids) 
       OR target_user_id = ANY(fake_user_ids);
    
    -- Remove posts
    DELETE FROM posts 
    WHERE user_id = ANY(fake_user_ids);
    
    -- Remove park checkins
    DELETE FROM park_checkins 
    WHERE user_id = ANY(fake_user_ids);
    
    -- Remove dogs (will cascade to related tables)
    DELETE FROM dogs 
    WHERE user_id = ANY(fake_user_ids);
    
    -- Remove fake users from auth.users first
    DELETE FROM auth.users 
    WHERE email IN (
      'alice@example.com',
      'bob@example.com',
      'charlie@example.com', 
      'diana@example.com',
      'eve@example.com'
    );
    
    -- Remove fake users from users table
    DELETE FROM users 
    WHERE id = ANY(fake_user_ids);
    
    RAISE NOTICE 'Removed % fake users and their data', array_length(fake_user_ids, 1);
  ELSE
    RAISE NOTICE 'No fake users found to remove';
  END IF;
END $$;

-- 3. REMOVE SPECIFIC TEST PLAYDATES (if any exist)
-- -----------------------------------------------

-- Remove test playdates with specific titles
DELETE FROM playdates 
WHERE title IN (
  'Golden Gate Park Meetup',
  'Beach Playdate', 
  'Dog Park Adventure',
  'Buddy & Max Playdate',
  'Luna & Daisy Gentle Meetup',
  'Bella & Buddy Short Walk'
);

-- Remove test playdates with fake locations
DELETE FROM playdates 
WHERE location IN (
  'Central Park, New York, NY',
  'Zilker Park, Austin, TX', 
  'Lincoln Park, Chicago, IL',
  'Crissy Field Beach',
  'Dolores Park'
);

-- 4. REMOVE TEST PARK CHECKINS (any orphaned checkins)
-- ---------------------------------------------------

-- Remove any park checkins that don't have valid users
DELETE FROM park_checkins 
WHERE user_id NOT IN (SELECT id FROM users);

-- Remove any park checkins that don't have valid dogs  
DELETE FROM park_checkins 
WHERE dog_id NOT IN (SELECT id FROM dogs);

-- 5. CLEAN UP ORPHANED RECORDS
-- ---------------------------

-- Remove any orphaned playdate participants
DELETE FROM playdate_participants 
WHERE playdate_id NOT IN (SELECT id FROM playdates);

-- Remove any orphaned playdate requests
DELETE FROM playdate_requests 
WHERE playdate_id NOT IN (SELECT id FROM playdates);

-- Remove any orphaned messages
DELETE FROM messages 
WHERE match_id NOT IN (SELECT id FROM matches);

-- Remove any orphaned matches
DELETE FROM matches 
WHERE user_id NOT IN (SELECT id FROM users) 
   OR target_user_id NOT IN (SELECT id FROM users);

-- Remove any orphaned posts
DELETE FROM posts 
WHERE user_id NOT IN (SELECT id FROM users);

-- 6. RESET SEQUENCES (Optional)
-- ----------------------------

-- Note: UUID tables don't use sequences, but if you have any auto-increment columns
-- you might want to reset them. Most BarkDate tables use UUIDs so this likely isn't needed.

-- 7. VERIFICATION QUERIES
-- ----------------------

-- Check remaining data counts
SELECT 
  (SELECT COUNT(*) FROM users) as users_count,
  (SELECT COUNT(*) FROM dogs) as dogs_count,
  (SELECT COUNT(*) FROM playdates) as playdates_count,
  (SELECT COUNT(*) FROM featured_parks) as featured_parks_count,
  (SELECT COUNT(*) FROM park_checkins) as park_checkins_count,
  (SELECT COUNT(*) FROM matches) as matches_count,
  (SELECT COUNT(*) FROM messages) as messages_count,
  (SELECT COUNT(*) FROM posts) as posts_count;

-- Show remaining users (should only be real users)
SELECT id, name, email, created_at 
FROM users 
ORDER BY created_at DESC;

-- Show remaining featured parks (should be empty or only real parks)
SELECT name, address, created_at 
FROM featured_parks 
ORDER BY created_at DESC;

-- =================================================================
-- CLEANUP COMPLETE!
-- =================================================================

-- Summary of what was removed:
-- ✓ Fake sample users (Alice, Bob, Charlie, Diana, Eve)
-- ✓ Fake dogs belonging to those users  
-- ✓ Fake playdates and playdate requests
-- ✓ Fake messages and matches
-- ✓ Fake posts and social media content
-- ✓ Sample featured parks from NYC/Brooklyn area
-- ✓ Any orphaned park checkins
-- ✓ All related fake data in dependency order

-- Your real user data and any real featured parks you've added should remain intact.
-- The database is now clean and ready for production use!
