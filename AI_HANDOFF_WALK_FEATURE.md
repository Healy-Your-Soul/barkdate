# 🤖 AI Handoff Document: "Walk Together" Feature
**Current Status: ALL Sprints (0-5) Complete. Feature fully unified.**

> **Dear Next AI Assistant:**
> This document is designed to give you complete context on the ongoing implementation of the "Walk Together" feature. An architectural misalignment was discovered between two separate walk systems in the app (System A and System B). We are currently in the middle of a 5-sprint plan to unify them.

---

## 1. Context & Architectural Decisions

*   **The Original Problem**:
    *   **System A (Playdates)**: Allowed direct invites to walks. Created `playdates`, requests, and `conversations`. But it never actually showed the user the group chat after sending an invite.
    *   **System B (Check-ins)**: Scheduled public walks using `PlanWalkSheet`. Inserted into `checkins`. Appeared on the feed carousel via `_getScheduledWalkAlerts`. But it had NO group chat.
*   **The Master Solution (Locked In)**:
    1.  **`playdates` table**: Will handle ALL scheduled walk planning and group chats (both direct invites AND map-based scheduling).
    2.  **`checkins` table**: Will be restricted strictly to "I'm at this park right now" (live tracking).
    3.  **Chat Integration**: Every playdate walk automatically gets a Supabase `conversations` entry. Actions inside the chat (Walk Card) should sync to the `playdates` table, which in turn syncs to the feed carousel.

---

## 2. Current Implementation Status (Sprint by Sprint)

### ✅ Sprint 0: Clean Up & Naming (DONE)
*   **What was done**: Renamed the confusing `onBarkPressed` callback to `onWalkPressed` identically across the codebase.
*   **Files Touched**: `lib/widgets/dog_card.dart`, `lib/screens/feed_screen.dart`, `lib/features/feed/presentation/screens/feed_screen.dart`.
*   **Status**: Passed `flutter analyze`.

### ✅ Sprint 1: Walk Send → Group Chat Flow (DONE)
*   **What was done**: When sending a walk via `SendWalkSheet`, it now successfully intercepts the returned `playdateId`, fetches the associated `conversation_id`, and navigates the user **immediately** into `ChatRoute`.
*   **What was done**: Created an interactive UI element called `ChatWalkCard` which renders in the chat as the first message. It is visually green and editable if the walk date is in the future, and grayed out/locked if the walk time has passed. We also added a pinned header (`ChatWalkPinnedHeader`) to the top of the chat view.
*   **Files Touched**:
    *   `lib/widgets/send_walk_sheet.dart`
    *   `lib/features/messages/presentation/screens/chat_screen.dart`
    *   `lib/widgets/chat_walk_card.dart` (NEW)
    *   `lib/services/conversation_service.dart` (Fixed bug)
*   **Critical DB Bug Fixed**: Supabase table `messages` uses column `match_id` for its conversation foreign key (NOT `conversation_id`). `ConversationService.postSystemMessage` was crashing. This is fixed.
*   **Status**: Compiled iOS without errors. Database schema verified.

### ✅ Sprint 2: Walk Details Sheet Fixes (DONE)
*   **Goal**: Make `walk_details_sheet.dart` agnostic so it can gracefully display data coming from the `playdates` table (not just `checkins`).
*   **What was done**:
    *   `WalkDetailsSheet` now accepts an optional `playdateId` parameter. When provided, it loads walk data from the `playdates` + `playdate_participants` tables instead of `checkins`.
    *   Real participant data (dog photos, dog names, owner names) now shown from `playdate_participants`.
    *   "Join the Walk" inserts into `playdate_participants` and ensures the user is added to the conversation.
    *   "Leave This Walk" removes the user from `playdate_participants` and the conversation.
    *   Added an "Open Walk Chat" button that navigates to the linked group conversation when one exists.
    *   Locked state: the header turns grey and buttons are hidden once the walk time passes or the playdate is cancelled.
    *   Shows "Organizer" badge next to the organizer's name.
    *   `_getUserOwnUpcomingWalkAlerts()` now queries `latitude`, `longitude`, filters by `['pending', 'confirmed']` status, fetches actual participant count from `playdate_participants`, and passes `playdateId` in metadata.
    *   Added `FriendActivityService.getPlaydateWalkParticipants()` method.
    *   Added `playdateId` field to `FriendAlert.walkTogether` factory and metadata.
    *   `PackAlertsCarousel._handleCtaTap()` now passes `playdateId` through to `showWalkDetailsSheet`.
    *   `ChatWalkCard._viewDetails()` now passes `playdateId` instead of `checkInId`.
    *   `ChatScreen` pinned header tap now passes `playdateId` instead of `checkInId`.
    *   **Feed "Upcoming Walks" section**: Tapping a playdate card now opens `showWalkDetailsSheet` (with `playdateId`) instead of `PlaydateDetailsRoute`. This means the feed cards get the same rich walk details UI with participants, chat button, and join/leave — not just the generic playdate view.
    *   Accept/Decline buttons in the feed now also invalidate `friendAlertsProvider` so the Pack Activity carousel refreshes immediately.
*   **Files Touched**:
    *   `lib/widgets/walk_details_sheet.dart` (rewritten)
    *   `lib/services/friend_activity_service.dart` (fixed + new method)
    *   `lib/models/friend_alert.dart` (added playdateId)
    *   `lib/widgets/pack_alerts_carousel.dart` (updated CTA handler)
    *   `lib/widgets/chat_walk_card.dart` (fixed _viewDetails)
    *   `lib/features/messages/presentation/screens/chat_screen.dart` (pass playdateId)
    *   `lib/features/feed/presentation/screens/feed_screen.dart` (playdate card tap + accept/decline refresh)
*   **Status**: `flutter analyze` — No issues found.

