# BarkDate Playdates & Notifications — 3-Week Implementation Sprint

## Overview
This sprint delivers a complete, resilient playdate + notifications system with real-time updates, great UX, and end-to-end workflows. We will change existing code where it simplifies the experience.

## Workflow Map (Source of Truth)

### Playdate lifecycle & notifications
- Invite sent (organizer → invitee):
  - Write: playdate_request
  - Notify invitee: type=playdate_request, metadata={playdate_id, organizer_id, organizer_dog_id, organizer_dog_name, invitee_id, invitee_dog_id, scheduled_at, location}
- Accept:
  - Update: playdates.status=confirmed; insert invitee into playdate_participants
  - Notify organizer (and optionally participants): type=playdate, actionType=playdate_accepted, metadata={playdate_id, responder_name}
- Decline:
  - Update: playdates.status=cancelled
  - Notify organizer: type=playdate, actionType=playdate_declined, metadata={playdate_id, message?}
- Counter-propose:
  - Update: playdate_requests.counter_proposal={time/location}
  - Notify organizer: type=playdate, actionType=playdate_counter_proposed, metadata={playdate_id, counter_proposal}
- Organizer updates details (time/location/notes):
  - Update: playdates fields + updated_at
  - Notify all other participants: type=playdate, actionType=playdate_updated, metadata={playdate_id, changes}
- Organizer cancels:
  - Update: playdates.status=cancelled
  - Notify all participants: type=playdate, actionType=playdate_cancelled, metadata={playdate_id}
- Reschedule (time/location):
  - Same as update + notification actionType=playdate_updated
- Add/remove dogs (participants):
  - Add: insert playdate_participants; notify added user: type=playdate, actionType=participant_added
  - Remove: delete playdate_participants; notify organizer: type=playdate, actionType=participant_removed
- Recap posted (optional next sprint):
  - Notify participants: type=social or type=playdate, actionType=recap_posted

### Social / Bark / Feed
- Bark → target owner: type=bark, actionType=bark_received, metadata={from_user_id, from_dog_id, from_dog_name}
- Social like/comment (future tighten): type=social, actionType=liked/commented, metadata={post_id, actor}

---

## Week 1 — Core Workflows Complete (Create, Respond, Update)

### Goals
Fully working playdate invitations, responses, updates, and notifications with stable UI and real-time sync.

### Backend
- Finalize PlaydateRequestService contracts with normalized metadata.
- Add service methods:
  - addParticipant(playdateId, userId, dogId) → notification: participant_added
  - removeParticipant(playdateId, userId, dogId) → notification: participant_removed
  - cancelPlaydate(playdateId, byUserId) → notification: playdate_cancelled
  - reschedulePlaydate(playdateId, byUserId, newTime/newLocation) → notification: playdate_updated
- Ensure every state transition writes a notification with actionType + minimal metadata for deep-linking.

### Frontend
- PlaydateRequestModal: validation + error states; ensures notification metadata carries playdate_id.
- NotificationsScreen:
  - Real-time stream (DONE)
  - Action wiring:
    - playdateRequest → Accept/Decline/Counter (opens PlaydateResponseModal)
    - playdate_updated → deep-link to PlaydatesScreen detail
    - participant_added/removed → “View participants”
    - playdate_cancelled → mark read
- PlaydatesScreen:
  - Sections: Pending (incoming), Upcoming (confirmed), Past
  - Pending: Accept/Decline/Counter
  - Upcoming: Edit (time/location/notes), Add/Remove Dogs, Cancel
  - Add real-time subscriptions to playdates & playdate_participants

### QA
- E2E: Invite → Receive notification → Accept/Decline/Counter → Notifications update → Upcoming reflects live.
- Negative path: Missing metadata / invalid transitions handled gracefully.

---

## Week 2 — Advanced Scenarios (Reschedule, Multi-Dog, UX polish)

### Goals
Rescheduling + multi-dog participation flows finalized; consistent UX patterns.

### Backend
- Enforce organizer-only updates; on counter-proposal acceptance, convert into accepted update and notify.
- Participant add/remove writes participant-level notifications and organizer confirmations.

### Frontend
- PlaydatesScreen:
  - Reschedule bottom sheet: datetime + location pickers, optimistic UI
  - Add/Remove Dogs: picker from user’s dogs; reflect live
  - Detail view: full metadata (location, time, participants, notes) with action shortcuts
- NotificationsScreen: quick mark-read on all types, optimized grouped view

### UX polish
- Consistent chips and action rows inspired by modern chat UIs (inspiration only: FluffyChat build polish `https://github.com/krille-chan/fluffychat/wiki/How-To-Build`).
- Standardize snackbars and error handling across flows.

### QA
- E2E reschedule: Organizer updates → participants see playdate_updated notification → lists reflect live
- Multi-dog: Add participant → notification to added user; remove → organizer notified
- Cancel flow: All participants receive playdate_cancelled; Upcoming cleared

---

## Week 3 — Quality, Completeness, and Nice-to-Haves

### Goals
Robustness, reliability, and final polish.

### Backend
- Guard rails: prevent duplicate invites for same user/dog; block updates on cancelled/completed; explicit errors.
- Optional reminders: day-of notifications (can defer if push infra is not ready).

### Frontend
- Unread badge counts in app bar (live).
- Deep linking: every notification takes the user to the correct screen/sub-view.
- Empty/error states audited; loading skeletons for lists.

### QA & Performance
- Real device tests (iOS/Android/Web)
- Virtualized long lists; measure/reduce jank
- Network failure simulations

---

## Notifications Matrix (Final)

- Invite sent → invitee: type=playdate_request
- Accept → organizer: type=playdate, actionType=playdate_accepted
- Decline → organizer: type=playdate, actionType=playdate_declined
- Counter-propose → organizer: type=playdate, actionType=playdate_counter_proposed, metadata={counter_proposal}
- Update (time/location/notes) → other participants: type=playdate, actionType=playdate_updated
- Cancel → all participants: type=playdate, actionType=playdate_cancelled
- Participant added → added user: type=playdate, actionType=participant_added
- Participant removed → organizer: type=playdate, actionType=participant_removed
- Bark → target owner: type=bark, actionType=bark_received
- Social like/comment → post owner: type=social, actionType=liked/commented

---

## Known Issue & Mitigation

**DebugService: “Unsupported operation: Cannot send Null” (Web debug spam)**
- Cause: stream/event created before user is available or null payload on platform channel.
- Mitigation:
  - Guard all streams behind non-null user checks (done for notifications).
  - Add try/catch around listeners to avoid propagation.
  - Apply same guards when adding playdates/participants realtime to PlaydatesScreen.

---

## Deliverables Checklist

- [ ] Backend: addParticipant/removeParticipant/cancel/reschedule APIs
- [ ] Backend: all notifications emit complete metadata
- [ ] Frontend: PlaydatesScreen actions wired (accept/decline/counter/update/add/remove/cancel)
- [ ] Frontend: Realtime subscriptions for playdates + participants
- [ ] Frontend: Notification actions deep-link everywhere
- [ ] QA: E2E flows; negative tests; performance checks

---

## Notes
- We will change existing code where beneficial; simplicity > legacy decisions.
- Real-time is prioritized for Notifications & Playdates; push can be a follow-up if needed.
- UI quality will favor clarity and consistency across screens.
