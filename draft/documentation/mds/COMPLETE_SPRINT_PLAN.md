# 🎯 BarkDate Complete Sprint Plan & User Journeys

## ✅ **PHASE 1: UNIFIED PROFILE SYSTEM (COMPLETE)**

### **Current Status**: ✅ STANDARDIZED
- ✅ Single `CreateProfileScreen` with multiple `EditMode` options
- ✅ Profile screen redesigned with unified menu system  
- ✅ No duplicate "add dog" flows - everything routes to same screen
- ✅ Supabase-only authentication working cleanly

### **Unified Profile Architecture**:
```dart
enum EditMode { 
  createProfile,  // Full onboarding (dog + owner)
  editDog,       // Dog profile only
  editOwner,     // Owner profile only  
  editBoth       // Both dog and owner
}
```

### **Result**: ✅ Clean, consistent profile management system

---

## 📱 **PHASE 2: TAB IMPLEMENTATIONS**

## **TAB 1: FEED SCREEN** 🐕📱

### **User Journey Map**:
```
📱 LANDING
└── User sees infinite scroll of posts
    ├── Dog photos with cute captions
    ├── Playdate announcements 
    ├── Achievement celebrations
    └── Community highlights

👆 INTERACT  
└── User engages with content
    ├── ❤️ Like posts (with paw animation)
    ├── 💬 Comment on posts
    ├── 📤 Share to other platforms
    └── 🔖 Save favorite posts

📸 CREATE
└── User creates new content
    ├── 📷 Multi-photo posts with captions
    ├── 📍 Location tagging (dog parks, etc.)
    ├── 🏷️ Tag other dogs/owners
    └── 🎉 Achievement sharing

🔍 DISCOVER
└── User finds new connections
    ├── 👀 Browse trending posts
    ├── 🐕 Discover similar breed dogs
    ├── 📍 Find local dog community
    └── 👥 Get friend suggestions
```

### **Sprint Breakdown**:

#### **WEEK 1-2: Core Feed Infrastructure**
```dart
// Required Dependencies (already have most)
dependencies:
  cached_network_image: ^3.3.0  # For optimized image loading
  flutter_staggered_grid_view: ^0.7.0  # For Pinterest-style layout
  pull_to_refresh: ^2.0.0  # For refresh functionality
```

**Day 1-3: Real-time Post System**
- [ ] Create `posts` table in Supabase
- [ ] Implement real-time subscriptions for live updates
- [ ] Build infinite scroll with pagination
- [ ] Add post creation with multiple photos

**Day 4-7: Social Interactions**  
- [ ] Like system with real-time counts
- [ ] Comment system with threaded replies
- [ ] Share functionality
- [ ] Save/bookmark posts

**Day 8-14: UI Polish**
- [ ] Card-based post layout with Material 3 design
- [ ] Smooth animations for interactions
- [ ] Pull-to-refresh functionality
- [ ] Loading states and error handling

#### **WEEK 3: Advanced Features**
- [ ] User tagging system (@username)
- [ ] Location tagging with Google Places
- [ ] Post categories (playdate, photo, achievement)
- [ ] Advanced filtering and search

#### **WEEK 4: Community Features**
- [ ] Trending posts algorithm
- [ ] Local community detection
- [ ] Achievement celebration posts
- [ ] Popular dogs/posts discovery

---

## **TAB 2: MAP SCREEN** 🗺️📍

### **User Journey Map**:
```
🗺️ LANDING
└── User sees interactive map
    ├── 📍 Current location with blue dot
    ├── 🐕 Nearby dogs as custom markers
    ├── 🌳 Dog parks and pet-friendly places
    └── 📅 Active playdates happening now

🔍 EXPLORE
└── User discovers locations
    ├── 🏞️ Browse different neighborhoods  
    ├── 🔍 Search for specific places
    ├── 📊 See dog density heatmaps
    └── 🎯 Filter by dog size/breed

🤝 CONNECT
└── User initiates contact
    ├── 👋 See "dogs nearby right now"
    ├── 💬 Send quick "wanna play?" message
    ├── 📱 View other dog's profile
    └── 📅 Suggest impromptu meetup

🧭 NAVIGATE
└── User gets directions
    ├── 🚗 Route to dog parks
    ├── 🏥 Find nearest vet clinics
    ├── 🛍️ Locate pet stores
    └── ☕ Discover dog-friendly cafes

📍 CREATE EVENTS
└── User hosts location-based activities
    ├── 📅 Create "playdate here" events
    ├── 🎪 Organize group dog walks
    ├── 📢 Announce "we're here now!"
    └── 🔔 Set up location-based notifications
```

### **Sprint Breakdown**:

