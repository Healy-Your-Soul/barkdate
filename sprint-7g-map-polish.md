# Sprint 7g — Map Polish (Walk Visibility + Marker Sizing + Info Tooltip)

> **Goal in one sentence:** Fix the bug where scheduled future walks don't appear on the web user's map (despite showing correctly on iOS), shrink the walk-marker circles so they don't dominate the map, and modernize the walk tooltip shown above markers.
>
> **Branch:** `map/walk-visibility-and-polish`
> **Estimated effort:** ~2–3 hours (most of it is the custom tooltip widget — the other two are quick)
> **Dependencies:** Sprint 6 (walk markers), Sprint 7f (WalkRealtimeService)
> **Blocks:** Nothing
>
> **TL;DR for a new dev:** Three separate map issues rolled into one sprint because they all touch `map_tab_screen.dart` and `dog_marker_generator.dart`. (A) Scheduled walks aren't appearing on GG's web screen because `getScheduledWalksForMap()` fetches all future playdates but the map only renders them once during `_fetchPlacesAndEvents` — the 30-second refresh timer calls `_refreshScheduledWalks()` correctly, but on web the initial fetch races with the live-user debug-marker logic and can silently fail. (B) Walk marker circles at `size: 88` are visually too large compared to dog markers at `size: 42` — we want them ~1.15–1.2× dog markers. (C) The tooltip showing "Lizzy · 10:00 AM / Walk at Woodville Reserve" above the walk marker uses Google Maps' native `InfoWindow` — which renders as a plain white bubble with system font, can't be styled, and doesn't match our design language.

---

## Why this matters — screenshots from user testing

Looking at the two screenshots side-by-side:

| GG's screen (web) | Lizzy's screen (iOS) |
|---|---|
| Shows only the "You" marker with GG's dog photo. No scheduled walk markers visible. No blue circle markers. | Shows multiple dog markers AND scheduled walk markers with blue circles. The tooltip above one shows "Lizzy · 10:00 AM / Walk at Woodville Reserve" in the native InfoWindow style. |

Three issues:
1. **Walk markers missing on GG's screen** — either `getScheduledWalksForMap()` returned an empty list for the web session, or the walks were fetched but not rendered because the markers were overwritten by a later `_updateMarkers()` call.
2. **Walk circles are too big** — at `size: 88` (in `createScheduledWalkMarker`) they're twice the diameter of regular dog markers (`size: 42`). On a phone screen they cover nearby markers and look disproportionate.
3. **The native `InfoWindow` tooltip is ugly** — Google Maps' `InfoWindow` is an opaque white rectangle with rounded corners, system font, and a downward caret. It can't be customized with colors, icons, or typography. The text "Lizzy · 10:00 AM" with a clock emoji is functional but feels dated.

---

## Why this happened — tracing the data flow

### Sub-task A: Missing walk markers on web

The data flow for scheduled walks:

```
initState()
  → _getUserLocation()
    → _fetchPlacesAndEvents()
      → _refreshScheduledWalks()   ← first fetch
        → FriendActivityService.getScheduledWalksForMap()
        → _updateMarkers()         ← markers built
```

Then every 30 seconds:
```
Timer.periodic(30s)
  → _refreshScheduledWalks()
  → _refreshCheckInCounts()
```

**Problem 1: Web initial load race.**

