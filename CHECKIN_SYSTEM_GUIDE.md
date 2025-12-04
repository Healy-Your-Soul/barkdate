# Check-In System Documentation

## 🐕 What Are Check-Ins? (Simple Explanation)

**A check-in is when a user tells the app "I'm at this place with my dog RIGHT NOW."**

Think of it like:
- Facebook check-ins → "I'm at Starbucks"
- BarkDate check-ins → "I'm at Central Dog Park with Buddy"

---

## 🎯 Why Check-Ins Are Vital

1. **Real-Time Social Discovery**
   - See which dog owners are at the park *right now*
   - Helps users find playmates immediately
   - "3 dogs are here now - want to join?" 🐕

2. **Trust & Safety**
   - Confirms a place is actually dog-friendly today
   - Shows real user activity, not just Google data
   - Builds social proof for new users

3. **Matchmaking**
   - App can suggest: "Max (Golden Retriever) is at Riverside Park - he loves to play fetch!"
   - Schedule future playdates with dogs you meet

4. **Gamification**
   - Earn points/badges for check-ins
   - "Park Champion" badge for 50 check-ins at one location
   - Unlock special features

---

## 🔄 Check-In Lifecycle (The Journey)

### Stage 1: USER CHECKS IN
```
User at Central Park
      ↓
Opens Map → Taps marker → "Check In Here"
      ↓
Selects dog(s): [✓ Buddy] [✓ Max]
      ↓
Taps "Check In"
      ↓
✅ CHECK-IN CREATED
```

**What happens in database:**
```sql
INSERT INTO checkins (
  user_id: 'abc123',
  dog_id: 'buddy456',
  park_id: 'central_park',
  park_name: 'Central Park',
  checked_in_at: '2025-10-28 14:30:00',
  status: 'active',
  latitude: -31.9505,
  longitude: 115.8605
)
```

### Stage 2: ACTIVE CHECK-IN (Visible to Everyone)
```
Other users see:
  "3 🐕 here now" on map marker
  
Tap marker → Bottom sheet shows:
  "Who's Here Now"
  - Buddy (Golden Retriever) - checked in 5m ago
  - Max (Labrador) - checked in 12m ago
  - Luna (Beagle) - checked in 1h ago
```

**Auto-refresh:**
- Map refreshes check-in counts every 30 seconds
- Real-time updates without manual reload

### Stage 3: CHECK-OUT (3 ways to end)

**Option A: Manual Check-Out**
```
User taps "Check Out" button
      ↓
✅ CHECKED OUT
```

**Option B: Auto-Expire (4 hours)**
```
Background job runs hourly:
  - Find check-ins older than 4 hours
  - Set status = 'completed'
  - Set checked_out_at = NOW()
```

**Option C: Check In Elsewhere**
```
User checks in at Riverside Park
      ↓
System auto-checks out from Central Park
      ↓
User is now checked in at Riverside Park
```

**Database update:**
```sql
UPDATE checkins
SET status = 'completed',
    checked_out_at = '2025-10-28 16:45:00'
WHERE id = 'checkin_xyz'
```

### Stage 4: HISTORICAL DATA (Analytics)
```
Check-in history used for:
  - User stats: "You've visited 12 parks, spent 45 hours playing"
  - Park stats: "Busiest time: Saturday 2-4pm"
  - Recommendations: "Based on your history, try Riverfront Park"
```

---

## 🛠 How It Works in Map V2

### 1. Map Markers Show Dog Count
```dart
// Marker snippet shows active check-ins
snippet: dogCount > 0
    ? '$dogCount 🐕 here now • ${place.distanceText}'
    : '${place.category.icon} ${place.distanceText}'
```

**Visual:**
```
Map Marker (tap)
   ↓
Info Window:
  "Central Park"
  "3 🐕 here now • 1.2km"
```

### 2. Bottom Sheet Shows Details
```dart
// Green badge if dogs are present
if (dogCount > 0) {
  Container(
    "3 dogs here now! 🐕"
    [Tap to see who's here →]
  )
}

// Check-in button
CheckInButton(
  parkId: place.placeId,
  parkName: place.name,
  onCheckInSuccess: () => refreshCounts(),
)
```

### 3. Auto-Refresh Every 30 Seconds
```dart
Timer.periodic(Duration(seconds: 30), (_) {
  _refreshCheckInCounts(); // Fetch latest counts
  _updateMarkers(); // Rebuild markers with new counts
});
```

### 4. "Who's Here Now" Dialog
```dart
// Tap green badge → shows list
ListView(
  [Buddy - 5m ago]
  [Max - 12m ago]
  [Luna - 1h ago]
)
```

---

## 📊 Database Schema

### Table: `checkins`

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Unique check-in ID |
| user_id | uuid | Who checked in |
| dog_id | uuid | Which dog |
| park_id | text | Where (place ID) |
| park_name | text | Place name (cached) |
| checked_in_at | timestamp | When started |
| checked_out_at | timestamp | When ended (null if active) |
| status | text | 'active', 'completed', 'scheduled', 'cancelled' |
| is_future_checkin | boolean | Scheduled for later? |
| scheduled_for | timestamp | Future check-in time |
| latitude | float | Location coordinates |
| longitude | float | Location coordinates |

### Indexes (for speed)
```sql
CREATE INDEX idx_checkins_active ON checkins(park_id, status) 
  WHERE status = 'active';

CREATE INDEX idx_checkins_user_active ON checkins(user_id, status)
  WHERE status = 'active';

CREATE INDEX idx_checkins_time ON checkins(checked_in_at DESC);
```

---

## 🎮 User Flow (Complete Example)

### Scenario: Sarah wants to find dogs to play with

