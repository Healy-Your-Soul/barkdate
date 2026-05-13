-- Dog Sharing Feature Migration

-- 1. New Table: dog_shares
CREATE TABLE IF NOT EXISTS dog_shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  dog_id UUID NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  shared_with_user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- NULL if pending
  share_code VARCHAR(8) UNIQUE NOT NULL, -- Random 8-char code
  access_level VARCHAR(20) NOT NULL CHECK (access_level IN ('view', 'edit', 'manage')),
  pin_code VARCHAR(6), -- Optional 6-digit PIN
  expires_at TIMESTAMP WITH TIME ZONE, -- NULL = never expires
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  accepted_at TIMESTAMP WITH TIME ZONE, -- NULL until accepted
  revoked_at TIMESTAMP WITH TIME ZONE, -- NULL unless revoked
  
  -- Metadata
  shared_via VARCHAR(20) CHECK (shared_via IN ('link', 'qr', 'whatsapp')),
  notes TEXT, -- Owner notes about this share
  
  UNIQUE(dog_id, shared_with_user_id)
);

-- Indexes for dog_shares
CREATE INDEX IF NOT EXISTS idx_dog_shares_dog_id ON dog_shares(dog_id);
CREATE INDEX IF NOT EXISTS idx_dog_shares_share_code ON dog_shares(share_code);
CREATE INDEX IF NOT EXISTS idx_dog_shares_owner_id ON dog_shares(owner_id);

-- 2. Update dogs table
ALTER TABLE dogs
ADD COLUMN IF NOT EXISTS is_shareable BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS total_shares_count INT DEFAULT 0;

-- 3. New Table: dog_share_activity_log
CREATE TABLE IF NOT EXISTS dog_share_activity_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  dog_share_id UUID NOT NULL REFERENCES dog_shares(id) ON DELETE CASCADE,
  actor_user_id UUID NOT NULL REFERENCES users(id),
  action VARCHAR(50) NOT NULL, -- 'created', 'accepted', 'revoked', 'viewed', 'edited'
  metadata JSONB, -- Details about the action
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. RLS Policies

-- Enable RLS
ALTER TABLE dog_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE dog_share_activity_log ENABLE ROW LEVEL SECURITY;

-- dog_shares policies
CREATE POLICY dog_shares_select_policy ON dog_shares
FOR SELECT
USING (
  auth.uid() = owner_id OR 
  auth.uid() = shared_with_user_id
);

CREATE POLICY dog_shares_insert_policy ON dog_shares
FOR INSERT
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY dog_shares_update_policy ON dog_shares
FOR UPDATE
USING (auth.uid() = owner_id);

-- 5. RPC Functions

-- create_dog_share
CREATE OR REPLACE FUNCTION create_dog_share(
  p_dog_id UUID,
  p_owner_id UUID,
  p_access_level VARCHAR,
  p_pin_code VARCHAR DEFAULT NULL,
  p_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_shared_via VARCHAR DEFAULT 'link',
  p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(share_code VARCHAR, share_url TEXT, qr_data TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_share_code VARCHAR(8);
  v_share_url TEXT;
BEGIN
  -- Verify owner owns the dog
  IF NOT EXISTS (SELECT 1 FROM dogs WHERE id = p_dog_id AND owner_id = p_owner_id) THEN
    RAISE EXCEPTION 'Unauthorized: You do not own this dog';
  END IF;
  
  -- Generate unique 8-character code (alphanumeric, uppercase)
  LOOP
    v_share_code := upper(substring(md5(random()::text) from 1 for 8));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM dog_shares WHERE share_code = v_share_code);
  END LOOP;
  
  -- Insert share record
  INSERT INTO dog_shares (
    dog_id, owner_id, share_code, access_level, 
    pin_code, expires_at, shared_via, notes
  ) VALUES (
    p_dog_id, p_owner_id, v_share_code, p_access_level,
    p_pin_code, p_expires_at, p_shared_via, p_notes
  );
  
  -- Update dog's share count
  UPDATE dogs SET total_shares_count = total_shares_count + 1 WHERE id = p_dog_id;
  
  -- Log activity
  INSERT INTO dog_share_activity_log (dog_share_id, actor_user_id, action, metadata)
  SELECT id, p_owner_id, 'created', jsonb_build_object('access_level', p_access_level)
  FROM dog_shares WHERE share_code = v_share_code;
  
  -- Build URLs
  v_share_url := 'https://barkdate.app/share/' || v_share_code;
  
  RETURN QUERY SELECT 
    v_share_code,
    v_share_url,
    v_share_url; -- QR data is just the URL
END;
$$;

-- accept_dog_share
CREATE OR REPLACE FUNCTION accept_dog_share(
  p_share_code VARCHAR,
  p_user_id UUID,
  p_pin_code VARCHAR DEFAULT NULL
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  dog_id UUID,
  access_level VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_share RECORD;
BEGIN
  -- Find share
  SELECT * INTO v_share
  FROM dog_shares
  WHERE share_code = p_share_code
  AND revoked_at IS NULL;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Invalid or revoked share code', NULL::UUID, NULL::VARCHAR;
    RETURN;
  END IF;
  
  -- Check expiration
  IF v_share.expires_at IS NOT NULL AND v_share.expires_at < NOW() THEN
    RETURN QUERY SELECT false, 'This share link has expired', NULL::UUID, NULL::VARCHAR;
    RETURN;
  END IF;
  
  -- Check PIN if required
  IF v_share.pin_code IS NOT NULL AND v_share.pin_code != p_pin_code THEN
    RETURN QUERY SELECT false, 'Incorrect PIN code', NULL::UUID, NULL::VARCHAR;
    RETURN;
  END IF;
  
  -- Update share with user
  UPDATE dog_shares
  SET shared_with_user_id = p_user_id,
      accepted_at = NOW()
  WHERE id = v_share.id;
  
  -- Log activity
  INSERT INTO dog_share_activity_log (dog_share_id, actor_user_id, action)
  VALUES (v_share.id, p_user_id, 'accepted');
  
  RETURN QUERY SELECT 
    true,
    'Successfully connected to dog profile',
    v_share.dog_id,
    v_share.access_level;
END;
$$;

-- revoke_dog_share
CREATE OR REPLACE FUNCTION revoke_dog_share(
  p_share_id UUID,
  p_owner_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify ownership
  IF NOT EXISTS (
    SELECT 1 FROM dog_shares 
    WHERE id = p_share_id AND owner_id = p_owner_id
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  
  -- Revoke
  UPDATE dog_shares
  SET revoked_at = NOW()
  WHERE id = p_share_id;
  
  -- Log
  INSERT INTO dog_share_activity_log (dog_share_id, actor_user_id, action)
  VALUES (p_share_id, p_owner_id, 'revoked');
  
  RETURN true;
END;
$$;

-- get_shared_dogs
CREATE OR REPLACE FUNCTION get_shared_dogs(p_user_id UUID)
RETURNS TABLE(
  dog_id UUID,
  dog_name VARCHAR,
  dog_breed VARCHAR,
  dog_photo_url TEXT,
  access_level VARCHAR,
  owner_name VARCHAR,
  shared_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.name,
    d.breed,
    d.main_photo_url,
    ds.access_level,
    u.name,
    ds.accepted_at
  FROM dog_shares ds
  JOIN dogs d ON ds.dog_id = d.id
  JOIN users u ON ds.owner_id = u.id
  WHERE ds.shared_with_user_id = p_user_id
  AND ds.revoked_at IS NULL;
END;
$$;
