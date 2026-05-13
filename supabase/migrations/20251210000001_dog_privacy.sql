-- =====================================================
-- BARKDATE: Dog Privacy & Friendship Enhancements
-- Run this in Supabase SQL Editor (Dashboard > SQL)
-- =====================================================
-- This migration adds:
-- 1. Privacy setting to dogs table (is_public)
-- =====================================================

-- =====================================================
-- PART 1: Add Privacy Column to Dogs Table
-- =====================================================

-- Add is_public column to dogs table (default true = discoverable)
ALTER TABLE dogs 
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;

-- Add column comment
COMMENT ON COLUMN dogs.is_public IS 'If true, dog is discoverable in nearby searches and check-in lists. If false, dog is private.';

-- =====================================================
-- PART 2: Ensure dog_friendships has proper status
-- =====================================================

-- Add status column if it doesn't exist (for friend requests)
ALTER TABLE dog_friendships 
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'accepted';

-- Status can be: 'pending', 'accepted', 'declined'
COMMENT ON COLUMN dog_friendships.status IS 'Friend request status: pending, accepted, declined';

-- Add requested_by to track who initiated
ALTER TABLE dog_friendships 
ADD COLUMN IF NOT EXISTS requested_by_user_id UUID REFERENCES auth.users(id);

-- =====================================================
-- PART 3: Update RLS for public/private dogs
-- =====================================================

-- Drop old policy
DROP POLICY IF EXISTS "Anyone can view public dogs" ON dogs;

-- Create new policy: Users can see their own dogs + all public dogs
-- Using user_id (not owner_id) to match actual schema
CREATE POLICY "Anyone can view public dogs" ON dogs
  FOR SELECT USING (
    user_id = auth.uid() 
    OR is_public = true 
    OR is_public IS NULL  -- Legacy dogs without setting = public
  );

-- =====================================================
-- DONE!
-- =====================================================
SELECT 'Dog privacy migration completed!' AS result;
