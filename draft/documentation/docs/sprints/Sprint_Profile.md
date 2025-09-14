# Sprint: Profile Tab Completion (Owner/Dog Profiles, Media, Settings)

## Goals
- Complete owner/dog edit flows with media uploads and live stats.
- Implement key settings like notification prefs and account deletion.

## Scope
- Client
  - Finish `CreateProfileScreen` flows for owner and dog, with validation.
  - Photo upload via Supabase Storage with progress; update profile on success.
  - Replace fake stats with real counts (playdates, friends, posts).
  - Settings: notification toggles (in-app/push), logout, account deletion.
- Backend
  - Ensure users/dogs schemas match UI; add fields as needed.
  - Storage buckets and public/private access patterns; RLS-enforced read paths.
  - RPC `delete_user_account` wired from UI.

## Deliverables
- Reliable profile editing including photo upload and instantaneous display.
- Real stats and working settings.

## Acceptance Criteria
- Owner and dog edits persist and reflect after save.
- Account deletion cleans up storage and DB and signs user out.

## Tasks
1) Backend
   - Verify `users`, `dogs` columns, storage buckets, and policies.
   - Ensure delete RPCs exist and are permissioned.
2) Client
   - Finish edit flows; add progress/error handling for uploads.
   - Stats service to compute counts; cache in memory.
   - Settings toggles stored in `SettingsService` and respected by notification manager.
3) QA & polish
   - Avatar fallbacks, error states, empty states.

## Risks/Notes
- Storage URL signing vs public buckets—choose consistent strategy.
- Large image compression before upload for performance.
