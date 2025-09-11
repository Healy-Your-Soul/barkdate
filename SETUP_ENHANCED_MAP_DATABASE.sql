-- =================================================================
-- BARKDATE ENHANCED MAP & ADMIN FEATURES - DATABASE SCHEMA
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
CREATE POLICY "Anyone can view active featured parks" ON featured_parks
  FOR SELECT USING (is_active = true);

-- Only authenticated users can insert (we'll add admin role later)
CREATE POLICY "Authenticated users can create featured parks" ON featured_parks
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Only creators can update their featured parks
CREATE POLICY "Creators can update their featured parks" ON featured_parks
  FOR UPDATE USING (auth.uid() = created_by);

-- Only creators can delete their featured parks
CREATE POLICY "Creators can delete their featured parks" ON featured_parks
  FOR DELETE USING (auth.uid() = created_by);

-- Park Checkins Policies
-- Users can read all active checkins (for dog counts)
CREATE POLICY "Anyone can view active checkins" ON park_checkins
  FOR SELECT USING (is_active = true);

-- Users can only insert their own checkins
CREATE POLICY "Users can create their own checkins" ON park_checkins
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own checkins
CREATE POLICY "Users can update their own checkins" ON park_checkins
  FOR UPDATE USING (auth.uid() = user_id);

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

CREATE TRIGGER update_featured_parks_updated_at 
  BEFORE UPDATE ON featured_parks
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- 7. INSERT SAMPLE DATA (Optional)
-- --------------------------------

-- Sample featured parks (you can customize these)
INSERT INTO featured_parks (name, description, latitude, longitude, address, amenities, rating) VALUES
('Central Bark Dog Park', 'A premium off-leash dog park in the heart of the city with agility equipment and separate areas for small and large dogs.', 40.7831, -73.9712, '123 Central Park West, New York, NY 10025', ARRAY['off_leash_area', 'agility_equipment', 'separate_small_dog_area', 'water_fountain', 'waste_stations', 'benches'], 4.5),
('Riverside Dog Run', 'Scenic waterfront dog park with stunning river views and plenty of space for dogs to run and play.', 40.7589, -73.9851, '456 Riverside Drive, New York, NY 10027', ARRAY['off_leash_area', 'water_access', 'shade_trees', 'parking', 'benches'], 4.2),
('Brooklyn Bridge Park Dog Run', 'Modern dog park with Manhattan skyline views, featuring separate areas and excellent facilities.', 40.7024, -73.9875, '789 Brooklyn Bridge Park, Brooklyn, NY 11201', ARRAY['off_leash_area', 'separate_small_dog_area', 'water_fountain', 'waste_stations', 'lighting'], 4.7)
ON CONFLICT DO NOTHING;

-- 8. SCHEDULE AUTOMATIC CLEANUP (Run this in Supabase Dashboard > Database > Extensions)
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
-- 5. Add more featured parks through the admin interface

-- Real-time Setup Instructions:
-- 1. Go to Supabase Dashboard > API > Realtime
-- 2. Add "park_checkins" to the realtime tables
-- 3. Save changes

COMMENT ON TABLE featured_parks IS 'Admin-curated featured dog parks with enhanced details and amenities';
COMMENT ON TABLE park_checkins IS 'Real-time tracking of dogs checked into parks for live counts and social features';
