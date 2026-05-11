# Sprint Summary: Map Polish & Push Token Resilience

## Overview
This sprint focused on **two main areas**:
1. **UI Improvements**: Making the map sheet cleaner and easier to understand
2. **Push Notification Fix**: Ensuring users reliably receive notifications by keeping their FCM token up-to-date

---

## Part 1: UI Polish Changes

### File: `lib/screens/map_v2/widgets/simple_place_sheet.dart`

#### What Is This File?
This file displays the bottom sheet that pops up when you tap on a park or location on the map. It shows:
- Check-in status (how many dogs are currently at this location)
- Spotted dogs section (for reporting dogs you see there)
- Buttons to check-in or plan a walk

---

### Change 1: Better Visual Separation for "Spotted Dogs" Section

**The Problem:**
The "Spotted dogs here?" section was getting visually lost among other information. Users couldn't easily distinguish it from the rest of the content.

**The Solution:**
Added visual dividers (horizontal lines) before and after the spotted dogs section to make it stand out.

**Code Changed:**
```dart
// BEFORE - No dividers, just plain text and button
Text('Spotted dogs here?', ...)
Stepper(...)
ElevatedButton(label: 'SPOTTED', ...)

// AFTER - Now has dividers for clarity
Divider(height: 26)  // ← Spacing divider BEFORE
Text('Spotted dogs here?', ...)
Stepper(...)
ElevatedButton(label: 'SPOTTED', ...)
Divider(height: 26)  // ← Spacing divider AFTER
```

**Why This Matters:**
When a user opens the map sheet, they now see a clear visual section for reporting spotted dogs. The dividers act like a "box around" this feature, making it feel intentional and important.

---

### Change 2: Larger, More Prominent "SPOTTED" Button

**The Problem:**
The spotted dogs button was too small and didn't stand out. Users might miss it.

**The Solution:**
Changed from a small `AppButton` to a larger, rounder `ElevatedButton` with rounded corners.

**Code Changed:**
```dart
// BEFORE - Small, subtle button
AppButton(
  size: AppButtonSize.small,
  label: 'Spotted',
  icon: Icons.add,
)

// AFTER - Larger, more prominent button with rounded corners
ElevatedButton(
  style: ElevatedButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),  // ← Makes it fully rounded
    ),
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
  child: Text('SPOTTED', style: TextStyle(fontSize: 16)),  // ← Uppercase and bigger
  onPressed: () => _handleSpottedDogs(),
)
```

**Why This Matters:**
The button is now impossible to miss. Its rounded corners give it a modern, friendly feel that encourages users to tap it. The larger size and uppercase text make it feel like an important action.

---

### Change 3: Better Check-In Copy

**The Problem:**
When a park had zero dogs checked in, the message said "No dogs here right now." But this is confusing because:
- Does it mean "no spotted dogs" or "no checked-in dogs"?
- These are two different pieces of information

**The Solution:**
Changed the message to be specific and clear.

**Code Changed:**
```dart
// BEFORE - Ambiguous
if (_dogCount == 0) {
  Text('No dogs here right now')
}

// AFTER - Crystal clear
if (_dogCount == 0) {
  Text('No checked-in dogs here right now')  // ← Explicit about what we're talking about
}
```

**Why This Matters:**
Now users understand the difference:
- "No checked-in dogs here right now" = no users have actively checked in at this location
- The "Spotted dogs here?" section is for reporting dogs they see (separate from check-ins)

This prevents confusion and helps users understand the app's two-layer system: *checked-in* dogs (users reporting their presence) vs *spotted* dogs (casual sightings).

---

### Change 4: Improved Spacing & Layout

**The Problem:**
Elements were cramped together, making the sheet feel cluttered.

**The Solution:**
Added consistent vertical spacing (gaps) between key sections.

