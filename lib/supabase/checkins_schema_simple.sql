-- Check-ins Database Schema for BarkDate (Simple Install)
-- This script creates everything fresh, handling dependencies properly

-- Step 1: Create the checkins table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  park_id text NOT NULL, -- Changed to text to avoid parks table dependency
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

-- Step 2: Create indexes (if they don't exist)
CREATE INDEX IF NOT EXISTS idx_checkins_user_id ON checkins(user_id);
CREATE INDEX IF NOT EXISTS idx_checkins_park_id ON checkins(park_id);
CREATE INDEX IF NOT EXISTS idx_checkins_status ON checkins(status);
CREATE INDEX IF NOT EXISTS idx_checkins_checked_in_at ON checkins(checked_in_at);
CREATE INDEX IF NOT EXISTS idx_checkins_scheduled_for ON checkins(scheduled_for);

-- Step 3: Create or replace functions
CREATE OR REPLACE FUNCTION get_park_dog_count(park_uuid text)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::integer
    FROM checkins
    WHERE park_id = park_uuid
    AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_active_checkin(user_uuid uuid)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT row_to_json(c.*) INTO result
  FROM checkins c
  WHERE user_id = user_uuid
  AND status = 'active'
  ORDER BY checked_in_at DESC
  LIMIT 1;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION update_checkins_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Drop trigger if exists, then create
DROP TRIGGER IF EXISTS checkins_updated_at ON checkins;
CREATE TRIGGER checkins_updated_at
  BEFORE UPDATE ON checkins
  FOR EACH ROW
  EXECUTE FUNCTION update_checkins_updated_at();

-- Step 5: Enable Row Level Security
ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;

-- Step 6: Drop existing policies if they exist, then create new ones
DROP POLICY IF EXISTS "Users can view their own check-ins" ON checkins;
CREATE POLICY "Users can view their own check-ins" ON checkins
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view park check-in counts" ON checkins;
CREATE POLICY "Users can view park check-in counts" ON checkins
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create their own check-ins" ON checkins;
CREATE POLICY "Users can create their own check-ins" ON checkins
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own check-ins" ON checkins;
CREATE POLICY "Users can update their own check-ins" ON checkins
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own check-ins" ON checkins;
CREATE POLICY "Users can delete their own check-ins" ON checkins
  FOR DELETE USING (auth.uid() = user_id);

-- Step 7: Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON checkins TO authenticated;
GRANT EXECUTE ON FUNCTION get_park_dog_count(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_active_checkin(uuid) TO authenticated;
