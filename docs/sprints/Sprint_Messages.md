# Sprint: Messages Tab Integration (Realtime Chat + Push)

## Goals
- Replace demo list with real conversations.
- Ensure realtime chat with unread counts, read receipts, and push notifications.

## Scope
- Client
  - Messages list from `BarkDateMessageService.getConversations` with unread badges.
  - Pass real `matchId` and `recipientId` to open `ChatDetailScreen`.
  - Optional: typing indicators via Realtime ephemeral channel.
  - Send images: upload to Supabase Storage, message references media URL.
- Backend
  - Confirm `messages` schema and RLS (sender/receiver can read, sender can insert, receiver can update read state).
  - Indexes for `match_id + created_at` and `receiver_id + is_read`.
- Notifications
  - On message insert, create notification row for receiver and trigger FCM via Edge Function.

## Deliverables
- Functional conversations list with unread counts.
- Realtime chat with read receipts and optional media.
- Background push opens to chat.

## Acceptance Criteria
- New messages appear in <2s; leaving/returning maintains history.
- Unread badge decrements after chat is viewed.
- Tapping push navigates to the correct chat.

## Tasks
1) Backend
   - Validate/adjust `messages` table and RLS/indices.
   - Add Edge Function for push on message insert if not present.
2) Client
   - Implement real `MessagesScreen` using service.
   - Wire navigation to pass `matchId`/`recipientId`.
   - Read receipts (mark as read on open).
   - Optional typing indicator.
3) Media
   - Allow image send; store in `chat-media/{userId}/...`.
4) QA & polish
   - Error states, retries, scroll-to-bottom behavior.

## Risks/Notes
- RLS correctness; ensure no data leaks across users.
- Storage rules for chat media.
- Push delivery reliability handled by Edge Function retry.
