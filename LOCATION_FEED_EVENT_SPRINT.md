# 🚀 LOCATION, FEED & EVENT CREATION SPRINT PLAN
**Priority: CRITICAL** | **Status: READY TO IMPLEMENT** | **Date: Oct 19, 2025**

---

## 📋 EXECUTIVE SUMMARY

### What's Broken (Layman's Terms)
1. **Location Data is Inconsistent**: Some dogs/events have old location data (or no location), so they don't show up in feeds
2. **Feed is Showing Wrong Data**: Dogs appear in feed even if they have both events AND playdate needs (should filter better)
3. **Location Permission Unclear**: Users can't easily update location permissions after initial setup
4. **Event Creation is Incomplete**: Can't add images, invite dog friends, or select locations on a map
5. **Feed is Slow**: Not as fast as Instagram - needs better caching and optimization

### Core Problems Identified
- **Location Source of Truth**: Users and Dogs tables have separate lat/long - which one do we use?
- **Old Data Without Location**: Events/playdates created before location feature have NULL lat/long
- **Feed Logic Confusion**: Mixing location-based (Catch/Events) with non-location (Friends/Playdates)
- **No Map Integration in Event Creation**: Can't pick a park on map for events
- **Missing Social Features**: Can't share events, can't add friends to events, no image uploads

---

## 🎯 SPRINT GOALS

### 1. FIX LOCATION ARCHITECTURE ⚡ CRITICAL
**Goal**: Establish clear location data flow and ensure all entities have valid locations

### 2. OPTIMIZE FEED PERFORMANCE 🚀 CRITICAL  
**Goal**: Make feed load as fast as Instagram (< 1 second with cache)

### 3. COMPLETE EVENT CREATION FEATURE 🎉 HIGH
**Goal**: Full-featured event creation with images, map, and friend invites

### 4. CLARIFY LOCATION-BASED vs NON-LOCATION FEATURES 📍 HIGH
**Goal**: Make it clear which features use location and which don't

### 5. IMPROVE LOCATION PERMISSIONS UX 🔐 MEDIUM
**Goal**: Users can easily enable/disable/update location from settings

---

## 🏗️ ARCHITECTURE OVERVIEW

### Current State Problems

```
┌─────────────────────────────────────────────────────────────┐
│                    CURRENT ISSUES                            │
├─────────────────────────────────────────────────────────────┤
│ 1. Users table has lat/long                                  │
│ 2. Dogs table has lat/long (inherits from users)           │
│ 3. Events table has lat/long                                │
│ 4. Playdates table has lat/long                             │
│ 5. Posts table has lat/long                                 │
│                                                              │
│ ❌ Problem: Old records have NULL location                   │
│ ❌ Problem: Location not updating when user moves            │
│ ❌ Problem: No clear "location update" flow in UI           │
└─────────────────────────────────────────────────────────────┘
```

### Proposed Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                  LOCATION HIERARCHY                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  USER LOCATION (Source of Truth)                            │
│  ├── Updated: On login, manual refresh, background updates  │
│  ├── Stored: users.latitude, users.longitude                │
│  └── Cached: In LocationService memory cache                │
│                                                              │
│  DOG LOCATION (Inherits from User)                          │
│  ├── Updated: Whenever user location updates                │
│  ├── Used for: "Nearby Dogs" (Catch feature)               │
│  └── Logic: Always use OWNER's location                     │
│                                                              │
│  EVENT LOCATION (Specific to Event)                         │
│  ├── Set during: Event creation (map picker)                │
│  ├── Used for: "Events Near Me" (location-based)            │
│  └── Logic: Events are PLACE-BASED (park, venue)           │
│                                                              │
│  PLAYDATE LOCATION (Meetup Location)                        │
│  ├── Set during: Playdate creation (map picker)             │
│  ├── Used for: Where to meet (NOT for filtering)           │
│  └── Logic: Friend-based, NOT location-based discovery      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Location-Based vs Friend-Based Features

