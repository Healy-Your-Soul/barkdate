-- Safe migration to add missing columns to existing tables
-- This will NOT fail if tables already exist

-- Add created_at to event_participants table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'event_participants' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE event_participants ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    
    -- Update existing rows with event's created_at
    UPDATE event_participants ep
    SET created_at = e.created_at
    FROM events e
    WHERE ep.event_id = e.id AND ep.created_at IS NULL;
  END IF;
END $$;

-- Add fcm_token to users table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'fcm_token'
  ) THEN
    ALTER TABLE users ADD COLUMN fcm_token TEXT;
  END IF;
END $$;

-- Add requester_dog_id to playdate_requests if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'playdate_requests' AND column_name = 'requester_dog_id'
  ) THEN
    ALTER TABLE playdate_requests ADD COLUMN requester_dog_id UUID REFERENCES dogs(id);
  END IF;
END $$;

-- Create indexes for performance (will skip if already exist)
CREATE INDEX IF NOT EXISTS idx_event_participants_created_at ON event_participants(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_playdate_requests_requester_dog ON playdate_requests(requester_dog_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON event_participants TO authenticated;
GRANT SELECT, UPDATE ON users TO authenticated;