On web, `_refreshLiveUsers()` (line 323) runs concurrently with `_refreshScheduledWalks()`. The live-users function calls `_updateLiveUserMarkers()` and then `_updateMarkers()`. If `_refreshLiveUsers()` completes AFTER `_refreshScheduledWalks()`, it calls `_updateMarkers()` with `_scheduledWalks` potentially still empty (the walk fetch hadn't completed yet). The walks are then never re-rendered because the subsequent `_updateMarkers()` from `_refreshScheduledWalks()` runs fine — but on web, the Google Maps widget sometimes doesn't re-render markers that were set during a previous frame if the widget was still initializing.

**Root fix:** Ensure `_refreshScheduledWalks()` always triggers a marker rebuild, and fix the concurrent _updateMarkers race.

**Problem 2: No realtime subscription for playdates on the map.**

The `_setupCheckinSubscription()` (line 117) only listens to the `checkins` table. When someone creates or confirms a playdate (in the `playdates` table), there's no realtime trigger to refetch walk markers. The only mechanism is the 30-second timer. If GG opened the map before any walks existed, they'd have to wait up to 30 seconds AND the timer's `_refreshScheduledWalks()` would need to succeed.

Sprint 7f added `WalkRealtimeService` which already has a `playdates` channel. But the map tab screen doesn't subscribe to it yet.

> [!IMPORTANT]
> **We intentionally keep showing ALL users' scheduled walks on the map** (not just the current user's). This is a deliberate product choice — showing walk activity from all users creates a sense that the app is alive and that people are using it. It's social proof and encourages new users to engage. Do NOT add user-scoping filters to `getScheduledWalksForMap()`.

### Sub-task B: Walk circles too large

In `dog_marker_generator.dart` line 302–306:

```dart
static Future<BitmapDescriptor> createScheduledWalkMarker({
  required String? organizerDogPhotoUrl,
  String? inviteeDogPhotoUrl,
  int size = 88,   // ← DEFAULT IS 88px
})
```

And in `map_tab_screen.dart` line 568, it's called without overriding `size`:

```dart
final icon = await DogMarkerGenerator.createScheduledWalkMarker(
  organizerDogPhotoUrl: organizerDogPhotoUrl,
  inviteeDogPhotoUrl: inviteeDogPhotoUrl,
  // size defaults to 88
);
```

Regular dog markers use `size: 42` with `borderWidth: 3`. The walk marker is 2.1× the diameter — way too prominent. On the screenshot, the light blue circle (pending walk) and the dark blue circle (confirmed) both dwarf the nearby dog markers.

**Fix:** Reduce to **1.15–1.2× the dog marker size** for both pending and confirmed walks:

| Marker type | Current size | New size | Ratio to dog marker (42px) |
|---|---|---|---|
| Pending walk (single dog) | 88px | **48px** | 1.14× |
| Confirmed walk (two dogs) | 88px | **50px** | 1.19× |

Why these sizes:
- **48px for pending** — just slightly larger than a dog marker, enough to signal "scheduled walk" via the blue ring + clock badge, without dominating.
- **50px for confirmed** — 2px more to give the side-by-side dog photos a tiny bit of breathing room. Both photos will be tighter but still distinguishable.

### Sub-task C: InfoWindow → Custom tooltip

