-- Apple Demo Account for App Store Review
-- Run this in Supabase SQL Editor

-- NOTE: Supabase uses a managed auth system, so you should create 
-- the demo user through the Supabase dashboard or Auth API instead.
-- 
-- RECOMMENDED APPROACH:
-- 1. Go to Supabase Dashboard > Authentication > Users
-- 2. Click "Add User" > "Create New User"
-- 3. Email: apple-reviewer@barkdate.app
-- 4. Password: BarkDemo2024!
-- 5. Click "Auto Confirm User" checkbox
-- 6. After creating, copy the user UUID and use it below

-- Replace 'YOUR_USER_UUID_HERE' with the actual UUID from step 6 above
DO $$
DECLARE
  demo_user_id UUID := '1c38db8d-8ce5-4fdf-b30f-3e37b50ce34c'; -- REPLACE THIS after creating user in dashboard
  demo_dog_id UUID := gen_random_uuid();
BEGIN
  -- Create user profile in public.users table
  INSERT INTO users (id, email, name, avatar_url, created_at)
  VALUES (
    demo_user_id,
    'apple-reviewer@barkdate.app',
    'Demo User',
    NULL,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  -- Create demo dog profile
  INSERT INTO dogs (
    id, 
    user_id, 
    name, 
    breed, 
    age, 
    size, 
    gender, 
    bio, 
    main_photo_url, 
    is_active,
    created_at
  )
  VALUES (
    demo_dog_id,
    demo_user_id,
    'Buddy',
    'Golden Retriever',
    3,
    'Large',
    'Male',
    'Hi! I''m Buddy, a friendly demo dog. I love making new friends at the park! 🐕',
    'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400',
    true,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  
  RAISE NOTICE 'Demo account created successfully!';
  RAISE NOTICE 'User ID: %', demo_user_id;
  RAISE NOTICE 'Dog ID: %', demo_dog_id;
END $$;