```
┌───────────────────────────────────────────────────────────────┐
│          LOCATION-BASED FEATURES (Use Lat/Long)               │
├───────────────────────────────────────────────────────────────┤
│ ✅ Catch (Tinder-style) - "Find dogs near me"                │
│ ✅ Events (if public/open) - "Events happening near me"       │
│ ✅ Parks on Map - "Dog parks within X km"                     │
│ ✅ Check-ins - "Who's at the park right now"                  │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────┐
│        FRIEND-BASED FEATURES (NOT Location-Based)             │
├───────────────────────────────────────────────────────────────┤
│ ✅ Friends List - "Your dog's friends"                        │
│ ✅ Playdates - "Schedule with specific friends"               │
│ ✅ Private Events - "Invite specific friends"                 │
│ ✅ Messages - "Chat with matched users"                       │
│                                                                │
│ Note: These DO have location (where to meet) but don't use    │
│ location for DISCOVERY/FILTERING                             │
└───────────────────────────────────────────────────────────────┘
```

---

## 🔍 DETAILED ISSUES & SOLUTIONS

### Issue #1: Location Data Inconsistency

#### Current Problem
```dart
// In feed_screen.dart
final dogData = await BarkDateMatchService.getNearbyDogs(userId);
// This uses dogs.latitude/longitude but some dogs have NULL

// In barkdate_services.dart (getNearbyDogs)
// Queries: WHERE dogs.latitude IS NOT NULL AND dogs.longitude IS NOT NULL
// Problem: Old dogs or dogs whose owners never enabled location = EXCLUDED
```

#### Why This Happens
1. User signs up → location permission not requested immediately
2. User creates dog profile → dog.latitude/longitude = NULL
3. User browses app → no location set
4. Feed tries to show nearby dogs → **EMPTY** because no location

#### Solution
```sql
-- MIGRATION: Backfill missing dog locations from users table
UPDATE dogs 
SET 
  latitude = users.latitude,
  longitude = users.longitude,
  updated_at = NOW()
FROM users
WHERE dogs.user_id = users.id
  AND dogs.latitude IS NULL 
  AND users.latitude IS NOT NULL;
```

```dart
// UPDATE: LocationService to sync user → dogs
static Future<void> updateUserLocation(
  String userId,
  double latitude,
  double longitude,
) async {
  final timestamp = DateTime.now().toIso8601String();
  
  // 1. Update user location
  await SupabaseConfig.client.from('users').update({
    'latitude': latitude,
    'longitude': longitude,
    'location_updated_at': timestamp,
  }).eq('id', userId);
  
  // 2. Update ALL owned dogs to inherit location
  await SupabaseConfig.client.from('dogs').update({
    'latitude': latitude,
    'longitude': longitude,
  }).eq('user_id', userId);
  
  // 3. Clear cache to force refresh
  CacheService().clearNearbyDogs(userId);
}
```

---

### Issue #2: Feed Showing Duplicate/Wrong Data

#### Current Problem
```dart
// A dog could be:
// 1. In "Nearby Dogs" section (wants playdates)
// 2. In "My Events" section (hosting event)
// 3. In "Suggested Events" (invited to event)
// 
// Same dog shows up 3 times!
```

#### Solution: Smart Feed Filtering
```dart
// NEW: Feed filtering service
class FeedFilterService {
  /// Filter out dogs that are already in events
  static List<Dog> filterDogsInEvents(
    List<Dog> nearbyDogs,
    List<Event> events,
  ) {
    final dogsInEvents = events
        .expand((e) => e.participantDogIds ?? [])
        .toSet();
    
    return nearbyDogs
        .where((dog) => !dogsInEvents.contains(dog.id))
        .toList();
  }
  
  /// Filter out dogs with active playdates
  static Future<List<Dog>> filterDogsWithActivePlaydates(
    List<Dog> dogs,
  ) async {
    final dogsWithPlaydates = await PlaydateQueryService
        .getDogsWithActivePlaydates();
    
    return dogs
        .where((dog) => !dogsWithPlaydates.contains(dog.id))
        .toList();
  }
  
  /// Get feed priority
  /// Returns: 0 = hide, 1 = low, 2 = medium, 3 = high
  static int getFeedPriority(Dog dog) {
    if (dog.hasActiveEvent) return 0; // Hide from feed
    if (dog.hasActivePlaydate) return 0; // Hide from feed
    if (dog.lastActiveToday) return 3; // Show first
    if (dog.lastActiveThisWeek) return 2; // Show second
    return 1; // Show last
  }
}
```

---

### Issue #3: Feed Performance (Too Slow)

