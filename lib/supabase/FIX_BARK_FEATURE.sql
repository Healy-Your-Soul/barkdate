-- ============================================
-- FIX BARK FEATURE (Revised)
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. DROP EXISTING POLICIES FIRST (To avoid dependency errors)
DROP POLICY IF EXISTS "Users can view friendships of their dogs" ON dog_friendships;
DROP POLICY IF EXISTS "Users can create friendships for their dogs" ON dog_friendships;
DROP POLICY IF EXISTS "Users can view friendships for their dogs" ON dog_friendships;
DROP POLICY IF EXISTS "Users can view their dogs friendships" ON dog_friendships;
DROP POLICY IF EXISTS "Users can delete their dogs friendships" ON dog_friendships;
DROP POLICY IF EXISTS "Anyone can read friendships" ON dog_friendships;
DROP POLICY IF EXISTS "Authenticated users can insert friendships" ON dog_friendships;
DROP POLICY IF EXISTS "Authenticated users can update friendships" ON dog_friendships;

-- 2. FIX TABLE STRUCTURE
-- Only now safe to alter columns
DO $$ 
BEGIN
    -- Check if 'dog1_id' exists (old schema)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dog_friendships' AND column_name = 'dog1_id') THEN
        -- Using CASCADE to be safe, though policies are already dropped
        ALTER TABLE dog_friendships DROP COLUMN IF EXISTS dog1_id CASCADE;
        ALTER TABLE dog_friendships DROP COLUMN IF EXISTS dog2_id CASCADE;
        DELETE FROM dog_friendships; -- Clear bad data
    END IF;

    -- Add 'dog_id' if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dog_friendships' AND column_name = 'dog_id') THEN
        ALTER TABLE dog_friendships ADD COLUMN dog_id UUID REFERENCES dogs(id) ON DELETE CASCADE;
    END IF;

    -- Add 'friend_dog_id' if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dog_friendships' AND column_name = 'friend_dog_id') THEN
        ALTER TABLE dog_friendships ADD COLUMN friend_dog_id UUID REFERENCES dogs(id) ON DELETE CASCADE;
    END IF;

    -- Add 'status' if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dog_friendships' AND column_name = 'status') THEN
        ALTER TABLE dog_friendships ADD COLUMN status TEXT DEFAULT 'pending';
    END IF;
END $$;

-- 3. ENABLE RLS
ALTER TABLE dog_friendships ENABLE ROW LEVEL SECURITY;

-- 4. CREATE PERMISSIVE POLICIES

-- Allow anyone to read friendships
CREATE POLICY "Anyone can read friendships" ON dog_friendships
    FOR SELECT USING (true);

-- Allow authenticated users to insert
CREATE POLICY "Authenticated users can insert friendships" ON dog_friendships
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow authenticated users to update
CREATE POLICY "Authenticated users can update friendships" ON dog_friendships
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Allow authenticated users to delete
CREATE POLICY "Authenticated users can delete friendships" ON dog_friendships
    FOR DELETE USING (auth.role() = 'authenticated');

-- 5. GRANT PERMISSIONS
GRANT ALL ON dog_friendships TO authenticated;
GRANT ALL ON dog_friendships TO anon;

-- 6. RECREATE INDEXES
DROP INDEX IF EXISTS idx_dog_friendships_dogs; -- Drop old index
CREATE INDEX IF NOT EXISTS idx_dog_friendships_dog_id ON dog_friendships(dog_id);
CREATE INDEX IF NOT EXISTS idx_dog_friendships_friend_dog_id ON dog_friendships(friend_dog_id);
