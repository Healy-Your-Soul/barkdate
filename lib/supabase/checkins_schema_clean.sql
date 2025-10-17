-- Check-ins Database Schema for BarkDate (Clean Install)
-- This script safely drops and recreates the check-ins feature

-- Drop existing indexes first (if they exist)
DROP INDEX IF EXISTS idx_checkins_user_id;
DROP INDEX IF EXISTS idx_checkins_park_id;
DROP INDEX IF EXISTS idx_checkins_status;
DROP INDEX IF EXISTS idx_checkins_checked_in_at;
DROP INDEX IF EXISTS idx_checkins_scheduled_for;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS checkins_updated_at ON checkins;
DROP FUNCTION IF EXISTS update_checkins_updated_at();
DROP FUNCTION IF EXISTS get_park_dog_count(uuid);
DROP FUNCTION IF EXISTS get_user_active_checkin(uuid);
DROP FUNCTION IF EXISTS auto_checkout_old_checkins();

-- Drop existing views
DROP VIEW IF EXISTS park_activity_summary;

-- Drop existing table (if it exists)
DROP TABLE IF EXISTS checkins CASCADE;

-- Create the checkins table
CREATE TABLE checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  park_id uuid NOT NULL REFERENCES parks(id) ON DELETE CASCADE,
  park_name text NOT NULL,
  checked_in_at timestamp with time zone NOT NULL DEFAULT now(),
  checked_out_at timestamp with time zone,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'scheduled')),
  is_future_checkin boolean DEFAULT false,
  scheduled_for timestamp with time zone,
  latitude double precision,
  longitude double precision,
  checkin_method text DEFAULT 'manual' CHECK (checkin_method IN ('manual', 'gps', 'qr', 'nfc')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX idx_checkins_user_id ON checkins(user_id);
CREATE INDEX idx_checkins_park_id ON checkins(park_id);
CREATE INDEX idx_checkins_status ON checkins(status);
CREATE INDEX idx_checkins_checked_in_at ON checkins(checked_in_at);
CREATE INDEX idx_checkins_scheduled_for ON checkins(scheduled_for);

-- Function to get current dog count at a park
CREATE OR REPLACE FUNCTION get_park_dog_count(park_uuid uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM checkins
    WHERE park_id = park_uuid
    AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get user's active check-in
CREATE OR REPLACE FUNCTION get_user_active_checkin(user_uuid uuid)
RETURNS checkins AS $$
DECLARE
  result checkins;
BEGIN
  SELECT * INTO result
  FROM checkins
  WHERE user_id = user_uuid
  AND status = 'active'
  ORDER BY checked_in_at DESC
  LIMIT 1;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-checkout old check-ins
CREATE OR REPLACE FUNCTION auto_checkout_old_checkins()
RETURNS void AS $$
BEGIN
  UPDATE checkins
  SET checked_out_at = now(),
      status = 'completed',
      updated_at = now()
  WHERE status = 'active'
  AND checked_in_at < now() - interval '4 hours';
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_checkins_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER checkins_updated_at
  BEFORE UPDATE ON checkins
  FOR EACH ROW
  EXECUTE FUNCTION update_checkins_updated_at();

-- Enable Row Level Security
ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;

-- RLS Policies for checkins table
CREATE POLICY "Users can view their own check-ins" ON checkins
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view park check-in counts" ON checkins
  FOR SELECT USING (true);

CREATE POLICY "Users can create their own check-ins" ON checkins
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own check-ins" ON checkins
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own check-ins" ON checkins
  FOR DELETE USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON checkins TO authenticated;
GRANT EXECUTE ON FUNCTION get_park_dog_count(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_active_checkin(uuid) TO authenticated;

-- Create a view for park activity summary
CREATE VIEW park_activity_summary AS
SELECT 
  p.id as park_id,
  p.name as park_name,
  COUNT(c.id) as current_dog_count,
  COUNT(CASE WHEN c.checked_in_at >= now() - interval '24 hours' THEN 1 END) as checkins_last_24h,
  COUNT(CASE WHEN c.checked_in_at >= now() - interval '7 days' THEN 1 END) as checkins_last_week
FROM parks p
LEFT JOIN checkins c ON p.id = c.park_id AND c.status = 'active'
GROUP BY p.id, p.name;

-- Grant access to the view
GRANT SELECT ON park_activity_summary TO authenticated;

-- Insert sample data for testing (optional - uncomment if needed)
/*
INSERT INTO checkins (user_id, dog_id, park_id, park_name, status, checked_in_at)
SELECT 
  u.id,
  d.id,
  p.id,
  p.name,
  'active',
  now() - interval '1 hour'
FROM users u
CROSS JOIN dogs d
CROSS JOIN parks p
WHERE u.id = d.user_id
LIMIT 5;
*/