#### Current Problem
```dart
// In feed_screen.dart _loadAllFeedData()
// Makes 9 separate API calls:
await Future.wait([
  BarkDateMatchService.getNearbyDogs(...),        // 1
  PlaydateQueryService.getUserPlaydates(...),     // 2
  EventService.getUserParticipatingEvents(...),   // 3
  EventService.getRecommendedEvents(...),         // 4
  DogFriendshipService.getDogFriends(...),        // 5
  _getUpcomingPlaydatesCount(...),                // 6
  NotificationService.getUnreadCount(...),        // 7
  _getMutualBarksCount(...),                      // 8
  CheckInService.getActiveCheckIn(...),           // 9
]);

// Each call takes ~200-500ms = 2-4 seconds total!
```

#### Instagram/Facebook Solution: Aggregated Queries
```sql
-- NEW: Create RPC function for feed data
CREATE OR REPLACE FUNCTION get_user_feed_data(
  p_user_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_radius_km INT DEFAULT 25
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'nearby_dogs', (
      SELECT json_agg(row_to_json(t))
      FROM (
        SELECT d.*, 
          calculate_distance(p_latitude, p_longitude, d.latitude, d.longitude) as distance_km
        FROM dogs d
        WHERE d.user_id != p_user_id
          AND d.is_active = true
          AND d.latitude IS NOT NULL
          AND calculate_distance(p_latitude, p_longitude, d.latitude, d.longitude) <= p_radius_km
        ORDER BY distance_km ASC
        LIMIT 20
      ) t
    ),
    'upcoming_playdates', (
      SELECT json_agg(row_to_json(p))
      FROM playdates p
      WHERE (p.organizer_id = p_user_id OR p.participant_id = p_user_id)
        AND p.status = 'confirmed'
        AND p.scheduled_at >= NOW()
      ORDER BY p.scheduled_at ASC
      LIMIT 10
    ),
    'suggested_events', (
      SELECT json_agg(row_to_json(e))
      FROM events e
      WHERE e.status = 'upcoming'
        AND e.start_time >= NOW()
        AND calculate_distance(p_latitude, p_longitude, e.latitude, e.longitude) <= 50
      ORDER BY e.start_time ASC
      LIMIT 10
    ),
    'unread_notifications', (
      SELECT COUNT(*) FROM notifications WHERE user_id = p_user_id AND is_read = false
    ),
    'upcoming_playdates_count', (
      SELECT COUNT(*) FROM playdates 
      WHERE (organizer_id = p_user_id OR participant_id = p_user_id)
        AND status = 'confirmed'
        AND scheduled_at >= NOW()
    )
  ) INTO result;
  
  RETURN result;
END;
$$;
```

```dart
// UPDATE: FeedScreen to use single RPC call
Future<void> _loadAllFeedData() async {
  final user = SupabaseAuth.currentUser;
  if (user == null) return;
  
  // 1. Check cache first (instant render)
  _hydrateFromCache();
  
  // 2. Single RPC call for everything
  final result = await SupabaseConfig.client.rpc(
    'get_user_feed_data',
    params: {
      'p_user_id': user.id,
      'p_latitude': userLocation.latitude,
      'p_longitude': userLocation.longitude,
      'p_radius_km': 25,
    },
  );
  
  // 3. Update UI (seamless)
  setState(() {
    _nearbyDogs = parseDogs(result['nearby_dogs']);
    _upcomingFeedPlaydates = result['upcoming_playdates'];
    _suggestedEvents = parseEvents(result['suggested_events']);
    _unreadNotifications = result['unread_notifications'];
    // etc...
  });
  
  // 4. Update cache
  CacheService().cacheFeedData(user.id, result);
}
```

**Performance Improvement**: 2-4 seconds → **< 500ms** (4-8x faster!)

---

### Issue #4: Event Creation Missing Features

#### Current State (create_event_screen.dart)
```dart
// ✅ Has: Title, description, location (text), date/time, category
// ❌ Missing: 
//   - Map picker for location
//   - Image upload (event photos)
//   - Invite dog friends
//   - Share event
//   - Set lat/long coordinates
```

#### Solution: Enhanced Event Creation

