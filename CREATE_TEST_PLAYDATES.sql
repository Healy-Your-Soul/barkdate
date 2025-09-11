-- Create test playdate data for testing the SET button functionality
-- This creates realistic data that matches your current user setup

-- First, let's see what users we have
SELECT id, name, email FROM users LIMIT 5;

-- Create a test upcoming playdate (Chen and other user)
-- Note: Replace the UUIDs with actual user IDs from your database
INSERT INTO playdates (
  id,
  title,
  location,
  scheduled_at,
  description,
  status,
  organizer_id,
  participant_id,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'Golden Gate Park Meetup',
  'Golden Gate Park, SF',
  NOW() + INTERVAL '2 days',
  'Let''s meet up for a fun playdate at the park!',
  'confirmed',
  'c427c572-e79b-4dbe-aa90-f0abad80090d', -- Chen's user ID
  'bd20b2dd-a970-4677-9739-6f7be4682473', -- Other user ID (Kat)
  NOW() - INTERVAL '1 day',
  NOW() - INTERVAL '1 day'
);

-- Create another upcoming playdate (other direction)
INSERT INTO playdates (
  id,
  title,
  location,
  scheduled_at,
  description,
  status,
  organizer_id,
  participant_id,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'Beach Playdate',
  'Crissy Field Beach',
  NOW() + INTERVAL '5 days',
  'Beach fun with our pups!',
  'confirmed',
  'bd20b2dd-a970-4677-9739-6f7be4682473', -- Kat's user ID
  'c427c572-e79b-4dbe-aa90-f0abad80090d', -- Chen's user ID
  NOW() - INTERVAL '2 hours',
  NOW() - INTERVAL '2 hours'
);

-- Create a test playdate request (pending)
-- First create the playdate
INSERT INTO playdates (
  id,
  title,
  location,
  scheduled_at,
  description,
  status,
  organizer_id,
  participant_id,
  created_at,
  updated_at
) VALUES (
  'f47ac10b-58cc-4372-a567-0e02b2c3d479', -- Fixed UUID for the playdate
  'Dog Park Adventure',
  'Dolores Park',
  NOW() + INTERVAL '3 days',
  'Want to meet up for a playdate?',
  'pending',
  'bd20b2dd-a970-4677-9739-6f7be4682473', -- Kat as organizer
  'c427c572-e79b-4dbe-aa90-f0abad80090d', -- Chen as participant (even though pending)
  NOW() - INTERVAL '3 hours',
  NOW() - INTERVAL '3 hours'
);

-- Then create the playdate request referencing the playdate
INSERT INTO playdate_requests (
  id,
  playdate_id,
  requester_id,
  invitee_id,
  status,
  message,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'f47ac10b-58cc-4372-a567-0e02b2c3d479', -- Reference the playdate ID from above
  'bd20b2dd-a970-4677-9739-6f7be4682473', -- Kat as requester
  'c427c572-e79b-4dbe-aa90-f0abad80090d', -- Chen as invitee
  'pending',
  'Hey! Would love to have Lizzy meet GIgi at Dolores Park this weekend!',
  NOW() - INTERVAL '3 hours',
  NOW() - INTERVAL '3 hours'
);

-- Verify the data was created
SELECT 
  p.id,
  p.title,
  p.location,
  p.scheduled_at,
  p.status,
  p.organizer_id,
  p.participant_id,
  o.name as organizer_name,
  part.name as participant_name
FROM playdates p
LEFT JOIN users o ON p.organizer_id = o.id
LEFT JOIN users part ON p.participant_id = part.id
WHERE p.scheduled_at > NOW()
ORDER BY p.scheduled_at;

-- Check playdate requests
SELECT 
  pr.id,
  pr.status,
  pr.message,
  req.name as requester_name,
  inv.name as invitee_name,
  p.title as playdate_title
FROM playdate_requests pr
JOIN users req ON pr.requester_id = req.id
JOIN users inv ON pr.invitee_id = inv.id
JOIN playdates p ON pr.playdate_id = p.id
WHERE pr.status = 'pending';
