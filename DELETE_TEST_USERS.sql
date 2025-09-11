-- Delete Test Users Script
-- Run this in your Supabase SQL Editor to clean up test data

-- 1. First, let's see what users we have
SELECT id, email, name, created_at FROM public.users ORDER BY created_at;

-- 2. Delete specific test users by email
DELETE FROM public.users 
WHERE email IN (
    'thechenmor@gmail.com',
    'chen.mor@proqure.io'
);

-- 3. If you want to delete ALL users and start fresh (be careful!)
-- Uncomment the line below only if you want to delete EVERYTHING
-- DELETE FROM public.users;

-- 4. Also clean up any related data in other tables
-- Delete dogs associated with these users (if any)
DELETE FROM public.dogs 
WHERE user_id IN (
    'c427c572-e79b-4dbe-aa90-f0abad80090d',
    'bd20b2dd-a970-4677-9739-6f7be4682473'
);

-- 5. Delete any playdates created by these users (if any)
DELETE FROM public.playdates 
WHERE creator_id IN (
    'c427c572-e79b-4dbe-aa90-f0abad80090d',
    'bd20b2dd-a970-4677-9739-6f7be4682473'
);

-- 6. Delete any user avatars from storage (note: this removes the database records, 
-- you may need to manually delete files from storage bucket)
DELETE FROM storage.objects 
WHERE bucket_id = 'user-avatars' 
AND path_tokens[1] IN (
    'c427c572-e79b-4dbe-aa90-f0abad80090d',
    'bd20b2dd-a970-4677-9739-6f7be4682473'
);

-- 7. Verify deletion
SELECT id, email, name, created_at FROM public.users ORDER BY created_at;

-- 8. Check if any related data remains
SELECT COUNT(*) as remaining_dogs FROM public.dogs;
SELECT COUNT(*) as remaining_playdates FROM public.playdates;