**Code Changed:**
```dart
// BEFORE - Elements pushed together
Column(
  children: [
    Text('Dog Count: $_dogCount'),
    StepperWidget(...),
    ElevatedButton(...),
    Text('Dogs spotted here in the last 24h'),
  ],
)

// AFTER - Proper spacing between sections
Column(
  children: [
    Text('Dog Count: $_dogCount'),
    SizedBox(height: 18),  // ← Breathing room
    StepperWidget(...),
    SizedBox(height: 16),  // ← Breathing room
    ElevatedButton(...),
    SizedBox(height: 16),  // ← Breathing room
    Text('Dogs spotted here in the last 24h'),
  ],
)
```

**Why This Matters:**
Proper spacing makes the UI feel less claustrophobic. Each section gets room to breathe, making the information easier to scan and understand.

---

### Change 5: Enhanced Count Pill (Badge)

**The Problem:**
The small pill showing the count of spotted dogs was hard to read and didn't feel important.

**The Solution:**
Increased padding and font size to make it more prominent.

**Code Changed:**
```dart
// BEFORE - Small and subtle
Container(
  padding: EdgeInsets.all(8),  // ← Small padding
  child: Text(
    '$_spottedCount',
    style: TextStyle(fontSize: 12),  // ← Small font
  ),
)

// AFTER - Larger and easier to read
Container(
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),  // ← More padding
  child: Text(
    '$_spottedCount',
    style: TextStyle(fontSize: 14),  // ← Larger font
  ),
)
```

**Why This Matters:**
The count is now a visual focal point. Users immediately see how many dogs have been spotted at a location without straining their eyes.

---

## Part 2: Park-Only Demo Seeding

### File: `lib/screens/map_v2/map_tab_screen.dart`

#### What Is This File?
This file manages the map display and marker placement. It has logic to automatically seed (add) demo dog activity to locations for testing purposes.

#### The Problem
When the app tests/demos its "spotted dogs" feature, it was randomly adding demo data to *any* location—parks, restaurants, pet stores, etc.

This looked weird to users. Why would there be "spotted dogs" at a coffee shop?

#### The Solution
Filter the demo seeding to only parks—the only place type where "spotted dogs" makes sense.

---

### Change 1: Filter in Auto-Seed Method

**What happens:**
When the app auto-generates test data, it now only picks from park locations.

**Code Changed:**
```dart
// BEFORE - Could seed any location type
void _maybeAutoSeed() {
  final visiblePlaces = _mapPlaces;  // ← Includes all types
  final random = Random().nextInt(visiblePlaces.length);
  final selectedPlace = visiblePlaces[random];
  
  _seedPlace(selectedPlace);
}

// AFTER - Only seeds parks
void _maybeAutoSeed() {
  final visiblePlaces = _mapPlaces;
  
  // Filter down to parks only
  final parksOnly = visiblePlaces
    .where((place) => place.category == PlaceCategory.park)  // ← Only parks!
    .toList();
  
  if (parksOnly.isEmpty) return;  // If no parks visible, don't seed
  
  final random = Random().nextInt(parksOnly.length);
  final selectedPlace = parksOnly[random];
  
  _seedPlace(selectedPlace);
}
```

**Why This Matters:**
Demo data now only appears on realistic locations, making the test data feel authentic.

---

### Change 2: Filter in Admin Seed Method

**What happens:**
When a developer/tester manually triggers seeding via admin controls, it also respects the park-only filter.

**Code Changed:**
```dart
// BEFORE - Could seed anywhere
void _seedVisibleArea() {
  final visiblePlaces = _mapPlaces;  // ← All types
  for (var i = 0; i < 3; i++) {
    final random = Random().nextInt(visiblePlaces.length);
    _seedPlace(visiblePlaces[random]);
  }
}

// AFTER - Seeds only parks
void _seedVisibleArea() {
  final visiblePlaces = _mapPlaces;
  
  // Filter to parks only
  final parksOnly = visiblePlaces
    .where((place) => place.category == PlaceCategory.park)  // ← Only parks!
    .toList();
  
  if (parksOnly.isEmpty) return;
  
  // Seed up to 3 parks
  for (var i = 0; i < 3 && i < parksOnly.length; i++) {
    final random = Random().nextInt(parksOnly.length);
    _seedPlace(parksOnly[random]);
  }
}
```

