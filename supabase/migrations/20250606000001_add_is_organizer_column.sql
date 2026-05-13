-- Add missing columns to playdate_participants table
-- These columns are expected by the Dart code but don't exist in the schema

-- Add is_organizer column (boolean) - indicates if this participant is the playdate organizer
ALTER TABLE playdate_participants 
ADD COLUMN IF NOT EXISTS is_organizer BOOLEAN DEFAULT false;

-- Add status column (text) - participant status: pending, confirmed, declined
ALTER TABLE playdate_participants 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'declined'));


-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_playdate_participants_is_organizer 
ON playdate_participants(is_organizer);
