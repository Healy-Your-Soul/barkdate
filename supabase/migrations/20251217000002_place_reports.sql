-- Place Reports Migration (SIMPLIFIED - FIXED)
-- Users can report places as not dog-friendly
-- Admin features will be added when is_admin column exists

-- 1. Add is_admin column to users if it doesn't exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- 2. Create place_reports table
CREATE TABLE IF NOT EXISTS place_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id TEXT NOT NULL,
  place_name TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  report_type TEXT NOT NULL DEFAULT 'not_dog_friendly',
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  admin_notes TEXT,
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Create indexes
CREATE INDEX IF NOT EXISTS idx_place_reports_place_id ON place_reports(place_id);
CREATE INDEX IF NOT EXISTS idx_place_reports_status ON place_reports(status);
CREATE INDEX IF NOT EXISTS idx_place_reports_created_at ON place_reports(created_at DESC);

-- 4. Enable RLS
ALTER TABLE place_reports ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies (simplified for all authenticated users for now)
DROP POLICY IF EXISTS "Users can create reports" ON place_reports;
CREATE POLICY "Users can create reports"
ON place_reports FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own reports" ON place_reports;
CREATE POLICY "Users can view own reports"
ON place_reports FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all reports" ON place_reports;
CREATE POLICY "Admins can view all reports"
ON place_reports FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND is_admin = true
  )
);

DROP POLICY IF EXISTS "Admins can update reports" ON place_reports;
CREATE POLICY "Admins can update reports"
ON place_reports FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND is_admin = true
  )
);

-- 6. Function to submit report
CREATE OR REPLACE FUNCTION submit_place_report(
  p_place_id TEXT,
  p_place_name TEXT,
  p_report_type TEXT DEFAULT 'not_dog_friendly',
  p_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_report_id UUID;
BEGIN
  -- Check duplicate within 24 hours
  IF EXISTS (
    SELECT 1 FROM place_reports
    WHERE place_id = p_place_id 
      AND user_id = auth.uid()
      AND status = 'pending'
      AND created_at > NOW() - INTERVAL '24 hours'
  ) THEN
    RAISE EXCEPTION 'You have already reported this place recently';
  END IF;

  -- Insert report
  INSERT INTO place_reports (place_id, place_name, user_id, report_type, message)
  VALUES (p_place_id, p_place_name, auth.uid(), p_report_type, p_message)
  RETURNING id INTO v_report_id;

  RETURN v_report_id;
END;
$$;

-- 7. Grant permissions
GRANT EXECUTE ON FUNCTION submit_place_report TO authenticated;

-- 8. Update notifications type constraint to include admin_report
DO $$
BEGIN
  ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
  ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
    CHECK (type IN ('match', 'message', 'playdate', 'achievement', 'system', 'admin_report'));
EXCEPTION WHEN OTHERS THEN
  -- Constraint might not exist
  NULL;
END $$;
