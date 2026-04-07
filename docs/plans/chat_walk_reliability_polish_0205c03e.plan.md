---
name: Chat walk reliability polish
overview: Fix walk invite/chat reliability and message UX by wiring realtime + fallback data paths, adding contextual actions, and improving conversation ordering/sending behavior.
todos:
  - id: popup-reliability
    content: Fix walk invite bottom sheet so it shows on first login without page refresh; auth/rescan/post-frame; dedupe
    status: pending
  - id: chat-card-linking
    content: Ensure walk container appears immediately in chat via request fallback + realtime refresh
    status: pending
  - id: location-map-nav
    content: Open in-app map from location row and keep CTA->details with directions
    status: pending
  - id: walk-card-polish
    content: Adjust participant spacing and contextual CTA by role/status
    status: pending
  - id: unread-chat-list
    content: Implement unread-first sort in chat list and mark-read lifecycle
    status: pending
  - id: send-latency
    content: Clear message input immediately and decouple non-critical send side-effects
    status: pending
  - id: sql-apply-verify
    content: Apply and verify playdate-request acceptance trigger migration
    status: pending
isProject: false
---

# Chat Walk Reliability and UX Fixes

## Scope and confirmed behavior
- Unread sorting applies to the **chat list only**.
- In chat walk UI, **location row opens in-app map with location info**.
- CTA button still opens walk details sheet, and sheet provides **Get directions**.

## Issues to resolve
- Invitee does not always see incoming walk bottom-sheet popup after login.
- **Critical symptom:** After a **full page refresh**, the walk-invite **bottom sheet suddenly appears**, even though it did not show on first entry. That pattern usually means the popup path depends on **late-bound context**, **notification realtime not subscribed at the right time**, or a **time window / one-shot gate** that misses the first delivery and only fires after reload re-fetches or re-attaches streams. Implementation must make pending invites show **without requiring refresh**.
- Organizer chat sometimes does not show walk container immediately after creating invite.
- Location row in chat walk card/header does not open map directly.
- Minor card UI polish: spacing between avatar stack and participant count; contextual CTA text for organizer vs invitee.
- Chat list should sort unread conversations to top.
- Sending message leaves typed text visible for too long.

## Implementation plan

### 1) Make incoming walk popup reliable after login
- Update notification bootstrap to subscribe/re-subscribe on auth changes and scan unread pending invite notifications on session start.
- Keep realtime trigger path, but remove reliance on "created within 10s" as sole gate for opening pending invites (reload often "fixes" this because it re-queries fresh rows and re-attaches listeners).
- On successful sign-in (and on app resume when logged in), run a **one-time fetch** of latest unread `playdate_request` notifications for the current user and open the sheet when appropriate (still deduped), so cold start matches refresh behavior.
- Ensure `rootNavigatorKey.currentContext` is available (e.g. `WidgetsBinding.addPostFrameCallback` / retry once) so the first navigation after OAuth does not silently skip the sheet.
- Guard against duplicate sheet openings with existing dedupe key.
- **Acceptance:** Invitee sees the bottom sheet for a pending walk invite on first load after login **without** refreshing the browser tab.

Files:
- [lib/services/notification_manager.dart](lib/services/notification_manager.dart)
- [lib/widgets/receive_walk_sheet.dart](lib/widgets/receive_walk_sheet.dart)
- [lib/services/firebase_messaging_service.dart](lib/services/firebase_messaging_service.dart)

### 2) Ensure walk container appears in chat for sender immediately
- Keep/extend fallback link logic in chat screen to resolve walk via latest `playdate_requests` even when `conversations.playdate_id` link lags.
- Add realtime listener for `playdate_requests` in chat screen and card so newly created/updated requests refresh linked walk state.
- Trigger local refresh on return from send flow so sender sees card without waiting for other user actions.

Files:
- [lib/features/messages/presentation/screens/chat_screen.dart](lib/features/messages/presentation/screens/chat_screen.dart)
- [lib/widgets/chat_walk_card.dart](lib/widgets/chat_walk_card.dart)
- [lib/widgets/send_walk_sheet.dart](lib/widgets/send_walk_sheet.dart)

