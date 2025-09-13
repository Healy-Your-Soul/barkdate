-- Migration: playdate multi-owner upgrade
-- Adds requester_dog_id to playdate_requests and makes participant_id nullable to favor playdate_participants pivot

ALTER TABLE playdates ALTER COLUMN participant_id DROP NOT NULL;

ALTER TABLE playdate_requests ADD COLUMN IF NOT EXISTS requester_dog_id uuid REFERENCES dogs(id);

-- Optional: backfill requester_dog_id using first participant (organizer) dog if available
-- UPDATE playdate_requests pr
-- SET requester_dog_id = pp.dog_id
-- FROM playdate_participants pp
-- JOIN playdates p ON p.id = pr.playdate_id
-- WHERE pr.requester_dog_id IS NULL AND pp.playdate_id = pr.playdate_id AND pp.user_id = pr.requester_id;

-- Ensure uniqueness considers requester_dog_id for multi-dog scenarios (drop old constraint first if exists)
DO $$
DECLARE
    constraint_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name='playdate_requests' AND constraint_type='UNIQUE' AND constraint_name='playdate_requests_playdate_id_invitee_id_invitee_dog_id_key'
    ) INTO constraint_exists;
    IF constraint_exists THEN
        ALTER TABLE playdate_requests DROP CONSTRAINT playdate_requests_playdate_id_invitee_id_invitee_dog_id_key;
    END IF;
END$$;

ALTER TABLE playdate_requests ADD CONSTRAINT playdate_requests_unique_dogs UNIQUE (playdate_id, invitee_id, invitee_dog_id, requester_dog_id);

-- Indexes to speed queries
CREATE INDEX IF NOT EXISTS idx_playdate_participants_playdate ON playdate_participants(playdate_id);
CREATE INDEX IF NOT EXISTS idx_playdate_participants_user ON playdate_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_playdate_requests_requester_dog ON playdate_requests(requester_dog_id);

-- View or future RPC adaptations can reference playdate_participants exclusively.
