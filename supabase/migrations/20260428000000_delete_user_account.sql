-- =====================================================
-- Delete User Account: RPC Functions
-- =====================================================
-- Creates two functions called by the Flutter app during account deletion:
-- 1. cleanup_user_storage — nullifies storage URL references in DB rows
-- 2. delete_user_account — cascades deletion of all user data + auth user

-- =====================================================
-- 1. cleanup_user_storage
-- =====================================================
-- Called BEFORE delete_user_account.
-- Nullifies photo/avatar URL columns so storage files aren't orphaned
-- as dangling references. The actual file deletion is done client-side.

CREATE OR REPLACE FUNCTION cleanup_user_storage(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Clear user avatar URL
  UPDATE users SET avatar_url = NULL WHERE id = user_id;

  -- Clear dog photo URLs
  UPDATE dogs SET main_photo_url = NULL WHERE dogs.user_id = cleanup_user_storage.user_id;

  -- Clear post image URLs
  UPDATE posts SET image_url = NULL WHERE posts.user_id = cleanup_user_storage.user_id;

  RAISE NOTICE 'Storage references cleaned for user %', user_id;
END;
$$;

-- =====================================================
-- 2. delete_user_account
-- =====================================================
-- Deletes all user-owned data from every table, then removes the
-- auth.users row. Uses SECURITY DEFINER so it runs with elevated
-- privileges (the service role) — only the owning user or an admin
-- should call this.

CREATE OR REPLACE FUNCTION delete_user_account(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- ---- Notifications & Achievements ----
  DELETE FROM notifications WHERE notifications.user_id = delete_user_account.user_id;
  DELETE FROM user_achievements WHERE user_achievements.user_id = delete_user_account.user_id;

  -- ---- Social: follows, likes, comments ----
  DELETE FROM follows WHERE follower_id = user_id OR following_id = user_id;
  DELETE FROM post_likes WHERE post_likes.user_id = delete_user_account.user_id;
  DELETE FROM post_comments WHERE post_comments.user_id = delete_user_account.user_id;
  DELETE FROM posts WHERE posts.user_id = delete_user_account.user_id;

  -- ---- Content moderation ----
  DELETE FROM user_blocks WHERE blocker_id = user_id OR blocked_id = user_id;
  DELETE FROM content_reports WHERE reporter_id = user_id OR reported_user_id = user_id;

  -- ---- Dog sharing ----
  DELETE FROM dog_share_activity_log WHERE dog_share_activity_log.user_id = delete_user_account.user_id;
  DELETE FROM dog_shares WHERE owner_id = user_id OR shared_with_id = user_id;

  -- ---- Playdates ----
  DELETE FROM playdate_reminder_preferences WHERE playdate_reminder_preferences.user_id = delete_user_account.user_id;
  DELETE FROM playdate_participants WHERE playdate_participants.user_id = delete_user_account.user_id;
  DELETE FROM playdate_requests WHERE sender_id = user_id OR receiver_id = user_id;
  DELETE FROM playdates WHERE organizer_id = user_id OR participant_id = user_id;

  -- ---- Messaging ----
  -- Delete messages sent by user
  DELETE FROM messages WHERE sender_id = user_id;
  -- Remove from conversation participants
  DELETE FROM conversation_participants WHERE conversation_participants.user_id = delete_user_account.user_id;

  -- ---- Events ----
  DELETE FROM event_invitations WHERE inviter_id = user_id OR invitee_id = user_id;

  -- ---- Check-ins & Location ----
  DELETE FROM checkins WHERE checkins.user_id = delete_user_account.user_id;
  DELETE FROM park_status_reports WHERE park_status_reports.user_id = delete_user_account.user_id;

  -- ---- Place reports & amenity suggestions ----
  DELETE FROM place_reports WHERE place_reports.user_id = delete_user_account.user_id;
  DELETE FROM amenity_suggestions WHERE amenity_suggestions.user_id = delete_user_account.user_id;

  -- ---- Dog friendships (must be before dogs) ----
  DELETE FROM dog_friendships
    WHERE dog_id IN (SELECT id FROM dogs WHERE dogs.user_id = delete_user_account.user_id)
       OR friend_dog_id IN (SELECT id FROM dogs WHERE dogs.user_id = delete_user_account.user_id);

  -- ---- Matches ----
  DELETE FROM matches
    WHERE dog1_id IN (SELECT id FROM dogs WHERE dogs.user_id = delete_user_account.user_id)
       OR dog2_id IN (SELECT id FROM dogs WHERE dogs.user_id = delete_user_account.user_id);

  -- ---- Dogs ----
  DELETE FROM dogs WHERE dogs.user_id = delete_user_account.user_id;

  -- ---- Premium subscriptions ----
  DELETE FROM premium_subscriptions WHERE premium_subscriptions.user_id = delete_user_account.user_id;

  -- ---- User profile ----
  DELETE FROM users WHERE id = user_id;

  -- ---- Auth user (requires service_role via SECURITY DEFINER) ----
  DELETE FROM auth.users WHERE id = user_id;

  RAISE NOTICE 'User % and all related data deleted successfully', user_id;
END;
$$;

-- Grant execute to authenticated users (they can only delete themselves
-- because the Flutter app passes auth.uid() as the parameter).
GRANT EXECUTE ON FUNCTION cleanup_user_storage(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_account(uuid) TO authenticated;
