-- Insert sample data into BarkDate database

-- Helper function to insert users into auth.users and return their UUID
CREATE OR REPLACE FUNCTION insert_user_to_auth(user_email text, user_password text)
RETURNS uuid AS $$
DECLARE
  user_id uuid;
BEGIN
  INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES (
    (SELECT id FROM auth.instances LIMIT 1),
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    user_email,
    crypt(user_password, gen_salt('bf')),
    now(),
    now(),
    now()
  )
  RETURNING id INTO user_id;
  RETURN user_id;
END;
$$ LANGUAGE plpgsql;

-- 1. Insert Users (and auth.users)
INSERT INTO users (id, email, name, avatar_url, bio, location, is_premium, premium_expires_at)
SELECT
  insert_user_to_auth('alice@example.com', 'password123'),
  'alice@example.com',
  'Alice Smith',
  'https://example.com/avatars/alice.jpg',
  'Dog lover and avid hiker. Looking for playdates for my energetic Golden Retriever!',
  'New York, NY',
  true,
  now() + INTERVAL '1 year'
UNION ALL
SELECT
  insert_user_to_auth('bob@example.com', 'password123'),
  'bob@example.com',
  'Bob Johnson',
  'https://example.com/avatars/bob.jpg',
  'Proud owner of a mischievous Beagle. Always up for a walk in the park!',
  'Los Angeles, CA',
  false,
  NULL
UNION ALL
SELECT
  insert_user_to_auth('charlie@example.com', 'password123'),
  'charlie@example.com',
  'Charlie Brown',
  'https://example.com/avatars/charlie.jpg',
  'My French Bulldog loves cuddles and short walks. Seeking calm playmates.',
  'Chicago, IL',
  true,
  now() + INTERVAL '6 months'
UNION ALL
SELECT
  insert_user_to_auth('diana@example.com', 'password123'),
  'diana@example.com',
  'Diana Prince',
  'https://example.com/avatars/diana.jpg',
  'Rescued a shy Greyhound. Hoping to help her socialize and build confidence.',
  'Austin, TX',
  false,
  NULL
UNION ALL
SELECT
  insert_user_to_auth('eve@example.com', 'password123'),
  'eve@example.com',
  'Eve Adams',
  'https://example.com/avatars/eve.jpg',
  'Owner of two playful Poodles. The more the merrier for playdates!',
  'Miami, FL',
  false,
  NULL;

-- 2. Insert Dogs
INSERT INTO dogs (user_id, name, breed, age, size, gender, photo_urls, bio, temperament, vaccinated, neutered, weight_kg)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'Buddy',
  'Golden Retriever',
  3,
  'Large',
  'Male',
  ARRAY['https://example.com/dogs/buddy1.jpg', 'https://example.com/dogs/buddy2.jpg'],
  'Buddy is a very friendly and energetic Golden Retriever. He loves to fetch and swim.',
  ARRAY['Friendly', 'Energetic', 'Playful'],
  true,
  true,
  30
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'Max',
  'Beagle',
  2,
  'Medium',
  'Male',
  ARRAY['https://example.com/dogs/max1.jpg'],
  'Max is a curious and mischievous Beagle. He loves sniffing out new adventures.',
  ARRAY['Curious', 'Mischievous', 'Loyal'],
  true,
  true,
  15
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'charlie@example.com'),
  'Bella',
  'French Bulldog',
  4,
  'Small',
  'Female',
  ARRAY['https://example.com/dogs/bella1.jpg', 'https://example.com/dogs/bella2.jpg'],
  'Bella is a sweet and calm French Bulldog. She enjoys short walks and lots of naps.',
  ARRAY['Calm', 'Affectionate', 'Gentle'],
  true,
  true,
  12
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  'Luna',
  'Greyhound',
  5,
  'Large',
  'Female',
  ARRAY['https://example.com/dogs/luna1.jpg'],
  'Luna is a rescued Greyhound, a bit shy but very loving once she trusts you. Needs gentle playmates.',
  ARRAY['Shy', 'Gentle', 'Fast'],
  true,
  true,
  28
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  'Daisy',
  'Poodle (Standard)',
  1,
  'Medium',
  'Female',
  ARRAY['https://example.com/dogs/daisy1.jpg'],
  'Daisy is a playful and intelligent Standard Poodle puppy. Loves to learn new tricks.',
  ARRAY['Playful', 'Intelligent', 'Energetic'],
  true,
  false,
  18
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  'Rocky',
  'Poodle (Miniature)',
  3,
  'Small',
  'Male',
  ARRAY['https://example.com/dogs/rocky1.jpg'],
  'Rocky is a friendly Miniature Poodle, always ready for a game of fetch.',
  ARRAY['Friendly', 'Playful', 'Loyal'],
  true,
  true,
  8;

