-- SQL Script to fully delete dog "GG" and all related records
-- Run this in Supabase SQL Editor

-- First, find the dog ID for GG (to verify)
-- SELECT id, name, user_id FROM dogs WHERE name = 'GG';

-- Step 1: Delete from playdate_participants (where GG is organizer/participant)
DELETE FROM playdate_participants 
WHERE dog_id IN (SELECT id FROM dogs WHERE name = 'GG');

-- Step 2: Delete from playdate_requests (where GG was invited or requester)
DELETE FROM playdate_requests 
WHERE invitee_dog_id IN (SELECT id FROM dogs WHERE name = 'GG');

DELETE FROM playdate_requests 
WHERE requester_dog_id IN (SELECT id FROM dogs WHERE name = 'GG');

-- Step 3: Delete from any other related tables that might reference GG
-- Dog friendships
DELETE FROM dog_friendships 
WHERE dog_id IN (SELECT id FROM dogs WHERE name = 'GG')
   OR friend_dog_id IN (SELECT id FROM dogs WHERE name = 'GG');

-- Matches
DELETE FROM matches 
WHERE dog_id IN (SELECT id FROM dogs WHERE name = 'GG')
   OR target_dog_id IN (SELECT id FROM dogs WHERE name = 'GG');

-- Posts (where dog was tagged)
UPDATE posts SET dog_id = NULL 
WHERE dog_id IN (SELECT id FROM dogs WHERE name = 'GG');

-- Step 4: Finally, hard delete the dog record itself
DELETE FROM dogs WHERE name = 'GG';

-- Verify GG is gone
SELECT * FROM dogs WHERE name = 'GG';
-- Should return 0 rows
