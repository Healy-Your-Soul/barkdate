-- Run this in Supabase SQL Editor to check FCM tokens and test notifications

-- Step 1: Check which users have FCM tokens
SELECT 
  id, 
  name, 
  email, 
  CASE 
    WHEN fcm_token IS NULL THEN '❌ No token'
    WHEN fcm_token = '' THEN '❌ Empty token'
    ELSE '✅ Has token: ' || LEFT(fcm_token, 20) || '...'
  END as fcm_status,
  updated_at
FROM users 
WHERE fcm_token IS NOT NULL AND fcm_token != ''
ORDER BY updated_at DESC
LIMIT 10;

-- Step 2: Get your user's FCM token (replace with your email)
-- SELECT id, name, fcm_token FROM users WHERE email = 'your-email@example.com';

-- Step 3: Create a test notification (replace user_id with the target user's ID)
-- INSERT INTO notifications (user_id, title, body, type, is_read, created_at)
-- VALUES (
--   'YOUR-USER-ID-HERE',
--   '🐕 Test Notification',
--   'If you see this, in-app notifications work!',
--   'bark',
--   false,
--   NOW()
-- );
