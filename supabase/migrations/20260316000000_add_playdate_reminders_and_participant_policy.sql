-- Playdate reminder preferences + participant self-remove policy
-- Date: 2026-03-16

-- Ensure playdate request status allows counter proposals.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'playdate_requests_status_check'
  ) THEN
    ALTER TABLE playdate_requests DROP CONSTRAINT playdate_requests_status_check;
  END IF;

  ALTER TABLE playdate_requests
    ADD CONSTRAINT playdate_requests_status_check
    CHECK (status IN ('pending', 'accepted', 'declined', 'counter_proposed'));
END $$;

-- Reminder preferences for walk/playdate invites.
CREATE TABLE IF NOT EXISTS playdate_reminder_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  playdate_request_id uuid REFERENCES playdate_requests(id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT true,
  minutes_before integer NOT NULL DEFAULT 60,
  last_sent_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT playdate_reminder_preferences_unique_user_playdate
    UNIQUE (user_id, playdate_id),
  CONSTRAINT playdate_reminder_preferences_minutes_check
    CHECK (minutes_before IN (15, 60, 1440))
);

CREATE INDEX IF NOT EXISTS idx_playdate_reminder_preferences_playdate
  ON playdate_reminder_preferences(playdate_id);

CREATE INDEX IF NOT EXISTS idx_playdate_reminder_preferences_due
  ON playdate_reminder_preferences(enabled, last_sent_at)
  WHERE enabled = true;

ALTER TABLE playdate_reminder_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own reminder preferences" ON playdate_reminder_preferences;
CREATE POLICY "Users can view own reminder preferences"
  ON playdate_reminder_preferences
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own reminder preferences" ON playdate_reminder_preferences;
CREATE POLICY "Users can create own reminder preferences"
  ON playdate_reminder_preferences
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own reminder preferences" ON playdate_reminder_preferences;
CREATE POLICY "Users can update own reminder preferences"
  ON playdate_reminder_preferences
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own reminder preferences" ON playdate_reminder_preferences;
CREATE POLICY "Users can delete own reminder preferences"
  ON playdate_reminder_preferences
  FOR DELETE
  USING (auth.uid() = user_id);

-- Decline flow needs invitees to remove themselves from playdate conversations.
DROP POLICY IF EXISTS "Users can leave conversations" ON conversation_participants;
CREATE POLICY "Users can leave conversations"
  ON conversation_participants
  FOR DELETE
  USING (auth.uid() = user_id);
