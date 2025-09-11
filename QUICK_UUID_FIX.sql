-- Quick fix for the users table ID constraint
-- Run this in your Supabase SQL Editor

-- Option 1: Make the id field auto-generate UUIDs (RECOMMENDED)
ALTER TABLE public.users 
ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- Option 2: Allow NULL ids and use email as primary identifier
-- (Uncomment this if Option 1 doesn't work)
-- ALTER TABLE public.users ALTER COLUMN id DROP NOT NULL;

-- Check the current table structure
\d public.users;
