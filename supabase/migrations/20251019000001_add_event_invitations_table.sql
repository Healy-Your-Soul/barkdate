-- Adds event invitations support for events (Phase 3)
BEGIN;

CREATE TABLE IF NOT EXISTS event_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  invited_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','maybe','cancelled')),
  message text,
  responded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id, dog_id)
);

CREATE INDEX IF NOT EXISTS idx_event_invitations_event_id ON event_invitations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_dog_id ON event_invitations(dog_id);
CREATE INDEX IF NOT EXISTS idx_event_invitations_invited_by ON event_invitations(invited_by);

CREATE OR REPLACE FUNCTION update_event_invitations_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_event_invitations_updated_at ON event_invitations;
CREATE TRIGGER trg_event_invitations_updated_at
  BEFORE UPDATE ON event_invitations
  FOR EACH ROW
  EXECUTE FUNCTION update_event_invitations_updated_at();

ALTER TABLE event_invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Inviters can manage their event invitations" ON event_invitations
  FOR ALL
  USING (auth.uid() = invited_by)
  WITH CHECK (auth.uid() = invited_by);

CREATE POLICY "Dog owners can view their invitations" ON event_invitations
  FOR SELECT
  USING (
    auth.uid() = invited_by
    OR EXISTS (
      SELECT 1
      FROM dogs
      WHERE dogs.id = event_invitations.dog_id
        AND dogs.user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON event_invitations TO authenticated;

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS is_public boolean NOT NULL DEFAULT true;

COMMIT;