```dart
// NEW: Enhanced CreateEventScreen
class _CreateEventScreenState extends State<CreateEventScreen> {
  // ... existing fields ...
  
  // NEW FIELDS
  double? _selectedLatitude;
  double? _selectedLongitude;
  List<String> _uploadedPhotoUrls = [];
  List<String> _invitedDogIds = [];
  bool _isPublicEvent = true;
  
  // NEW: Map location picker
  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
        ),
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _locationController.text = result['address'];
      });
    }
  }
  
  // NEW: Image upload
  Future<void> _uploadEventImages() async {
    final images = await ImagePickerService.pickMultipleImages(maxImages: 5);
    
    for (final image in images) {
      final url = await PhotoUploadService.uploadEventPhoto(
        userId: currentUser.id,
        imagePath: image.path,
      );
      setState(() {
        _uploadedPhotoUrls.add(url);
      });
    }
  }
  
  // NEW: Invite dog friends
  Future<void> _inviteDogFriends() async {
    final friends = await DogFriendshipService.getDogFriends(myDogId);
    
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => DogFriendSelectorDialog(
        friends: friends,
        alreadyInvited: _invitedDogIds,
      ),
    );
    
    if (selected != null) {
      setState(() {
        _invitedDogIds = selected;
      });
    }
  }
  
  // UPDATED: Create event with new fields
  Future<void> _createEvent() async {
    // ... validation ...
    
    final event = await EventService.createEvent(
      title: _titleController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      latitude: _selectedLatitude,  // NEW
      longitude: _selectedLongitude, // NEW
      startTime: startDateTime,
      endTime: endDateTime,
      category: _selectedCategory,
      maxParticipants: _maxParticipants,
      photoUrls: _uploadedPhotoUrls, // NEW
      isPublic: _isPublicEvent, // NEW
    );
    
    // NEW: Send invitations
    if (_invitedDogIds.isNotEmpty) {
      await EventService.inviteDogs(
        eventId: event.id,
        dogIds: _invitedDogIds,
      );
    }
  }
}
```

---

### Issue #5: Location Permissions UX

#### Current Problem
```
User Journey:
1. Sign up → location permission screen → user clicks "Allow"
2. Week later, user wants to disable location
3. ❌ No option in settings!
4. User goes to phone Settings → Location → BarkDate → "Never"
5. App breaks - can't find nearby dogs anymore
6. User confused why feed is empty
```

#### Solution: Location Settings Management

```dart
// NEW: Location permission widget in settings_screen.dart
class LocationSettingsSection extends StatefulWidget {
  @override
  State<LocationSettingsSection> createState() => _LocationSettingsSectionState();
}

class _LocationSettingsSectionState extends State<LocationSettingsSection> {
  bool _locationEnabled = false;
  String _currentLocation = 'Not set';
  
  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }
  
  Future<void> _checkLocationStatus() async {
    final permission = await Geolocator.checkPermission();
    final position = await LocationService.getCurrentLocation();
    
    setState(() {
      _locationEnabled = permission == LocationPermission.always || 
                        permission == LocationPermission.whileInUse;
      
      if (position != null) {
        _currentLocation = '${position.latitude.toStringAsFixed(4)}, '
                          '${position.longitude.toStringAsFixed(4)}';
      }
    });
  }
  
  Future<void> _toggleLocation(bool value) async {
    if (value) {
      // Enable location
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        await LocationService.updateUserLocation(
          currentUserId,
          position.latitude,
          position.longitude,
        );
        _checkLocationStatus();
      } else {
        // Permission denied - show instructions
        _showLocationPermissionDialog();
      }
    } else {
      // Disable location - show warning
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Disable Location?'),
          content: Text(
            'Disabling location will hide your profile from nearby dogs '
            'and you won\'t see dogs near you. Continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Disable'),
            ),
          ],
        ),
      );
      
      if (confirm == true) {
        await LocationService.disableLocation(currentUserId);
        _checkLocationStatus();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.location_on),
      title: Text('Location Services'),
      subtitle: Text(_locationEnabled ? _currentLocation : 'Disabled'),
      trailing: Switch(
        value: _locationEnabled,
        onChanged: _toggleLocation,
      ),
    );
  }
}
```

---

## 📁 FILES TO CREATE/MODIFY

### New Files to Create

```
lib/services/
  ├── feed_filter_service.dart           (NEW) - Smart feed filtering
  └── map_location_picker_service.dart   (NEW) - Map picker for events

lib/screens/
  ├── map_location_picker_screen.dart    (NEW) - Map UI for location picking
  └── dog_friend_selector_dialog.dart    (NEW) - Friend invitation UI

lib/widgets/
  ├── location_settings_widget.dart      (NEW) - Location toggle in settings
  └── event_image_uploader.dart          (NEW) - Multi-image upload for events

supabase/migrations/
  ├── 20251019_backfill_dog_locations.sql         (NEW) - Fix NULL locations
  ├── 20251019_create_feed_data_function.sql      (NEW) - Aggregated feed query
  └── 20251019_add_event_invitations_table.sql    (NEW) - Event invitations
```

