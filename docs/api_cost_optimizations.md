# 💰 Google Maps API Cost Optimizations Reference

> **Created:** January 2, 2026  
> **Purpose:** Document removed features for future re-enabling when budget allows

---

## 📋 Summary of Changes

We optimized Google Maps API costs by:
1. Removing expensive Place Search fields (photos, ratings)
2. Adding session token management for Autocomplete

---

## 🔴 Removed Fields (Places Search)

**File:** `lib/services/places_service.dart`  
**Function:** `searchDogFriendlyPlaces()`  
**Line:** ~142-155

### Current (Cost-Optimized) Fields:
```dart
final fields = [
  'id',              // Basic - FREE
  'displayName',     // Basic - FREE
  'formattedAddress', // Basic - FREE
  'location',        // Basic - FREE
  'primaryType',     // Basic - FREE
  'businessStatus',  // Basic - FREE
];
```

### To Re-Enable Ratings & Photos:
```dart
final fields = [
  'id',
  'displayName',
  'formattedAddress',
  'location',
  'primaryType',
  'businessStatus',
  // UNCOMMENT BELOW TO RE-ENABLE (costs $$$):
  'rating',          // Advanced - ~$0.005/request
  'userRatingCount', // Advanced - ~$0.005/request
  'photos',          // Advanced - ~$0.007/photo
  'openingHours',    // Advanced - ~$0.005/request
];
```

### Cost Estimates:
| Field | Cost Per Request | 1000 Users/Day |
|-------|------------------|----------------|
| rating | $0.005 | $5/day |
| userRatingCount | $0.005 | $5/day |
| photos | $0.007/photo | $7-35/day |
| openingHours | $0.005 | $5/day |
| **Total if all enabled** | | **$20-50/day** |

---

## 🟢 Added: Session Token Manager

**File:** `lib/services/places_service.dart`  
**Class:** `PlacesSessionTokenManager`

### What It Does:
- Bundles multiple autocomplete keystrokes into one billable session
- Resets after user selects a place
- Saves ~80% on autocomplete costs

### Usage:
```dart
// Auto-used in getAutocompleteSuggestions()
// Manual reset after selection:
PlacesSessionTokenManager.resetToken();
```

---

## 📁 Files Modified

| File | Change | How to Revert |
|------|--------|---------------|
| `lib/services/places_service.dart` | Removed rating/photos fields | Uncomment fields in `searchDogFriendlyPlaces()` |
| `lib/services/places_service.dart` | Added `PlacesSessionTokenManager` | Keep this - it only saves money |
| `lib/widgets/location_picker_field.dart` | Added session token reset | Keep this |
| `lib/screens/map_location_picker_screen.dart` | Added session token reset | Keep this |
| `pubspec.yaml` | Added `uuid` dependency | Keep this |

---

## 🔄 Quick Re-Enable Guide

### To bring back photos and ratings:

1. Open `lib/services/places_service.dart`
2. Find the `fields` array in `searchDogFriendlyPlaces()` (~line 142)
3. Add back:
   ```dart
   'rating',
   'userRatingCount', 
   'photos',
   ```
4. Update UI components to display these (they may show as null currently)

### UI Files That May Need Updates:
- `lib/screens/map_screen.dart` - Place info cards
- `lib/screens/map_v2/widgets/simple_place_sheet.dart` - Place details sheet
- `lib/features/map/presentation/widgets/map_bottom_sheets.dart` - Place sheets

---

## 💡 Future Optimization Ideas

1. **Lazy load photos:** Only fetch when user expands "View Photos"
2. **Cache ratings:** Store in Supabase, refresh weekly
3. **Tiered approach:** Free tier = no photos, Premium = photos