**Why This Matters:**
Both automatic and manual seeding are now consistent—they both respect the "parks only" rule.

---

## Part 3: Push Token Resilience (The Big One)

### Context: What Are Push Notifications?

Before diving into the code, let's understand the problem:

1. **Push notifications** = messages sent from the server to users' phones
2. To send a notification, the server needs a **token** (like a unique address for that phone)
3. The token is managed by **Firebase Cloud Messaging (FCM)**
4. The token is stored in the **Supabase database** so the server knows where to send notifications

**The Problem:**
If a user doesn't open the app for a week, Firebase might rotate (change) their token. But if the app isn't running, it can't update the stored token in the database. So when the server tries to send a notification using the OLD token, it fails silently. User never gets the notification. 😞

**The Solution:**
When the user opens the app again, immediately check if the stored token is out of date and re-sync it. This ensures we always have the latest address for sending notifications.

---

### File 1: `lib/services/firebase_messaging_service.dart`

This file handles all push notification logic.

---

### Change 1: New Helper Method to Re-Sync Token

**What it does:**
This method is like a "health check" for the FCM token. It:
1. Fetches the current FCM token from the phone
2. Checks what token is stored in the database
3. Updates the database if they don't match

**Code Added:**

```dart
/// Fetch current FCM token and update Supabase if missing or different
/// Called on app resume and initialization to handle stale tokens
static Future<void> _resyncFCMTokenIfNeeded() async {
  try {
    // Step 1: Get the current token from Firebase
    final currentToken = await _firebaseMessaging.getToken();
    if (currentToken == null) {
      debugPrint('⚠️ Could not fetch FCM token for resync');
      return;  // ← If Firebase can't give us a token, abort
    }

    // Step 2: Get the signed-in user
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      debugPrint('ℹ️ No user signed in, skipping token resync');
      return;  // ← If nobody is logged in, nothing to update
    }

    // Step 3: Fetch the stored token from the database
    final stored = await SupabaseConfig.client
        .from('users')  // ← Look in the 'users' table
        .select('fcm_token')  // ← Get just the token column
        .eq('id', user.id)  // ← For this specific user
        .maybeSingle();  // ← Return null if not found (instead of error)

    final storedToken = stored?['fcm_token'] as String?;

    // Step 4: Compare them
    // Update ONLY if different or missing
    if (storedToken != currentToken) {
      // They don't match! Update the database with the new one
      await SupabaseConfig.client
          .from('users')
          .update({'fcm_token': currentToken})  // ← Set to current
          .eq('id', user.id);  // ← For this user

      // Log what happened
      debugPrint('🔄 FCM token re-synced (${storedToken == null ? 'was missing' : 'was stale'})');
      _cachedToken = currentToken;  // ← Remember it for next time
    }
  } catch (e) {
    // If anything goes wrong, just log it and continue
    debugPrint('⚠️ Error re-syncing FCM token: $e');
  }
}
```

**Line-by-Line Explanation:**

| Line | What It Does | Why It Matters |
|------|-----------|-------|
| `final currentToken = await _firebaseMessaging.getToken();` | Ask Firebase "what's the current token for this device?" | We need to know what the latest token is |
| `if (currentToken == null) { return; }` | If Firebase couldn't give us a token, stop | Can't proceed without a token |
| `final user = SupabaseConfig.auth.currentUser;` | Check who's logged in | We need to know whose token to update |
| `if (user == null) { return; }` | If nobody's logged in, stop | Can't save a token without knowing who it belongs to |
| `final stored = await SupabaseConfig.client.from('users').select('fcm_token').eq('id', user.id).maybeSingle();` | Query the database: "What token do we have stored for this user?" | We need to compare old vs new |
| `final storedToken = stored?['fcm_token'] as String?;` | Extract the token from the database result | Get the value we queried |
| `if (storedToken != currentToken) { ... }` | "Are they different?" | Only update if there's actually a change |
| `await SupabaseConfig.client.from('users').update({'fcm_token': currentToken}).eq('id', user.id);` | Update the database with the new token | Save the latest address |
| `debugPrint('🔄 FCM token re-synced ...');` | Log what happened | Helps developers debug if something goes wrong |