### Files to Modify

```
lib/services/
  ├── location_service.dart              (MODIFY) - Add disable, sync logic
  └── event_service.dart                 (MODIFY) - Add image, invite support

lib/screens/
  ├── feed_screen.dart                   (MODIFY) - Use new feed RPC
  ├── create_event_screen.dart           (MODIFY) - Add map, images, invites
  └── settings_screen.dart               (MODIFY) - Add location settings

lib/models/
  └── event.dart                         (MODIFY) - Add invitedDogIds field

supabase/migrations/
  └── 20250910161044_create_initial_schema.sql (REFERENCE) - Base schema
```

---

## 🛠️ IMPLEMENTATION CHECKLIST

### Phase 1: Fix Location Data (Day 1-2) ⚡ CRITICAL

- [ ] **Task 1.1**: Create migration to backfill NULL dog locations
  - File: `supabase/migrations/20251019_backfill_dog_locations.sql`
  - Logic: Copy users.latitude/longitude to dogs where NULL
  
- [ ] **Task 1.2**: Update `LocationService.updateUserLocation()` 
  - File: `lib/services/location_service.dart`
  - Add: Sync user location to all owned dogs
  - Add: Clear nearby dogs cache
  
- [ ] **Task 1.3**: Add location disable functionality
  - File: `lib/services/location_service.dart`
  - Method: `disableLocation(userId)` - set lat/long to NULL
  
- [ ] **Task 1.4**: Test location sync
  - Test: User updates location → all dogs updated
  - Test: User disables location → dogs hidden from feed

### Phase 2: Optimize Feed Performance (Day 2-3) 🚀 CRITICAL

- [ ] **Task 2.1**: Create aggregated feed RPC function
  - File: `supabase/migrations/20251019_create_feed_data_function.sql`
  - Function: `get_user_feed_data()` - returns all feed data as JSON
  
- [ ] **Task 2.2**: Update FeedScreen to use single RPC call
  - File: `lib/screens/feed_screen.dart`
  - Replace: `Future.wait([...])` with single `rpc('get_user_feed_data')`
  - Add: Better error handling
  
- [ ] **Task 2.3**: Create FeedFilterService
  - File: `lib/services/feed_filter_service.dart`
  - Methods: `filterDogsInEvents()`, `filterDogsWithActivePlaydates()`
  
- [ ] **Task 2.4**: Add feed caching improvements
  - File: `lib/services/cache_service.dart`
  - Add: `cacheFeedData()`, `getCachedFeedData()`
  
- [ ] **Task 2.5**: Test feed performance
  - Test: Cold start < 2 seconds
  - Test: Cached start < 500ms
  - Test: Pull-to-refresh < 1 second

### Phase 3: Enhanced Event Creation (Day 4-5) 🎉 HIGH

- [ ] **Task 3.1**: Create map location picker screen
  - File: `lib/screens/map_location_picker_screen.dart`
  - UI: Google Maps with location pin, search, confirm button
  
- [ ] **Task 3.2**: Add event image upload
  - File: `lib/widgets/event_image_uploader.dart`
  - Feature: Multi-image picker (up to 5 images)
  - Integration: PhotoUploadService
  
- [ ] **Task 3.3**: Create dog friend selector
  - File: `lib/screens/dog_friend_selector_dialog.dart`
  - UI: Checkbox list of dog friends
  - Feature: Select multiple dogs to invite
  
- [ ] **Task 3.4**: Create event_invitations table
  - File: `supabase/migrations/20251019_add_event_invitations_table.sql`
  - Schema: event_id, dog_id, invited_by, status
  
- [ ] **Task 3.5**: Update EventService with new features
  - File: `lib/services/event_service.dart`
  - Add: `inviteDogs(eventId, dogIds)`
  - Add: `uploadEventImages(eventId, images)`
  
- [ ] **Task 3.6**: Update CreateEventScreen UI
  - File: `lib/screens/create_event_screen.dart`
  - Add: Map location picker button
  - Add: Image upload section
  - Add: Invite friends button
  - Add: Public/Private toggle

