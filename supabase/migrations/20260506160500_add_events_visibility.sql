-- Add visibility column to events table to fix PostgREST errors
ALTER TABLE events ADD COLUMN IF NOT EXISTS visibility TEXT DEFAULT 'public';

-- Optional: If you had an old is_public column, you can backfill:
-- UPDATE events SET visibility = 'public' WHERE is_public = true;
-- UPDATE events SET visibility = 'invite_only' WHERE is_public = false;
