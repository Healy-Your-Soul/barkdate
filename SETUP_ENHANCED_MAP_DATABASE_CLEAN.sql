-- =================================================================
-- BARKDATE ENHANCED MAP & ADMIN FEATURES - DATABASE SCHEMA (CLEAN)
-- =================================================================
-- Run these commands in your Supabase SQL Editor

-- 0. ENABLE REQUIRED EXTENSIONS
-- -----------------------------
-- Enable PostGIS extension for location functions
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable earthdistance extension for distance calculations
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;

-- 1. CREATE FEATURED PARKS TABLE (Admin-curated parks)
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS featured_parks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  address TEXT,
  amenities TEXT[] DEFAULT '{}', -- Array of amenities
  rating DECIMAL(2,1) CHECK (rating >= 1.0 AND rating <= 5.0),
  photo_urls TEXT[] DEFAULT '{}', -- Array of photo URLs
  google_place_data JSONB, -- Store Google Places API data
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. CREATE PARK CHECKINS TABLE (Live dog tracking)
-- -------------------------------------------------
CREATE TABLE IF NOT EXISTS park_checkins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  dog_id UUID REFERENCES dogs(id) ON DELETE CASCADE,
  park_id UUID, -- Can reference either parks or featured_parks
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  checked_in_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  checked_out_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. ADD ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------

-- Enable RLS on tables
ALTER TABLE featured_parks ENABLE ROW LEVEL SECURITY;
ALTER TABLE park_checkins ENABLE ROW LEVEL SECURITY;

-- Featured Parks Policies
-- Anyone can read active featured parks
DO $$ BEGIN
  CREATE POLICY "Anyone can view active featured parks" ON featured_parks
    FOR SELECT USING (is_active = true);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Only authenticated users can insert (we'll add admin role later)
DO $$ BEGIN
  CREATE POLICY "Authenticated users can create featured parks" ON featured_parks
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Only creators can update their featured parks
DO $$ BEGIN
  CREATE POLICY "Creators can update their featured parks" ON featured_parks
    FOR UPDATE USING (auth.uid() = created_by);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Only creators can delete their featured parks
DO $$ BEGIN
  CREATE POLICY "Creators can delete their featured parks" ON featured_parks
    FOR DELETE USING (auth.uid() = created_by);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Park Checkins Policies
-- Users can read all active checkins (for dog counts)
DO $$ BEGIN
  CREATE POLICY "Anyone can view active checkins" ON park_checkins
    FOR SELECT USING (is_active = true);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Users can only insert their own checkins
DO $$ BEGIN
  CREATE POLICY "Users can create their own checkins" ON park_checkins
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Users can only update their own checkins
DO $$ BEGIN
  CREATE POLICY "Users can update their own checkins" ON park_checkins
    FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 4. CREATE INDEXES FOR PERFORMANCE
-- ---------------------------------

-- Index for location-based queries on featured parks (using standard lat/lng indexing)
CREATE INDEX IF NOT EXISTS idx_featured_parks_location 
ON featured_parks(latitude, longitude);

-- Index for active featured parks
CREATE INDEX IF NOT EXISTS idx_featured_parks_active 
ON featured_parks(is_active) WHERE is_active = true;

-- Index for active park checkins (for real-time dog counts)
CREATE INDEX IF NOT EXISTS idx_park_checkins_active 
ON park_checkins(park_id, is_active) WHERE is_active = true;

-- Index for user's active checkins
CREATE INDEX IF NOT EXISTS idx_park_checkins_user_active 
ON park_checkins(user_id, is_active) WHERE is_active = true;

-- 5. CREATE FUNCTIONS FOR AUTOMATED CLEANUP
-- -----------------------------------------

-- Function to automatically check out users after 12 hours
CREATE OR REPLACE FUNCTION auto_checkout_stale_checkins()
RETURNS void AS $$
BEGIN
  UPDATE park_checkins 
  SET is_active = false, 
      checked_out_at = NOW()
  WHERE is_active = true 
    AND checked_in_at < NOW() - INTERVAL '12 hours';
END;
$$ LANGUAGE plpgsql;

-- 6. CREATE TRIGGERS FOR AUTOMATIC UPDATES
-- ----------------------------------------

-- Trigger to update updated_at on featured_parks
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists and recreate it
DROP TRIGGER IF EXISTS update_featured_parks_updated_at ON featured_parks;
CREATE TRIGGER update_featured_parks_updated_at 
  BEFORE UPDATE ON featured_parks
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- 7. SCHEDULE AUTOMATIC CLEANUP (Run this in Supabase Dashboard > Database > Extensions)
-- -------------------------------------------------------------------------------------
-- Enable pg_cron extension for scheduled tasks
-- SELECT cron.schedule('auto-checkout-stale-checkins', '0 */6 * * *', 'SELECT auto_checkout_stale_checkins();');

-- =================================================================
-- SETUP COMPLETE! 
-- =================================================================

-- Next steps:
-- 1. Run all the above SQL in your Supabase SQL Editor
-- 2. Enable real-time subscriptions for park_checkins table in Supabase Dashboard
-- 3. Set up Google Places API key in your environment
-- 4. Test the admin interface at yourdomain.com/#/admin
-- 5. Add featured parks through the admin interface

-- Real-time Setup Instructions:
-- 1. Go to Supabase Dashboard > API > Realtime
-- 2. Add "park_checkins" to the realtime tables
-- 3. Save changes

-- To add your first featured park via SQL (optional):
-- INSERT INTO featured_parks (name, description, latitude, longitude, address, amenities, rating) 
-- VALUES ('Your Local Dog Park', 'A great local dog park', 40.7831, -73.9712, 'Your Address', ARRAY['off_leash_area'], 4.5);

COMMENT ON TABLE featured_parks IS 'Admin-curated featured dog parks with enhanced details and amenities';
COMMENT ON TABLE park_checkins IS 'Real-time tracking of dogs checked into parks for live counts and social features';