### Phase 4: Location Settings UX (Day 5-6) 🔐 MEDIUM

- [ ] **Task 4.1**: Create location settings widget
  - File: `lib/widgets/location_settings_widget.dart`
  - UI: Toggle switch, current location display
  
- [ ] **Task 4.2**: Add location section to settings screen
  - File: `lib/screens/settings_screen.dart`
  - Add: Location toggle
  - Add: Manual location refresh button
  - Add: Location permissions status
  
- [ ] **Task 4.3**: Add location permission helper
  - File: `lib/services/location_service.dart`
  - Add: `checkPermissionStatus()` - returns detailed status
  - Add: `openAppSettings()` - deep link to phone settings
  
- [ ] **Task 4.4**: Add location warnings
  - Show warning when location disabled
  - Explain impact on feed, matches, events

### Phase 5: Testing & Documentation (Day 6-7) ✅

- [ ] **Task 5.1**: Write integration tests
  - Test: Location sync (user → dogs)
  - Test: Feed filtering (no duplicates)
  - Test: Event creation with all features
  
- [ ] **Task 5.2**: Update user documentation
  - Guide: How location works
  - Guide: How to enable/disable location
  - Guide: What features require location
  
- [ ] **Task 5.3**: Performance testing
  - Test: Feed load times (< 1 second)
  - Test: Event creation flow (< 3 seconds)
  - Test: Image uploads (< 5 seconds)

---

## 🧪 TESTING SCENARIOS

### Scenario 1: New User with Location
```
1. User signs up
2. Location permission requested → Allow
3. User location saved to DB
4. Create dog profile → dog inherits location
5. Open feed → see nearby dogs immediately
✅ PASS: Feed loads with nearby dogs
```

### Scenario 2: Existing User without Location
```
1. User signed up before location feature
2. User.latitude = NULL, Dog.latitude = NULL
3. Run migration → Dog inherits NULL (no user location)
4. User opens app → location permission requested
5. User allows → location saved
6. Run sync → Dog inherits user location
7. Open feed → see nearby dogs
✅ PASS: Old users get location backfilled
```

### Scenario 3: User Disables Location
```
1. User opens Settings
2. Toggle "Location Services" OFF
3. Confirm warning dialog
4. User.latitude = NULL, Dog.latitude = NULL
5. Open feed → see friends/playdates but NO nearby dogs
6. Open Catch → show message "Enable location to find dogs"
✅ PASS: App works without location (limited features)
```

### Scenario 4: Event Creation with Map
```
1. User taps "Create Event"
2. Fill title, description, date/time
3. Tap "Select Location on Map"
4. Map opens → user pans to park
5. User taps "Confirm"
6. Location address fills in, lat/long saved
7. Upload 3 event images
8. Invite 2 dog friends
9. Tap "Create Event"
10. Event created with all data
✅ PASS: Full event creation works
```

### Scenario 5: Feed Performance
```
1. User opens app (cold start)
2. Cache empty → fetch from DB
3. Time: < 2 seconds
4. User pulls to refresh
5. Fetch from DB again
6. Time: < 1 second
7. User closes app, reopens
8. Cache hit → instant render
9. Time: < 500ms
✅ PASS: Feed is Instagram-fast
```

---

## 📊 SUCCESS METRICS

### Performance KPIs
- **Feed Load Time (Cold)**: < 2 seconds
- **Feed Load Time (Cached)**: < 500ms
- **Event Creation Time**: < 5 seconds (including images)
- **Location Update Time**: < 1 second
- **Cache Hit Rate**: > 80%

### Data Quality KPIs
- **Dogs with Location**: > 95% of active dogs
- **Events with Location**: 100% (required field)
- **Feed Accuracy**: 0 duplicates, 0 irrelevant entries
- **Location Accuracy**: ± 100 meters

### User Experience KPIs
- **Location Permission Acceptance**: > 70%
- **Event Creation Completion**: > 60%
- **Feed Refresh Rate**: > 3x per session
- **User Reports of "Empty Feed"**: < 5%

---

## 🚨 RISKS & MITIGATION

### Risk 1: Migration Breaks Existing Data
**Mitigation**: 
- Test migration on staging DB first
- Create backup before running
- Add rollback script

### Risk 2: Performance RPC is Slow
**Mitigation**:
- Add database indexes on lat/long columns
- Limit result sets (20 items per section)
- Use connection pooling

