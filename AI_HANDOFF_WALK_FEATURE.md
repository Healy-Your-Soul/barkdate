# 🤖 AI Handoff Document: "Walk Together" Feature
**Current Status: Sprint 0 & 1 Complete. Ready for Sprint 2.**

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

### ⏳ Sprint 2: Walk Details Sheet Fixes (NEXT)
*   **Goal**: Make `walk_details_sheet.dart` agnostic so it can gracefully display data coming from the `playdates` table (not just `checkins`).
*   **Task List**:
    *   Update `WalkDetailsSheet`.
    *   Update `friend_activity_service.dart` (`_getUserOwnUpcomingWalkAlerts()`) to properly pass `parkId` from `playdates.location`.

### ⏳ Sprint 3: Feed Carousel & Map Entry Point (TODO)
*   **Goal**: Ensure walk cards show in the feed carousel correctly. Switch `PlanWalkSheet` to use System A instead of System B.
*   **Task List**: Fix `pack_alerts_carousel.dart` taping. Change `plan_walk_sheet.dart` from CheckInService back to PlaydateRequestService.

### ⏳ Sprint 4: Chat ↔ Walk Live Sync (TODO)
*   **Goal**: Sync accept/decline actions in `receive_walk_sheet.dart` to invalidate the feed carousel provider and post a system message to the chat.

### ⏳ Sprint 5: Map Markers & Polish (TODO)
*   **Goal**: Wire map screen to show scheduled walks as markers. Wire notification tap-throughs.

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
