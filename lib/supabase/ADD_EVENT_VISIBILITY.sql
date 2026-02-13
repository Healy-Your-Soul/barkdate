-- ============================================
-- ADD VISIBILITY COLUMN TO EVENTS
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Add visibility column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'events' AND column_name = 'visibility') THEN
        ALTER TABLE events ADD COLUMN visibility TEXT DEFAULT 'public';
        
        -- 2. Migrate existing data
        -- is_public = true -> 'public'
        -- is_public = false -> 'invite_only'
        UPDATE events 
        SET visibility = CASE 
            WHEN is_public = true THEN 'public' 
            ELSE 'invite_only' 
        END;
    END IF;
END $$;

-- 3. Create index for performance
CREATE INDEX IF NOT EXISTS idx_events_visibility ON events(visibility);