#### **WEEK 1: Google Maps Setup** (Requires Firebase)
```yaml
# pubspec.yaml additions
dependencies:
  google_maps_flutter: ^2.5.0
  google_maps_flutter_web: ^0.5.4
  google_places_flutter: ^2.0.7
  geolocator: ^10.1.0
  geocoding: ^2.1.1
```

**Required Firebase Setup**:
1. **Google Cloud Console**:
   - Enable Google Maps JavaScript API
   - Enable Google Maps SDK for iOS/Android  
   - Enable Google Places API
   - Generate API keys with proper restrictions

2. **Environment Configuration**:
```dart
// lib/config/google_config.dart
class GoogleConfig {
  static const String _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _placesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  
  static String get mapsApiKey => _mapsApiKey;
  static String get placesApiKey => _placesApiKey;
}
```

**Day 1-7: Basic Map Implementation**
- [ ] Google Maps integration with Flutter
- [ ] User location detection and display
- [ ] Map controls and gestures
- [ ] Custom styling for dog theme

#### **WEEK 2: Dog Markers & Real-time**
**Day 8-14: Live Dog Positions**
- [ ] Display nearby dogs as custom markers
- [ ] Real-time position updates (with privacy controls)
- [ ] Custom dog breed icons for markers
- [ ] Tap-to-view dog profile cards

#### **WEEK 3: Places & Navigation**
**Day 15-21: Location Database**
- [ ] Dog park and pet-friendly location database
- [ ] Google Places integration for search
- [ ] Categories: parks, vets, stores, cafes
- [ ] Navigation integration with platform maps

#### **WEEK 4: Events & Community**
**Day 22-28: Location-based Features**
- [ ] Playdate location markers  
- [ ] "Dogs here now" real-time indicators
- [ ] Geofencing for local notifications
- [ ] Popular walking routes display

---

## **TAB 3: MESSAGES SCREEN** 💬📱

### **User Journey Map**:
```
💬 LANDING
└── User sees conversation list
    ├── 🔴 Unread message indicators
    ├── 📅 Playdate coordination chats
    ├── 👥 Group conversations
    └── 📍 Location-based conversations

💬 CHAT
└── User communicates in real-time
    ├── ⚡ Instant message delivery
    ├── 📷 Photo/video sharing
    ├── 🎙️ Voice messages  
    ├── 📍 Location sharing
    ├── ✅ Read receipts
    └── 🟢 Online status indicators

📅 COORDINATE
└── User organizes playdates
    ├── 📅 "When are you free?" calendar integration
    ├── 📍 "Meet here?" location suggestions
    ├── 👥 Group playdate planning
    ├── ⏰ Automatic reminders
    └── 📋 Playdate confirmation flow

👥 GROUPS  
└── User joins community
    ├── 🏘️ Local neighborhood groups
    ├── 🐕 Breed-specific communities
    ├── 🎾 Activity-based groups (fetch, agility)
    ├── 🏥 Emergency contact groups
    └── 👑 Group admin controls

🚨 EMERGENCY
└── User accesses urgent features
    ├── 🚨 "Lost dog" alert broadcast
    ├── 🏥 Quick vet contact
    ├── 📱 Emergency contact system
    └── 📍 Share real-time location
```

### **Sprint Breakdown**:

#### **WEEK 1: Core Messaging** 
**Day 1-7: Real-time Chat Foundation**
- [ ] Supabase Realtime subscriptions for messages
- [ ] Message threading and conversation management  
- [ ] Typing indicators and online presence
- [ ] Read receipts system

#### **WEEK 2: Rich Media & Voice**
**Day 8-14: Media Sharing**
- [ ] Photo/video sharing via Supabase Storage
- [ ] Voice message recording and playback
- [ ] Image compression and optimization
- [ ] Media gallery within chats

#### **WEEK 3: Group Features**
**Day 15-21: Community Messaging**
- [ ] Group chat creation and management
- [ ] Admin controls and permissions
- [ ] Group member management
- [ ] Local community group discovery

#### **WEEK 4: Push Notifications** (Firebase Required)
**Day 22-28: FCM Integration**
- [ ] Push notifications for new messages
- [ ] Playdate invitation notifications  
- [ ] Group message notifications
- [ ] Custom notification sounds and vibrations

**Required Firebase Setup for Messaging**:
```javascript
// Supabase Edge Function for FCM
// supabase/functions/send-notification/index.ts
serve(async (req) => {
  const { type, recipient_id, title, body, data } = await req.json()
  
  // Get FCM token from Supabase
  const { data: user } = await supabaseAdmin
    .from('user_profiles')
    .select('fcm_token')
    .eq('id', recipient_id)
    .single()

  // Send via FCM
  await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: user.fcm_token,
      notification: { title, body },
      data: data || {},
    }),
  })
})
```