### ✅ Sprint 3: Data Source Switch (DONE)
*   **Goal**: Switch all walk data queries from `checkins` to `playdates`. Rewire `PlanWalkSheet`.
*   **What was done**:
    *   Replaced `_getScheduledWalkAlerts()` (checkins) with `_getFriendUpcomingWalkAlerts()` (playdates) — friend walks now come from the `playdates` table with `playdateId` in metadata.
    *   Removed `_getWalkJoinCount()` (checkins) — participant counts now use `playdate_participants`.
    *   Replaced `getScheduledWalksForMap()` to query `playdates` instead of `checkins` — map walk markers now show playdate-based walks.
    *   Rewired `PlanWalkSheet` from `CheckInService.scheduleFutureCheckIn()` to creating a playdate + group conversation + navigating to chat.
    *   Added "Plan a Walk" button to the V2 map `PlaceSheetContent` (was missing from active map, only existed in legacy).
*   **Files Touched**:
    *   `lib/services/friend_activity_service.dart` (replaced 3 methods)
    *   `lib/widgets/plan_walk_sheet.dart` (rewired from CheckInService to playdates + ConversationService)
    *   `lib/screens/map_v2/widgets/simple_place_sheet.dart` (added Plan a Walk button)
*   **Status**: `flutter analyze` — No issues found.

### ✅ Sprint 4: Chat ↔ Walk Live Sync (DONE)
*   **Goal**: Accept/decline in `ReceiveWalkSheet` updates feed carousel and posts system message to chat.
*   **What was done**:
    *   Converted `ReceiveWalkSheet` from `StatefulWidget` to `ConsumerStatefulWidget` for Riverpod access.
    *   Added `ref.invalidate(friendAlertsProvider)` after accept AND decline — carousel refreshes immediately.
    *   Added `_postWalkSystemMessage()` helper — fetches conversation, gets user's dog name + human name, posts dog-centric system message (e.g. "Luna's human, Sarah, joined the walk!").
    *   Fixed accepted/declined/counter-proposed notifications in `respondToPlaydateRequest()` to use dog-centric text (e.g. "Luna is joining the walk! 🎉" instead of "Playdate Accepted!").
    *   Added `invitee_dog.main_photo_url` to the query so `dog_photo` is available in notification metadata.
*   **Files Touched**:
    *   `lib/widgets/receive_walk_sheet.dart` (ConsumerStatefulWidget + invalidate + system messages)
    *   `lib/supabase/bark_playdate_services.dart` (dog-centric accept/decline/counter notifications)
*   **Status**: `flutter analyze` — No issues found.

### ✅ Sprint 5: Map Markers & Notification Polish (DONE)
*   **Goal**: Scheduled walks visible on map with tap-through. All notification routing works correctly.
*   **What was done**:
    *   V2 map scheduled walk markers now use green markers (instead of azure) and have `onTap` → `showWalkDetailsSheet()` with `playdateId`.
    *   Fixed FCM notification type mismatch: DB stores `playdate_request` (snake_case) but Dart enum is `playdateRequest` (camelCase). Added a `_typeMap` + `_parseType()` helper that handles both formats across all three notification entry points.
    *   `playdate_accepted` notification tap now opens the walk's group chat (fetches conversation from `playdateId` in metadata) in both FCM routing and in-app notifications screen.
    *   Added `context.mounted` checks after async gaps to fix lint warnings.
*   **Files Touched**:
    *   `lib/screens/map_v2/map_tab_screen.dart` (green markers + onTap + walk_details_sheet import)
    *   `lib/services/firebase_messaging_service.dart` (type map + _parseType + playdate chat navigation)
    *   `lib/features/notifications/presentation/screens/notifications_screen.dart` (playdate tap → chat)

---

## 3. How To Test Effectively

Since this is a mobile app and there is no integrated web framework, here is the protocol for testing:
1.  **Code Consistency**: ALWAYS run `flutter analyze` after every sprint or major file modification.
2.  **Compilation Check**: Periodically run `flutter build ios --no-codesign --debug` or `flutter build apk` to catch runtime integration errors that analyze misses.
3.  **Schema Verification**: If interacting with Supabase, verify the columns exist using `curl` to the Supabase REST API or inspecting the `supabase_config.dart`.
4.  *(Manual)* **Testing Sprint 1 Feature**: Open the app -> Tap 'Walk?' on a dog card -> Confirm send -> Verify app pushes to Chat Screen -> Verify the `ChatWalkCard` displays location and time.

---

## 4. Known Environment Hazards

*   ⚠️ **Pre-existing DB Policy Bug**: Supabase `conversation_participants` table currently has a recursive RLS Policy causing "infinite recursion detected" errors during queries.
    *   *Remedy*: We have provided a SQL script at `draft/sql_archive/FIX_CONVERSATION_PARTICIPANTS_RLS.sql`. The human developer must run this in the Supabase Dashboard SQL editor manually before database fetching will work perfectly.
*   **Message Schema**: The `messages` table uses `match_id` for chat linkage. Do not use `conversation_id`.
*   **Context Scope**: Be aware of Riverpod async gaps inside sheets. We use `mounted` and `Navigator.of(context)` carefully when popping/pushing.

---

## 5. Embedded Documentation Resources

For full historical reference of how these conclusions were drawn, the full implementation plans and verification scripts have been copied into the project directory alongside this file.
You must review these files as your source of truth for the codebase's current state on this branch:
1.  **[implementation_plan.md](docs/walk_feature/implementation_plan.md)**: Contains mermaid graphs of the old architecture and detailed sprint breakdowns.
2.  **[verification_report.md](docs/walk_feature/verification_report.md)**: Details the successful curl database checks and bug patches applied in Sprints 0 & 1.

*(End of Handoff Document)*