---

### Change 2: Public Wrapper Method

**What it does:**
The method above is `private` (starts with `_`), which means it can only be called from inside this service. We need a `public` method (no underscore) that other parts of the app can call.

**Code Added:**

```dart
/// Public method to resync the FCM token
/// Called when the app returns to the foreground
static Future<void> resyncTokenOnAppResume() async {
  await _resyncFCMTokenIfNeeded();
}
```

**Why We Need This:**
- `_resyncFCMTokenIfNeeded()` is the actual logic (private)
- `resyncTokenOnAppResume()` is the public interface (can be called from other files)
- This separation keeps internal implementation details hidden

Think of it like:
- `_resyncFCMTokenIfNeeded()` = the engine
- `resyncTokenOnAppResume()` = the starter button you press

---

### Change 3: Call Re-Sync During Initialization

**What it does:**
When the app first starts, immediately check if the token needs updating.

**Code Changed:**

```dart
// In the initialize() method, around line 70-80

static Future<void> initialize() async {
  // ... other initialization code ...
  
  // Step 1: Get and store the initial token
  await _getAndStoreFCMToken();
  
  // Step 2: NOW, check if it needs resync (might have changed while app was closed)
  await _resyncFCMTokenIfNeeded();  // ← NEW!
  
  // Step 3: Set up listeners for future changes
  _setupMessageHandlers();
  
  debugPrint('✅ Firebase Messaging initialized successfully');
}
```

**Why This Matters:**
The app starts, and immediately checks: "Is my stored token still accurate?" If it's stale, it updates right away.

---

### File 2: `lib/services/notification_manager.dart`

#### What Is This File?
This file orchestrates all notification-related services. It's like the conductor of a notification orchestra.

---

### Change: Call Re-Sync When App Returns to Foreground

**What it does:**
When a user brings the app back to the foreground (after being away), we re-sync the token.

**Code Changed:**

```dart
/// Called when the app returns to the foreground
void onAppResumed() async {
  // Sync badge counts (existing code)
  await NotificationService.syncBadgeCount();
  
  // RE-SYNC FCM TOKEN (new code)
  // If the app was in background for a while, FCM might have rotated our token.
  // Get the latest token and update Supabase if needed.
  unawaited(FirebaseMessagingService.resyncTokenOnAppResume());
}
```

**Line-by-Line Explanation:**

| Code | Meaning |
|------|---------|
| `void onAppResumed()` | Method called when app comes to foreground |
| `await NotificationService.syncBadgeCount();` | Update badge counts (existing) |
| `unawaited(...)` | Start this in the background; don't wait for it to finish |
| `FirebaseMessagingService.resyncTokenOnAppResume();` | Call the public wrapper we created |

**Why `unawaited`?**
- We don't want to slow down the app resume by waiting for the token sync
- It's okay if it happens in the background
- But we still want it to happen

---

## Summary: How the Push Token Fix Works

### The Flow (User Perspective)

```
Day 1: User opens app
  └─ App stores FCM token in database

Days 2-6: User closes app, leaves phone
  └─ Firebase rotates the token (changes it for security)

Day 7: User opens app again
  └─ App calls onAppResumed() (because app was backgrounded)
    └─ Calls resyncTokenOnAppResume()
      └─ Runs _resyncFCMTokenIfNeeded()
        └─ Fetches current token from Firebase
        └─ Compares against database
        └─ Updates database if different
  └─ ✅ Database now has correct token
  └─ ✅ Next push notification will be delivered!
```

### The Flow (Code Perspective)

```
initialize()
  └─ _getAndStoreFCMToken()      # Store initial token
  └─ _resyncFCMTokenIfNeeded()   # Check if it needs update right away
  └─ _setupMessageHandlers()     # Listen for future Firebase token rotations

(App returns from background)

onAppResumed()
  └─ syncBadgeCount()
  └─ resyncTokenOnAppResume()    # Check again if token is stale
    └─ _resyncFCMTokenIfNeeded()
```

