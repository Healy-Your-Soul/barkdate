-- Sprint 7a: allow receiver_id to be NULL for group / playdate chats
-- where the message is broadcast to all participants in match_id.
-- Existing 1-on-1 messages continue to have a receiver_id set; new
-- group-chat messages may have NULL.
-- The FK still enforces referential integrity when receiver_id is not NULL.

ALTER TABLE messages
  ALTER COLUMN receiver_id DROP NOT NULL;