### 3) Location row behavior: open in-app map + directions
- Wire location row tap in card/header to navigate to in-app map screen with coordinates/place metadata.
- Keep primary CTA behavior for walk details sheet.
- Add/confirm `Get directions` action inside walk details sheet (visible when lat/lng exists).

Files:
- [lib/widgets/chat_walk_card.dart](lib/widgets/chat_walk_card.dart)
- [lib/widgets/walk_details_sheet.dart](lib/widgets/walk_details_sheet.dart)
- [lib/features/messages/presentation/screens/chat_screen.dart](lib/features/messages/presentation/screens/chat_screen.dart)
- [lib/core/router/app_routes.dart](lib/core/router/app_routes.dart)

### 4) Chat walk card UI polish and contextual CTA
- Add small horizontal spacing between dog avatar stack and participant count text.
- **Pinned header alignment:** In `ChatWalkPinnedHeader`, vertically center the **location pin icon** with the **two-line block** (location + time). Vertically center the **status pill + chevron** as one unit to match that same vertical center (avoid top-aligned icon with multi-line text).
- Make CTA label contextual by role/status:
  - Organizer before lock: `View / edit walk`
  - Invitee before lock: `View walk`
  - Locked/cancelled: `View details`
- Preserve icon-first style (no emojis).

Files:
- [lib/widgets/chat_walk_card.dart](lib/widgets/chat_walk_card.dart)
- [lib/widgets/walk_details_sheet.dart](lib/widgets/walk_details_sheet.dart)

### 5) Unread-first sorting in chat list (messages screen)
- Compute unread signal per conversation (`receiver_id == currentUser && is_read == false`).
- Sort chat list by unread first, then latest message timestamp.
- Mark messages as read when opening a chat so unread ordering behaves correctly.

Files:
- [lib/features/messages/presentation/screens/messages_screen.dart](lib/features/messages/presentation/screens/messages_screen.dart)
- [lib/features/messages/presentation/screens/chat_screen.dart](lib/features/messages/presentation/screens/chat_screen.dart)
- [lib/supabase/barkdate_services.dart](lib/supabase/barkdate_services.dart)

### 6) Send-message latency UX fix
- Clear input immediately after capture and before long async side-effects.
- Keep send failure recovery (restore text/snackbar if insert fails).
- Move notification push side-effects off critical path so message insert/echo feels instant.

Files:
- [lib/features/messages/presentation/screens/chat_screen.dart](lib/features/messages/presentation/screens/chat_screen.dart)
- [lib/supabase/barkdate_services.dart](lib/supabase/barkdate_services.dart)
- [lib/services/notification_manager.dart](lib/services/notification_manager.dart)

### 7) Supabase SQL sync hardening (already prepared)
- Apply migration that syncs `playdates.status/participant_id` when `playdate_requests.status` becomes `accepted` (security definer trigger).

File:
- [supabase/migrations/20260405120000_sync_playdate_on_request_accepted.sql](supabase/migrations/20260405120000_sync_playdate_on_request_accepted.sql)

#### Manual Supabase steps (optional; you can apply outside the app)
- **SQL Editor:** Run the migration SQL above (or `supabase db push` if you use CLI). If `EXECUTE FUNCTION` errors on your Postgres version, use `EXECUTE PROCEDURE` for the trigger instead.
- **Realtime:** In **Database → Replication**, ensure tables used for invite UX are published if you rely on client realtime: at minimum `notifications`, and for chat walk refresh also `playdate_requests` and `playdates` (match what the Flutter channels subscribe to).
- **RLS:** No change required for the trigger if it is `SECURITY DEFINER` with `search_path = public`; it updates `playdates` when the invitee accepts even when client RLS blocks invitee `UPDATE` on `playdates`.

## Validation checklist
- Invitee login with pending walk request shows bottom sheet (once, deduped) **without** manual page refresh.
- Sender sees walk card in chat immediately after invite creation.
- Location row opens in-app map; CTA opens details sheet; details sheet has directions action.
- Participant spacing is visually clean; CTA label matches role; pinned header icon and status+chevron are vertically centered with the location/time column.
- Chat list orders unread conversations first.
- Message input clears instantly on send.
- `flutter analyze` passes on touched files.