---

## **TAB 4: PROFILE SCREEN** 👤✨ (Enhanced)

### **Current Status**: ✅ UNIFIED SYSTEM COMPLETE

### **Enhancement Sprint**:

#### **WEEK 1: Advanced Profile Features**
**Day 1-7: Profile Enhancement**
- [ ] Dog photo carousel with smooth transitions  
- [ ] Achievement badges and progress tracking
- [ ] Playdate history with statistics
- [ ] Social stats (friends, likes, posts)

#### **WEEK 2: Social Integration**
**Day 8-14: Profile Sharing**
- [ ] QR code generation for profile sharing
- [ ] Public profile URLs
- [ ] Profile visitor tracking
- [ ] Cross-platform sharing options

#### **WEEK 3: Premium Features**
**Day 15-21: Premium Integration**
- [ ] Premium badge and benefits display
- [ ] Advanced privacy controls
- [ ] Custom profile themes
- [ ] Priority support access

---

## 🔥 **FIREBASE SERVICES INTEGRATION MAP**

### **Firebase Project Setup Required**:
```bash
# 1. Firebase Console Setup
- Create new Firebase project
- Enable Authentication (for Google OAuth only)
- Enable Cloud Messaging (FCM)
- Enable Cloud Functions (for FCM edge functions)

# 2. Google Cloud Console Setup  
- Enable Google Maps JavaScript API
- Enable Google Maps SDKs (iOS/Android)
- Enable Google Places API
- Enable Google Calendar API (for playdate integration)

# 3. API Key Configuration
- Web API Key (unrestricted for web app)
- Android API Key (with SHA-1 fingerprint)
- iOS API Key (with bundle ID)
- Server Key (for FCM from Supabase)
```

### **Service Integration Points**:

| Tab | Firebase Service | Purpose | Status |
|-----|-----------------|---------|---------|
| Feed | ❌ None | Uses Supabase only | ✅ Ready |
| Map | 🗺️ Google Maps API | Interactive mapping | 🔄 Phase 2 |
| Messages | 📱 FCM | Push notifications | 🔄 Phase 2 |
| Profile | ❌ None | Uses Supabase only | ✅ Complete |

### **API Key Management**:
```dart
// lib/config/firebase_config.dart
class FirebaseConfig {
  static const String fcmServerKey = String.fromEnvironment('FCM_SERVER_KEY');
  static const String googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String googlePlacesKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  
  // Platform-specific keys
  static String get webApiKey => String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static String get androidApiKey => String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static String get iosApiKey => String.fromEnvironment('FIREBASE_IOS_API_KEY');
}
```

---

## 📋 **IMPLEMENTATION TIMELINE**

### **Current Status** (✅ Complete):
- ✅ Authentication system (Supabase only)
- ✅ Unified profile management
- ✅ Basic app structure and navigation
- ✅ Database schema and real-time setup

### **Next 4 Weeks** (🔄 In Progress):

**Week 1**: Feed Screen Core
- Real-time posts, likes, comments
- Photo upload and display
- Basic social interactions

**Week 2**: Map Screen Foundation  
- Google Maps setup and integration
- Basic location display
- Dog markers implementation

**Week 3**: Messages Real-time
- Supabase Realtime messaging
- Media sharing
- Group conversations

**Week 4**: Firebase Integration
- FCM push notifications
- Google Maps advanced features
- Full cross-service integration

### **Weeks 5-8** (🔮 Future):
- Advanced features and polish
- Performance optimization  
- User testing and feedback
- Premium features implementation

---

## 🎯 **SUCCESS METRICS**

### **Technical Goals**:
- [ ] All tabs functional with core features
- [ ] Real-time updates under 500ms latency
- [ ] Push notifications 95% delivery rate
- [ ] Map performance 60fps on mobile
- [ ] Image upload under 3 seconds

### **User Experience Goals**:
- [ ] Single unified profile editing system
- [ ] Seamless navigation between tabs
- [ ] Consistent Material 3 design language
- [ ] Intuitive social interactions
- [ ] Reliable real-time messaging

### **Business Goals**:
- [ ] User engagement: 5+ minutes per session
- [ ] Social interactions: 3+ per user per day
- [ ] Playdate creation: 1+ per user per week
- [ ] Message activity: 10+ messages per user per day
- [ ] Location usage: Daily check-ins

---

## 🚀 **READY TO BEGIN IMPLEMENTATION**

The foundation is solid with:
✅ Supabase-only authentication working cleanly  
✅ Unified profile system standardized
✅ Firebase services properly scoped
✅ Clear sprint plans for each tab
✅ Realistic timeline with measurable goals

**Next Command**: Start with Feed Screen implementation in lib/screens/social_feed_screen.dart!