1. **Opens Map Tab**
   - Sees markers with badges: "2 🐕", "5 🐕", "1 🐕"
   - Thinks: "5 dogs at Riverside Park? Perfect!"

2. **Taps Riverside Park Marker**
   - Info window: "5 🐕 here now • 800m"
   - Bottom sheet opens

3. **Bottom Sheet Shows:**
   ```
   Riverside Park ⭐ 4.8
   [✓ Open Now] • 800m
   
   ┌────────────────────────────────┐
   │ 5 dogs here now! 🐕            │
   │ Tap to see who's here →        │
   └────────────────────────────────┘
   
   [Check In Here] ← Big green button
   ```

4. **Taps "Tap to see who's here"**
   - Modal opens with list:
     ```
     Who's Here Now
     
     🐕 Buddy (Golden Retriever)
        Checked in 5m ago
        @john_smith
     
     🐕 Luna (Beagle)
        Checked in 20m ago
        @dog_mom_sarah
     
     ... (3 more)
     ```

5. **Decides to Go! Taps "Check In Here"**
   - Dialog: "Which dogs are with you?"
     - [✓] Charlie (her dog)
   - Taps "Check In"
   - Success toast: "Woof! I'm checked in at Riverside Park! 🐕"

6. **Now Other Users See:**
   - Marker shows: "6 🐕 here now" (updated from 5)
   - Sarah's dog "Charlie" appears in the list

7. **After 2 Hours, Sarah Leaves**
   - Taps "Check Out" button
   - Toast: "Checked out successfully! See you next time! 🐾"
   - Marker updates: "5 🐕 here now" (back to 5)

---

## ⚙️ Technical Implementation

### Service Layer
```dart
// lib/services/checkin_service.dart

// Get counts for multiple places (efficient for map viewport)
static Future<Map<String, int>> getPlaceDogCounts(List<String> placeIds)

// Get detailed check-ins with user/dog info for a place
static Future<List<Map<String, dynamic>>> getActiveCheckInsAtPlace(String placeId)

// Create check-in
static Future<CheckIn?> checkInAtPark(...)

// End check-in
static Future<bool> checkOut()
```

### UI Layer
```dart
// lib/screens/map_v2/map_tab_screen.dart

// Auto-refresh timer
Timer.periodic(Duration(seconds: 30), (_) => _refreshCheckInCounts());

// Fetch counts
Future<void> _refreshCheckInCounts() {
  final counts = await CheckInService.getPlaceDogCounts(placeIds);
  setState(() => _checkInCounts = counts);
}

// Show on markers
snippet: '$dogCount 🐕 here now'
```

### Widget Layer
```dart
// lib/widgets/checkin_button.dart (reused from old map)

CheckInButton(
  parkId: place.placeId,
  parkName: place.name,
  onCheckInSuccess: () => refreshCounts(),
)
```

---

## 🔒 Is It Hard-Coded or Dynamic?

**100% DYNAMIC** ✅

- ❌ **NOT** hard-coded fake data
- ✅ Real user check-ins stored in Supabase
- ✅ Auto-expires after 4 hours
- ✅ Real-time counts fetched every 30s
- ✅ User can manually check out anytime

---

## 📈 Performance Optimizations

1. **Batch Fetching**
   - Single query for all visible places: `getPlaceDogCounts([id1, id2, ...])`
   - Not N queries per place

2. **Debounced Updates**
   - Camera idle → fetch places → then fetch check-ins
   - Not on every camera move

3. **Auto-Refresh Throttling**
   - Every 30s, not every second
   - Only if map is active

4. **Cached Counts**
   - Store `_checkInCounts` in state
   - Only update when changed

---

## 🎯 Success Metrics

Track these to measure success:

- **Check-In Rate**: % of users who check in after visiting a place
- **Social Discovery**: Playdates started from check-ins
- **Engagement**: Users who check "Who's Here Now"
- **Retention**: Users who return to the same park
- **Peak Times**: When parks are busiest (analytics)

---

## 🚀 Future Enhancements

- [ ] **Push Notifications**: "3 dogs just checked in at your favorite park!"
- [ ] **Friends-Only Mode**: Only see check-ins from friends
- [ ] **Scheduled Check-Ins**: "I'll be at Central Park tomorrow at 3pm"
- [ ] **Check-In Rewards**: Points, badges, leaderboards
- [ ] **Privacy Controls**: Anonymous check-ins, hide location
- [ ] **Photo Check-Ins**: Attach photos when checking in
- [ ] **Weather Alerts**: "It's raining at Central Park, 2 dogs left"

---

## 🐛 Common Issues & Solutions

### Issue: Counts Not Updating
**Solution:** Check Timer is active
```dart
_checkInRefreshTimer = Timer.periodic(...);
// Don't forget: dispose() -> _checkInRefreshTimer?.cancel();
```

### Issue: Check-In Button Not Showing
**Solution:** User needs a dog profile first
```dart
final dogs = await getUserDogs();
if (dogs.isEmpty) {
  showError('Create a dog profile first');
}
```

### Issue: Stale Check-Ins (>4 hours)
**Solution:** Run background job or add client-side filter
```dart
.gte('checked_in_at', DateTime.now().subtract(Duration(hours: 4)))
```

---

## 📝 Summary

**Check-ins are the heart of BarkDate's social features!**

- ✅ Real-time visibility: See who's at the park NOW
- ✅ Auto-refresh: Counts update every 30s
- ✅ Auto-expire: No stale data after 4 hours
- ✅ User-friendly: One-tap check-in/out
- ✅ Privacy-aware: Users control their visibility
- ✅ Performance-optimized: Batch queries, caching

**TL;DR:** Check-ins turn static map pins into living, social experiences. 🐕❤️
