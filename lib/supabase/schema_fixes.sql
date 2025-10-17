-- Schema Fixes for BarkDate
-- Sprint 1.1: Fix Missing Columns

-- Add created_at to event_participants table
ALTER TABLE event_participants 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add fcm_token to users table for push notifications
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Add requester_dog_id to playdate_requests if missing
ALTER TABLE playdate_requests 
ADD COLUMN IF NOT EXISTS requester_dog_id UUID REFERENCES dogs(id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_event_participants_created_at ON event_participants(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_playdate_requests_requester_dog ON playdate_requests(requester_dog_id);

-- Update existing event_participants with created_at from events table if needed
UPDATE event_participants ep
SET created_at = e.created_at
FROM events e
WHERE ep.event_id = e.id 
AND ep.created_at IS NULL;
