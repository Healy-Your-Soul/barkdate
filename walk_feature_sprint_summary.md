# Walk Together Feature - Sprints Summary & Status

## 💬 Chat Summary & Progress So Far

During our recent chat sessions, we analyzed the existing architecture for the "Walk Together" feature and found it was split into two completely disconnected systems:
*   **System A (Playdates)**: Used for direct walk invites, sending requests, and managing group chats.
*   **System B (Check-ins)**: Used for public scheduled walks that appear in the feed carousel.

We agreed on a strategy to unify these by keeping both tables but assigning them distinct roles:
1.  **`playdates`** handles all walk planning and group chats.
2.  **`checkins`** is restricted strictly to "I'm at this park RIGHT NOW" live statuses.

### Sprint Progress
*   **Sprint 0 (Cleanup):** ✅ Completed. We successfully renamed all instances of `onBarkPressed` to `onWalkPressed` for consistency across the codebase.
*   **Sprint 1 (Walk Send → Chat Flow):** ✅ Completed. After a user sends a walk invite, the app now automatically navigates them to the group chat. We added a rich `ChatWalkCard` at the top of the chat (editable before the walk time, and locked/grayed-out after it passes) alongside a pinned header.

### Critical Bugs Discovered & Fixed
*   **Messaging Schema Bug**: We discovered the `messages` table uses `match_id` rather than `conversation_id`. The code was trying to insert system messages into a non-existent column. This was patched in code by using the correct column (`match_id`).
*   **Supabase Recursive RLS Policy**: We uncovered a pre-existing issue in Supabase where the `conversation_participants` table has a recursive Row-Level Security (RLS) policy, which can cause infinite recursion errors. We have prepared an SQL script (`draft/sql_archive/FIX_CONVERSATION_PARTICIPANTS_RLS.sql`) for you to run manually in the Supabase Dashboard to cleanly fix this policy before proceeding further.

---

## 🏃 Sprint Plan (What Needs To Be Done)

### Sprint 0: Rename `onBarkPressed` → `onWalkPressed` *(cleanup)* ✅ DONE
**Goal**: Clean up the confusing callback name across the codebase. Quick, safe rename.
*   Renamed 10 occurrences across 3 files.

### Sprint 1: Walk Send → Group Chat Flow *(core fix)* ✅ DONE
**Goal**: When a user sends a walk invite, immediately create+open a group chat with a walk card in it.
*   Navigates directly to the group chat after creating a playdate request.
*   Created `chat_walk_card.dart` for rich interactive walk view inside the chat.
*   Added pinned header and system message rendering on `chat_screen.dart`.

### Sprint 2: Walk Details Sheet Fixes *(data integrity)*
**Goal**: Make `WalkDetailsSheet` work correctly for both CheckIn-based and Playdate-based walks.
*   **Modify `walk_details_sheet.dart`**: Load details from either `playdates` or `checkins` based on passed data. Show real participant photos/names. Fix Join/Cancel logic for both systems. Add an "Open Chat" button.
*   **Modify `friend_activity_service.dart`**: Fix `_getUserOwnUpcomingWalkAlerts()` to pass `parkId` from `playdates.location`. Add `playdateId` to walk alert metadata.

### Sprint 3: Feed Carousel & Entry Points *(visibility)*
**Goal**: Walk cards show correctly in the carousel and the Plan Walk entry point works on the map.
*   **Modify `pack_alerts_carousel.dart`**: Route taps properly for playdate-based walks.
*   **Modify `friend_activity_service.dart`**: Source all walk alerts entirely from the `playdates` table. Remove check-ins as a source for scheduled walks.
*   **Modify Map Bottom Sheet**: Add "Plan a Walk" button.
*   **Modify `plan_walk_sheet.dart`**: Switch creation logic from CheckInService back to `PlaydateRequestService`. Send proper notifications to friends.

### Sprint 4: Chat ↔ Walk Live Sync *(cross-feature integration)*
**Goal**: Actions taken on a walk (accept/decline) update both the chat card and the carousel in real-time.
*   **Modify `receive_walk_sheet.dart`**: Invalidate the carousel provider, post system messages ("Luna accepted the walk! 🎉"), and navigate to the chat.
*   **Modify `conversation_service.dart`**: Add helper for getting conversation metadata for easy navigation.

### Sprint 5: Map & Notifications Polish *(discoverability)*
**Goal**: Walks are visible on the map as markers and notifications route correctly.
*   **Modify `map_tab_screen.dart`**: Render custom markers for scheduled walks (with participant badges).
*   **Fix Notification routing**: Ensure tapping notifications routes payload data precisely to the correct popup sheets.

---

## 🔬 Verification Report (For Sprints 0 & 1)

### 1. Static Analysis ✅
```
flutter analyze → No issues found!
```

### 2. iOS Build ✅
```
flutter build ios --no-codesign --debug → ✓ Built build/ios/iphoneos/Runner.app
```

### 3. Database Schema Verification (via curl) ✅
| Table | Columns Tested | Result |
|-------|---------------|--------|
| `conversations` | `id, playdate_id, is_group, group_name` | ✅ All exist |
| `playdates` | `id, title, location, scheduled_at, status, organizer_id, latitude, longitude` | ✅ All exist |
| `playdate_participants` | `id, playdate_id, user_id, dog_id` | ✅ All exist |
| `messages` | `id, match_id, sender_id, receiver_id, content, message_type, is_read` | ✅ All exist |
| `conversation_participants` | `id, conversation_id, user_id, role` | ⚠️ Recursive RLS policy detected (SQL fix provided) |

### 4. Critical Bug Found & Fixed 🐛
> **Bug**: `ConversationService.postSystemMessage()` was inserting `conversation_id` into the `messages` table, but that column **doesn't exist**. The table uses `match_id` instead. Also: `sender_id: null` would fail because the column requires a non-null value.

**Fix applied**: `postSystemMessage()` now:
*   Uses `match_id` instead of `conversation_id`
*   Uses `message_type: 'system'` instead of `is_system_message: true`
*   Fetches a participant to use as an automated sender/receiver placeholder.

### 5. Final Code Flow Trace ✅
*   Sending a walk invokes `PlaydateRequestService`, writing to the DB and generating a push notification.
*   It immediately calls `ConversationService.getPlaydateConversation()`, pulling up the chat ID.
*   The system navigates immediately to `ChatScreen`.
*   `ChatScreen` analyzes the properties, inserts the `ChatWalkPinnedHeader`, and builds an editable/locked `ChatWalkCard` from the stream dynamically based on the current time vs. scheduled walk time.
