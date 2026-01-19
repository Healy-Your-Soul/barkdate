-- Add is_organizer column to playdate_participants
-- This column was expected by the code but not in the database

ALTER TABLE playdate_participants 
ADD COLUMN IF NOT EXISTS is_organizer BOOLEAN DEFAULT false;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_playdate_participants_is_organizer 
ON playdate_participants(is_organizer);