-- 3. Insert Matches
INSERT INTO matches (user_id, target_user_id, dog_id, target_dog_id, action, is_mutual)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Buddy'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Max'),
  'bark',
  true
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Max'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Buddy'),
  'bark',
  true
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM users WHERE email = 'charlie@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Buddy'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com') AND name = 'Bella'),
  'bark',
  false
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'diana@example.com') AND name = 'Luna'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'eve@example.com') AND name = 'Daisy'),
  'bark',
  true
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'eve@example.com') AND name = 'Daisy'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'diana@example.com') AND name = 'Luna'),
  'bark',
  true;

-- 4. Insert Messages
INSERT INTO messages (match_id, sender_id, receiver_id, content)
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'bob@example.com')),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'Hey Bob! Buddy would love to meet Max for a playdate.'
UNION ALL
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'bob@example.com')),
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'Sounds great, Alice! Max is always up for new friends. When are you free?'
UNION ALL
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'diana@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'eve@example.com')),
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  'Hi Eve! Luna is a bit shy, but I think she''d enjoy a gentle playdate with Daisy.'
UNION ALL
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'diana@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'eve@example.com')),
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  'Absolutely! Daisy is very calm with other dogs. How about next Saturday at the park?'
UNION ALL
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'bob@example.com')),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'How about this Sunday afternoon at Central Park?'
UNION ALL
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'bob@example.com')),
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'Perfect! See you then!'
UNION ALL
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'diana@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'eve@example.com')),
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  'Next Saturday sounds great! Let''s meet at Zilker Park at 10 AM.'
UNION ALL
SELECT
  (SELECT id FROM matches WHERE user_id = (SELECT id FROM users WHERE email = 'diana@example.com') AND target_user_id = (SELECT id FROM users WHERE email = 'eve@example.com')),
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  'Confirmed! Looking forward to it!'
;

-- 5. Insert Playdates
INSERT INTO playdates (organizer_id, participant_id, title, description, location, latitude, longitude, scheduled_at, duration_minutes, max_dogs, status)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  'Buddy & Max Playdate',
  'A fun afternoon for Buddy and Max to run around and play fetch.',
  'Central Park, New York, NY',
  40.785091,
  -73.968285,
  now() + INTERVAL '3 days' + INTERVAL '14 hours',
  90,
  2,
  'confirmed'
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  'Luna & Daisy Gentle Meetup',
  'A calm playdate for Luna to socialize with the gentle Daisy.',
  'Zilker Park, Austin, TX',
  30.264167,
  -97.771111,
  now() + INTERVAL '7 days' + INTERVAL '10 hours',
  60,
  2,
  'confirmed'
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'charlie@example.com'),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  'Bella & Buddy Short Walk',
  'A short, relaxed walk for Bella and Buddy.',
  'Lincoln Park, Chicago, IL',
  41.9250,
  -87.6360,
  now() + INTERVAL '10 days' + INTERVAL '16 hours',
  45,
  2,
  'pending';

-- 6. Insert Playdate Participants
INSERT INTO playdate_participants (playdate_id, user_id, dog_id)
SELECT
  (SELECT id FROM playdates WHERE title = 'Buddy & Max Playdate'),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Buddy')
UNION ALL
SELECT
  (SELECT id FROM playdates WHERE title = 'Buddy & Max Playdate'),
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Max')
UNION ALL
SELECT
  (SELECT id FROM playdates WHERE title = 'Luna & Daisy Gentle Meetup'),
  (SELECT id FROM users WHERE email = 'diana@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'diana@example.com') AND name = 'Luna')
UNION ALL
SELECT
  (SELECT id FROM playdates WHERE title = 'Luna & Daisy Gentle Meetup'),
  (SELECT id FROM users WHERE email = 'eve@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'eve@example.com') AND name = 'Daisy')
UNION ALL
SELECT
  (SELECT id FROM playdates WHERE title = 'Bella & Buddy Short Walk'),
  (SELECT id FROM users WHERE email = 'charlie@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'charlie@example.com') AND name = 'Bella')
UNION ALL
SELECT
  (SELECT id FROM playdates WHERE title = 'Bella & Buddy Short Walk'),
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Buddy');

-- 7. Insert Posts
INSERT INTO posts (user_id, dog_id, content, image_urls, location, latitude, longitude, likes_count, comments_count)
SELECT
  (SELECT id FROM users WHERE email = 'alice@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'alice@example.com') AND name = 'Buddy'),
  'Buddy had a fantastic time at Central Park today! So much space to run.',
  ARRAY['https://example.com/posts/buddy_park.jpg'],
  'Central Park, New York',
  40.785091,
  -73.968285,
  5,
  2
UNION ALL
SELECT
  (SELECT id FROM users WHERE email = 'bob@example.com'),
  (SELECT id FROM dogs WHERE user_id = (SELECT id FROM users WHERE email = 'bob@example.com') AND name = 'Max'),
  'Max found the biggest stick ever on our morning walk! #