### Risk 3: Image Uploads Timeout
**Mitigation**:
- Compress images before upload (max 2MB)
- Show progress indicator
- Allow background upload

### Risk 4: Location Permission Rejection
**Mitigation**:
- Explain benefits clearly in UI
- Allow app usage without location (limited)
- Add "Enable Later" option

---

## 🎨 UI/UX MOCKUPS (Text Descriptions)

### Event Creation Screen (Enhanced)
```
┌─────────────────────────────────────┐
│ Create Event                    [X] │
├─────────────────────────────────────┤
│                                     │
│ [Event Images Grid]                 │
│ ┌───┬───┬───┐                       │
│ │ + │   │   │  Tap to add (0/5)    │
│ └───┴───┴───┘                       │
│                                     │
│ Title: [Birthday Party________]     │
│                                     │
│ Category: [🎂 Birthday ▼]           │
│                                     │
│ Location: [Central Park_______]    │
│           [📍 Pick on Map]          │
│                                     │
│ Date: [Oct 25, 2025 ▼]             │
│ Time: [3:00 PM - 5:00 PM ▼]        │
│                                     │
│ Visibility:                         │
│ ● Public Event                      │
│ ○ Private (Invite Only)             │
│                                     │
│ [👫 Invite Dog Friends (2)]         │
│                                     │
│ Description:                        │
│ [________________________]          │
│ [________________________]          │
│                                     │
│ [     Create Event     ]            │
│                                     │
└─────────────────────────────────────┘
```

### Settings → Location Section
```
┌─────────────────────────────────────┐
│ Settings                            │
├─────────────────────────────────────┤
│                                     │
│ Location Services                   │
│ ┌─────────────────────────────────┐ │
│ │ 📍 Location: Enabled      [ON] │ │
│ │                                 │ │
│ │ Current Location:               │ │
│ │ 37.7749, -122.4194             │ │
│ │ San Francisco, CA              │ │
│ │                                 │ │
│ │ Last Updated: 2 hours ago      │ │
│ │ [Refresh Now]                   │ │
│ │                                 │ │
│ │ ℹ️ Location is used for:        │ │
│ │ • Finding dogs nearby (Catch)  │ │
│ │ • Events near you              │ │
│ │ • Park check-ins               │ │
│ │                                 │ │
│ │ Your location is NEVER shared  │ │
│ │ publicly. Only used for        │ │
│ │ matching within your radius.   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Search Radius                       │
│ [====●==================] 25 km     │
│                                     │
└─────────────────────────────────────┘
```

---

## 📚 RELATED DOCUMENTATION

- `ARCHITECTURE_MAP.md` - Current system architecture
- `USER_JOURNEY_GUIDE.md` - User flows and navigation
- `DESIGN_SYSTEM_GUIDE.md` - UI components and styling
- `PERFORMANCE_IMPLEMENTATION_SUMMARY.md` - Current performance state

---

## ✅ DEFINITION OF DONE

### Feature Complete When:
- [ ] All tasks in checklist completed
- [ ] All tests pass (unit + integration)
- [ ] Performance metrics met
- [ ] Code reviewed and approved
- [ ] Documentation updated
- [ ] Migration scripts tested on staging
- [ ] User testing completed (5+ users)
- [ ] No critical bugs in QA

### Deployment Checklist:
- [ ] Run database migrations
- [ ] Deploy backend changes
- [ ] Deploy app updates
- [ ] Monitor error rates (< 1%)
- [ ] Monitor performance metrics
- [ ] User feedback collection

---

## 📞 QUESTIONS TO ANSWER BEFORE STARTING

1. **Location Privacy**: Do we show exact location or just distance? 
   - **Recommendation**: Show distance only ("2.3 km away"), never exact coordinates

2. **Event Images**: Max size? Compression?
   - **Recommendation**: Max 2MB per image, auto-compress to 1920px width

3. **Friend Invitations**: Can invite non-friends?
   - **Recommendation**: Yes, but only for public events

4. **Location Update Frequency**: How often to refresh?
   - **Recommendation**: On app open, manual refresh, and every 30 minutes in background

5. **Feed Pagination**: Infinite scroll or "Load More"?
   - **Recommendation**: Infinite scroll for dogs, "Load More" for events/playdates

---

**READY TO START? Let's go! 🚀**

Which phase should we tackle first?
