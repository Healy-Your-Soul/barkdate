-- ============================================
-- AMENITIES SYSTEM MIGRATION
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Master amenities table (admin-editable list of available amenities)
CREATE TABLE IF NOT EXISTS amenities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  icon TEXT, -- emoji or icon name
  category TEXT DEFAULT 'general', -- 'comfort', 'safety', 'facilities', etc.
  is_active BOOLEAN DEFAULT true,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Place amenities (which amenities are at each place, with counts)
CREATE TABLE IF NOT EXISTS place_amenities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id TEXT NOT NULL,
  amenity_id UUID REFERENCES amenities(id) ON DELETE CASCADE,
  suggested_count INT DEFAULT 1,
  last_suggested_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(place_id, amenity_id)
);

-- 3. User amenity suggestions (tracks who suggested what, prevents duplicates)
CREATE TABLE IF NOT EXISTS amenity_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amenity_id UUID REFERENCES amenities(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(place_id, user_id, amenity_id)
);

-- 4. Insert default amenities
INSERT INTO amenities (name, icon, category, display_order) VALUES
  ('Dog Water Bowls', '🚰', 'facilities', 1),
  ('Shaded Areas', '🌳', 'comfort', 2),
  ('Off-Leash Area', '🐕', 'safety', 3),
  ('Fenced', '🚧', 'safety', 4),
  ('Benches', '🪑', 'comfort', 5),
  ('Restrooms', '🚻', 'facilities', 6),
  ('Poop Bags', '🛍️', 'facilities', 7),
  ('Parking', '🅿️', 'facilities', 8),
  ('Dog-Friendly Patio', '🏖️', 'comfort', 9),
  ('Treats Available', '🦴', 'facilities', 10)
ON CONFLICT (name) DO NOTHING;

-- 5. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_place_amenities_place_id ON place_amenities(place_id);
CREATE INDEX IF NOT EXISTS idx_amenity_suggestions_place_id ON amenity_suggestions(place_id);
CREATE INDEX IF NOT EXISTS idx_amenity_suggestions_user_id ON amenity_suggestions(user_id);

-- 6. RLS Policies
ALTER TABLE amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE place_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE amenity_suggestions ENABLE ROW LEVEL SECURITY;

-- Amenities: Anyone can read, only admins can modify
CREATE POLICY "Anyone can read amenities" ON amenities
  FOR SELECT USING (true);

-- Place amenities: Anyone can read
CREATE POLICY "Anyone can read place amenities" ON place_amenities
  FOR SELECT USING (true);

-- Place amenities: Authenticated users can insert/update (via function)
CREATE POLICY "Authenticated users can suggest amenities" ON place_amenities
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "System can update place amenities" ON place_amenities
  FOR UPDATE USING (true);

-- Amenity suggestions: Users can see their own
CREATE POLICY "Users can see own suggestions" ON amenity_suggestions
  FOR SELECT USING (auth.uid() = user_id);

-- Amenity suggestions: Users can insert their own
CREATE POLICY "Users can add suggestions" ON amenity_suggestions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 7. Function to suggest amenity (handles upsert logic)
CREATE OR REPLACE FUNCTION suggest_amenity(
  p_place_id TEXT,
  p_amenity_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID;
  v_already_suggested BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated';
  END IF;
  
  -- Check if user already suggested this amenity for this place
  SELECT EXISTS(
    SELECT 1 FROM amenity_suggestions 
    WHERE place_id = p_place_id 
      AND user_id = v_user_id 
      AND amenity_id = p_amenity_id
  ) INTO v_already_suggested;
  
  IF v_already_suggested THEN
    RETURN FALSE; -- Already suggested
  END IF;
  
  -- Record the suggestion
  INSERT INTO amenity_suggestions (place_id, user_id, amenity_id)
  VALUES (p_place_id, v_user_id, p_amenity_id);
  
  -- Upsert into place_amenities
  INSERT INTO place_amenities (place_id, amenity_id, suggested_count, last_suggested_at)
  VALUES (p_place_id, p_amenity_id, 1, NOW())
  ON CONFLICT (place_id, amenity_id) 
  DO UPDATE SET 
    suggested_count = place_amenities.suggested_count + 1,
    last_suggested_at = NOW(),
    updated_at = NOW();
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Function to get amenities for a place (with counts)
CREATE OR REPLACE FUNCTION get_place_amenities(p_place_id TEXT)
RETURNS TABLE (
  amenity_id UUID,
  name TEXT,
  icon TEXT,
  suggested_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id,
    a.name,
    a.icon,
    COALESCE(pa.suggested_count, 0)::INT
  FROM amenities a
  LEFT JOIN place_amenities pa ON a.id = pa.amenity_id AND pa.place_id = p_place_id
  WHERE a.is_active = true
  ORDER BY COALESCE(pa.suggested_count, 0) DESC, a.display_order;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION suggest_amenity TO authenticated;
GRANT EXECUTE ON FUNCTION get_place_amenities TO authenticated, anon;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT 'Amenities tables created successfully!' AS status;