---

## What Changed in Database

### `users` table in Supabase

The `fcm_token` column (which already existed) is now being kept more up-to-date:

```
BEFORE (unreliable):
  users.fcm_token only updated when:
  - User first signs in
  - Firebase rotates the token (but only if app is open)

AFTER (reliable):
  users.fcm_token updated when:
  - User first signs in ✓
  - Firebase rotates the token ✓
  - User opens app after being away ✓ NEW!
  - User resumes app after backgrounding ✓ NEW!
```

---

## For Testing

### How to Verify the Fix Works

1. **Initial state**: Open app → watch console for token sync
2. **Wait & return**: Close app for ~1 minute, reopen → check database for token update
3. **Manual seed**: Use admin tools to trigger token rotation → watch console for re-sync message
4. **Database check**: Query the `users` table → `fcm_token` should be current

### What to Look For in Logs

✅ **Good signs:**
```
✅ Firebase Messaging initialized successfully
🔄 FCM token re-synced (was missing)     # On first app open
🔄 FCM token re-synced (was stale)       # After returning from background
```

❌ **Bad signs:**
```
⚠️ Could not fetch FCM token for resync  # Firebase token unavailable
ℹ️ No user signed in, skipping token resync  # Expected if user not logged in
⚠️ Error re-syncing FCM token: ...       # Something went wrong in sync
```

---

## Architecture Diagram

```
Firebase Cloud Messaging
      ↓ (owns token generation)
Phone's Local FCM Token
      ↓ (we fetch this)
App Service (firebase_messaging_service.dart)
      ↓ (we resync if stale)
Supabase Database
      ↓ (server reads from here)
Push Notification Server
      ↓ (sends notifications to stored token address)
User's Phone
```

---

## Why This Matters

**Before this fix:**
- User closes app for a week
- FCM rotates their token
- User opens app after a week
- App doesn't know the new token
- Server still has the old token
- Push notifications never arrive
- User misses playdate invitations, chat messages, etc. 😞

**After this fix:**
- User closes app for a week
- FCM rotates their token
- User opens app after a week
- App immediately checks token status
- Token is out of date → updates database
- Server now has correct token
- Push notifications are delivered reliably ✅

---

## Summary Table: All Changes

| File | Change | Purpose | Impact |
|------|--------|---------|--------|
| `simple_place_sheet.dart` | Added dividers before/after spotted dogs section | Visual clarity | UI looks cleaner and more organized |
| `simple_place_sheet.dart` | Made SPOTTED button larger and rounder | Increased visibility | Users more likely to report spotted dogs |
| `simple_place_sheet.dart` | Changed "No dogs here" to "No checked-in dogs here right now" | Clarity | Users understand the difference between checked-in and spotted |
| `simple_place_sheet.dart` | Increased spacing between elements | Reduced clutter | UI feels less cramped |
| `simple_place_sheet.dart` | Increased count pill padding and font | Better readability | Easier to see spotted dog counts |
| `map_tab_screen.dart` | Filter auto-seed to parks only | Realistic test data | Demo activity appears only in logical locations |
| `map_tab_screen.dart` | Filter admin-seed to parks only | Consistent seeding | Admin seeding follows same rules as auto-seed |
| `firebase_messaging_service.dart` | Added `_resyncFCMTokenIfNeeded()` | Token reliability | Catches stale tokens |
| `firebase_messaging_service.dart` | Added `resyncTokenOnAppResume()` | Public interface | Other services can trigger resync |
| `firebase_messaging_service.dart` | Call resync in `initialize()` | Early detection | Fixes stale tokens on first app open |
| `notification_manager.dart` | Call resync in `onAppResumed()` | Timely updates | Fixes stale tokens when returning from background |

---

## Questions for Team Discussion

1. **Monitoring**: Should we add metrics to track how often tokens are being re-synced?
2. **Performance**: Is checking the database on every app resume acceptable, or should we add a timeout (e.g., only check if 5+ minutes have passed)?
3. **Testing**: Should we add automated tests for the token sync logic?