> [!NOTE]
> **Why not use Google Advanced Markers?**
>
> The user linked to [Google Advanced Markers for iOS SDK](https://developers.google.com/maps/documentation/ios-sdk/advanced-markers/overview). Advanced Markers let you customize marker background, border, glyph, and icon natively — and they require a `mapID` from Google Cloud Console. However:
>
> 1. **We're using Flutter, not native iOS.** The `google_maps_flutter` Flutter plugin does NOT support Advanced Markers. It uses the older `Marker` + `BitmapDescriptor` API. Our custom marker rendering (in `DogMarkerGenerator`) already achieves what Advanced Markers offers — custom icons rendered as `BitmapDescriptor.bytes()`.
>
> 2. **Advanced Markers don't solve the InfoWindow styling problem.** Even with Advanced Markers, the `InfoWindow` is still the same plain white native bubble — Google doesn't let you style InfoWindow content with custom fonts, colors, or layout. To get a fully styled tooltip, you need a **custom Flutter widget overlay** positioned above the marker. That's what we're doing.
>
> 3. **We're already doing "advanced markers" the Flutter way.** `DogMarkerGenerator` creates circular dog photos with colored borders, clock badges, two-dog overlapping layouts — all rendered via Canvas and returned as `BitmapDescriptor`. This is equivalent to what Advanced Markers provides, just through Flutter's rendering pipeline.
>
> **Bottom line:** We're NOT getting rid of InfoWindow by switching to Advanced Markers. We're replacing the native InfoWindow with a **custom Flutter widget overlay** (same pattern we already use for the `DogMiniCard` popup when tapping a live dog marker). The native InfoWindow gets set to `InfoWindow.noText` so it doesn't show, and we render our own styled card instead.

---

## Current map zoom behavior

For context, here's how the map zoom works today:

| Setting | Value | What it means |
|---|---|---|
| Default zoom (initial state) | `13.0` | Set in `MapViewportController` constructor (line 69 of `map_viewport_provider.dart`). Shows roughly a 5–6 km wide area. |
| User location zoom | `14.0` | Set in `_getUserLocation()` when the user's GPS position is found (line 170 of `map_tab_screen.dart`). Shows roughly a 2–3 km wide area — a neighborhood-level view. |
| Recenter zoom | `14.0` | When user taps "recenter" (line 108 of `map_viewport_provider.dart`). |
| Default center | Perth (-31.9505, 115.8605) | Fallback before GPS kicks in. |

**Google Maps zoom scale reference:**
- Zoom 10 → ~30 km visible (city-wide)
- Zoom 12 → ~8 km visible (district)
- Zoom 13 → ~5 km visible (large neighborhood)
- **Zoom 14 → ~2.5 km visible (neighborhood)** ← where we land
- Zoom 15 → ~1.2 km visible (blocks)
- Zoom 16 → ~600m visible (street-level)

The current zoom 14 is a good default for a dog-walking app — you can see nearby parks within walking distance. Zooming closer (e.g., 15) would show fewer parks but more detail; farther (13) would show more parks but markers get crowded.

---

## Sub-task A — Fix walk marker visibility on web

### Changes

#### 1. Subscribe map to `WalkRealtimeService` changes

In `map_tab_screen.dart`'s `initState`, add a subscription so walk markers update instantly:

```dart
StreamSubscription? _walkRealtimeSub;

@override
void initState() {
  super.initState();
  // ... existing code ...

  // Listen for realtime walk changes (Sprint 7f singleton)
  _walkRealtimeSub = WalkRealtimeService().changes.listen((_) {
    if (mounted) _refreshScheduledWalks();
  });
}

@override
void dispose() {
  _walkRealtimeSub?.cancel();
  // ... existing code ...
}
```

#### 2. Fix the race condition in `_fetchPlacesAndEvents()`

Ensure all data is loaded before calling `_updateMarkers()` once:

```dart
// Current: each refresh function calls _updateMarkers() independently.
// Fix: await all refreshes, then call _updateMarkers() ONCE.

await Future.wait([
  _refreshCheckInCounts(),
  _refreshOtherUsersCheckIns(),
  _refreshLiveUsers(),
  _refreshScheduledWalks(),
]);

_updateMarkers(); // Single call after all data is loaded
```

Remove the `_updateMarkers()` calls from inside each individual refresh function when called from `_fetchPlacesAndEvents`. But keep them for standalone refreshes (e.g., the 30s timer calling `_refreshScheduledWalks` alone still needs to call `_updateMarkers` at the end).

### Verification

1. Sign in as GG on web. Create a walk via Lizzy on iOS. **Expected:** GG's map shows the walk marker within 2 seconds (via realtime), not after 30s.
2. GG signs in fresh, with an existing walk already created. **Expected:** Walk marker appears on first map load (no race).
3. All users see all scheduled walks globally. **Expected:** Social proof — third-party users see walk activity across the platform.

---

## Sub-task B — Shrink walk marker circles

### Changes

In `map_tab_screen.dart`, line 568, pass an explicit `size`:

```dart
final icon = await DogMarkerGenerator.createScheduledWalkMarker(
  organizerDogPhotoUrl: organizerDogPhotoUrl,
  inviteeDogPhotoUrl: inviteeDogPhotoUrl,
  size: isConfirmed ? 50 : 48,  // was: default 88. Now ~1.15-1.19× dog markers (42px)
);
```

The `DogMarkerGenerator.createScheduledWalkMarker` already accepts a `size` parameter (line 302), so no changes needed there.

### Verification

1. View map with both pending and confirmed walks. **Expected:** Circles are slightly larger than regular dog markers (~1.15×), not dominating the map.
2. Two-dog confirmed marker at `size: 50`: both dog photos still distinguishable. If photos are too cramped at 50, bump to 52 — still within the 1.2× ceiling.
3. Clock badge in top-right corner: still readable at smaller size.

---

## Sub-task C — Custom tooltip widget for walk markers

### What we have today

The tooltip above Lizzy's walk marker is a Google Maps native `InfoWindow`:
- Plain white bubble, system font
- `title`: "🕐 Lizzy • 10:00 AM"
- `snippet`: "Walk at Woodville Reserve"
- Cannot be styled — no custom colors, icons, or typography

### The fix — custom `WalkMarkerTooltip` widget overlay

We already have the pattern for custom popups: `_selectedLiveDog` shows a `DogMiniCard` positioned above the map. We'll do the same for walk markers.

#### New state:

```dart
Map<String, dynamic>? _selectedWalkMarker;
```

#### New widget: `WalkMarkerTooltip`

A compact floating card:
- Left: small clock icon (pending) or paw-print icon (confirmed) in a colored circle
- Center: dog name + time (bold), park name (light, smaller)
- Background: white with subtle shadow (consistent with DogMiniCard)
- Accent color: walk-blue (`#0D47A1` confirmed, `#64B5F6` pending)
- Tap opens the WalkDetailsSheet

```dart
class WalkMarkerTooltip extends StatelessWidget {
  final String dogName;
  final String? inviteeDogName;
  final String time;
  final String parkName;
  final bool isConfirmed;
  final VoidCallback onTap;
  final VoidCallback onClose;

  // ... build method renders a compact, styled card ...
}
```

#### Marker changes:

Replace `InfoWindow` with `InfoWindow.noText` on walk markers, and use `onTap` to set `_selectedWalkMarker` (show tooltip). Tapping the tooltip opens the WalkDetailsSheet:

```dart
// Current: onTap opens sheet directly
// New: onTap shows tooltip; tooltip has a tap that opens sheet

infoWindow: InfoWindow.noText,  // Remove native InfoWindow
onTap: () {
  setState(() => _selectedWalkMarker = walk);
},
```

The tooltip is positioned as an overlay in the map stack (same as `DogMiniCard`), above the marker's position.

### Verification

1. Tap a walk marker. **Expected:** Custom tooltip appears with dog name, time, park name in a modern styled card. No native InfoWindow.
2. Tap the tooltip. **Expected:** `WalkDetailsSheet` opens.
3. Tap the map elsewhere. **Expected:** Tooltip dismisses.
4. Tooltip should be readable on both light and dark map backgrounds.

---

## Pre-flight reading

- `lib/screens/map_v2/map_tab_screen.dart` lines 265–280 — `_refreshScheduledWalks` and the race condition
- `lib/screens/map_v2/map_tab_screen.dart` lines 536–596 — walk marker construction (Sub-tasks B+C)
- `lib/utils/dog_marker_generator.dart` lines 290–455 — `createScheduledWalkMarker` and sizing (Sub-task B)
- `lib/services/walk_realtime_service.dart` — singleton from Sprint 7f (Sub-task A wiring)
- `lib/screens/map_v2/widgets/dog_mini_card.dart` — existing custom popup pattern (Sub-task C reference)
- `lib/screens/map_v2/providers/map_viewport_provider.dart` — zoom/viewport settings

---

## Files to modify

| Sub-task | File | Change |
|---|---|---|
| A | `lib/screens/map_v2/map_tab_screen.dart` | Subscribe to `WalkRealtimeService.changes`; fix race in `_fetchPlacesAndEvents` by `Future.wait` + single `_updateMarkers` |
| B | `lib/screens/map_v2/map_tab_screen.dart` | Pass `size: isConfirmed ? 50 : 48` to `createScheduledWalkMarker` |
| C | `lib/screens/map_v2/map_tab_screen.dart` | Add `_selectedWalkMarker` state; replace `InfoWindow` with `InfoWindow.noText`; render `WalkMarkerTooltip` overlay in build |
| C | `lib/screens/map_v2/widgets/walk_marker_tooltip.dart` (NEW) | New widget: compact styled tooltip card for walk markers |

---

## Verification matrix

| # | Setup | Action | Expected | Sub-task |
|---|---|---|---|---|
| 1 | GG on web, no walks exist | Lizzy creates walk on iOS | Walk marker appears on GG's map within 3s | A |
| 2 | GG opens map fresh with existing walk | — | Walk marker visible on first render | A |
| 3 | Any user opens map | — | Sees all scheduled walks globally (social proof) | A |
| 4 | Pending walk marker visible | Visual check | Circle is ~48px, roughly 1.14× regular dog markers (42px) | B |
| 5 | Confirmed walk marker (two dogs) | Visual check | Circle is ~50px (~1.19×), both dogs readable | B |
| 6 | Tap walk marker | — | Custom tooltip appears (not native InfoWindow) | C |
| 7 | Tap tooltip | — | WalkDetailsSheet opens | C |
| 8 | Tap elsewhere on map | — | Tooltip dismisses | C |
| 9 | iOS regression: all map features | — | Dog markers, check-ins, live users, places all unchanged | All |

---

## Out of scope

- ❌ Custom tooltip for regular dog markers (they already use `DogMiniCard` — different pattern, already works)
- ❌ Google Advanced Markers API migration (not supported by `google_maps_flutter` plugin — see note above)
- ❌ User-scoped walk filtering (deliberately showing all walks for social proof)
- ❌ Map dark mode / theming — separate feature
- ❌ Walk marker animations (pulse, bounce) — Sprint 8+
- ❌ Tap-to-navigate-to-park from the tooltip — separate UX decision

---

## Hand-off notes

1. **Sub-task A is the functional bug.** The race condition in `_fetchPlacesAndEvents` is the root cause — four async functions all call `_updateMarkers()` independently, and the one that finishes last wins. Fix by removing per-function `_updateMarkers()` calls inside `_fetchPlacesAndEvents` and calling it once after `Future.wait`. Each standalone refresh (30s timer) still needs its own `_updateMarkers()` call.

2. **Sub-task B is a one-line change.** Just pass the `size` parameter. Don't overcomplicate it. If 48/50 feels too tight visually after testing, bump to 50/52 — stay within the 1.2× ceiling.

3. **Sub-task C follows the `DogMiniCard` pattern exactly.** The tooltip is positioned as an overlay in the `Stack` that wraps the `GoogleMap` widget. Use `_selectedWalkMarker` to toggle visibility, same as `_selectedLiveDog` toggles `DogMiniCard`.

4. **The `InfoWindow` removal (Sub-task C) means losing the built-in "tap marker to show info" behavior.** Make sure `onTap` on the marker reliably fires — on web, Google Maps markers sometimes swallow taps if the `zIndex` is wrong. Test carefully.

5. **Do NOT scope walks to the current user.** Showing all walks globally is intentional social proof — it makes the app feel active and encourages engagement. Every user should see every scheduled walk on the map.

6. **Web testing is mandatory.** Sub-task A specifically fixes a web-only bug. iOS-only verification is not enough.
