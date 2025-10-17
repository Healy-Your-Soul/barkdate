# BarkDate Complete User Journey Guide

## 🎯 Overview

This document maps every screen, what users should see, and how they navigate through the app.

## 🚀 Authentication Flow

### 1. App Launch
**Screen:** `SupabaseAuthWrapper` (automatic routing)

**What Happens:**
- App checks if user has active Supabase session
- Shows loading spinner while checking

**Routing Logic:**
- **No session** → AuthScreen (Sign In/Sign Up)
- **Has session + complete profile** → MainNavigation (6 tabs)
- **Has session + incomplete profile** → Create Profile or Welcome

### 2. Auth Screen
**File:** `lib/screens/auth_screen.dart`

**What User Sees:**
- BarkDate logo and tagline
- Two buttons: "Sign In" and "Sign Up"

**User Actions:**
- Tap "Sign In" → SignInScreen
- Tap "Sign Up" → SignUpScreen

### 3. Sign In Screen
**File:** `lib/screens/auth/sign_in_screen.dart`

**What User Sees:**
- Email input field
- Password input field (with show/hide toggle)
- "Remember me" checkbox
- "Sign In" button
- "Forgot Password?" link
- "Don't have an account? Sign Up" link

**User Actions:**
- Enter email and password → Tap "Sign In"
- **Success** → MainNavigation (if profile complete) or Create Profile
- **Error** → Red snackbar with error message
- Tap "Forgot Password" → ForgotPasswordScreen
- Tap "Sign Up" → SignUpScreen

### 4. Sign Up Screen
**File:** `lib/screens/auth/sign_up_screen.dart`

**What User Sees:**
- Name input field
- Email input field
- Password input field (with strength indicator)
- Confirm password field
- Terms & Conditions checkbox
- "Sign Up" button
- "Already have an account? Sign In" link

**User Actions:**
- Fill form → Tap "Sign Up"
- **Success** → VerifyEmailScreen
- **Error** → Red snackbar with error message

### 5. Verify Email Screen
**File:** `lib/screens/auth/verify_email_screen.dart`

**What User Sees:**
- Email verification message
- "Check if Verified" button
- "Resend Email" button

**User Actions:**
- Check email → Click verification link
- Return to app → Tap "Check if Verified"
- **Verified** → Create Profile
- **Not verified** → Stay on screen

### 6. Welcome Screen (Onboarding)
**File:** `lib/screens/onboarding/welcome_screen.dart`

**What User Sees:**
- 3 onboarding slides:
  1. "Find Nearby Dog Friends"
  2. "Schedule Playdates"
  3. "Build Your Pack"
- Skip button (top-right)
- "Get Started" button (last slide)

**User Actions:**
- Swipe through slides
- Tap "Get Started" → Location Permission or Create Profile

### 7. Create Profile Screen
**File:** `lib/screens/onboarding/create_profile_screen.dart`

**What User Sees:**
- **Step 1: Human Info**
  - Name, bio, location, avatar upload
  - "Next" button
  
- **Step 2: Dog Profile**
  - Dog name, breed, age, size, gender, bio
  - Photo upload (multiple)
  - "Complete Profile" button

**User Actions:**
- Fill human info → Tap "Next"
- Fill dog info → Tap "Complete Profile"
- **Success** → MainNavigation

---

## 🏠 Main App Navigation (6 Tabs)

### Tab 1: Feed Screen 🏠
**File:** `lib/screens/feed_screen.dart`

**What User Sees:**

**Header:**
- "BarkDate" title
- Filter icon (top-right)
- Settings icon (top-right)

**Dashboard Section (4 Cards in 2x2 Grid):**
1. **My Playdates**
   - Icon: Calendar
   - Shows: "X upcoming" or "Schedule one"
   - Badge: Number of upcoming playdates
   
2. **Notifications**
   - Icon: Bell
   - Shows: "X new" or "All caught up"
   - Badge: Unread count
   
3. **Check In** (NEW!)
   - Icon: Paw (if active) or Location pin (if inactive)
   - Shows: "I'm at the park!" or "Check in at a park"
   - Color: Green (active) or Orange (inactive)
   
4. **Matches**
   - Icon: Heart
   - Shows: "X mutual barks" or "No matches yet"
   - Badge: Mutual bark count

**Nearby Dogs Section:**
- Section header: "Nearby Dogs" with count
- Filter button
- Scrollable list of dog cards

**Dog Card Contents:**
- Large photo (tap to view full profile)
- Dog name, breed
- Age, size, gender icons
- Distance from user
- "Bark" button (green paw icon)
- Quick actions: Message, Invite to playdate

**User Actions:**
- Tap dashboard card → Navigate to that feature
- Tap "My Playdates" → PlaydatesScreen
- Tap "Notifications" → NotificationsScreen
- Tap "Check In" → MapScreen (if inactive) or Check-out dialog (if active)
- Tap "Matches" → CatchScreen
- Tap dog card → Dog profile detail sheet
- Tap "Bark" → Send bark notification
- Tap filter → Filter sheet (breed, size, age, distance, energy)
- Pull down → Refresh nearby dogs

### Tab 2: Map Screen 🗺️
**File:** `lib/screens/map_screen.dart`

**What User Sees:**

**Header:**
- "Map" title
- My location button (top-right)

**Main Content:**
- **Check-in Status Banner** (if active)
  - "Currently at [Park Name]"
  - "Checked in [time] ago"
  - "Check Out" button
  
- **Search Bar**
  - "Search for dog-friendly places..."
  - Search icon
  
- **Google Map**
  - User location (blue dot)
  - Park markers (green pins)
  - Dog count badges on markers
  
- **Featured Parks Section** (below map)
  - Horizontal scrollable list
  - Park cards with photos, names, dog counts
  
- **Nearby Parks List**
  - Scrollable list of parks
  - Distance, address, dog count
  - "View on Map" button

**Floating Action Button:**
- Shows "Check In" (if not checked in)
- Hidden (if already checked in)

**User Actions:**
- Tap "Check In" FAB → Check-in options bottom sheet (list of nearby parks)
- Tap park on map → Park detail bottom sheet
- Tap park in list → Park detail bottom sheet
- In park detail → "Check In" or "Directions" buttons
- Search for place → Results list → Tap result → Place detail
- Tap "Check Out" → Confirm dialog → Check out

### Tab 3: Events Screen 🎉 (NEW!)
**File:** `lib/screens/events_screen.dart`

**What User Sees:**

**Header:**
- "Events" title
- Filter icon (top-right)
- Create event "+" button (top-right)

**3 Sub-Tabs:**

**Browse Tab:**
- Category filter chips (All, Birthday, Training, Social, Professional)
- Scrollable list of event cards

**Event Card Contents:**
- Large image with gradient overlay
- Category icon badge (top-left)
- Price badge (top-right): "FREE" or "$XX.XX"
- Category label (bottom-left)
- Participant count (bottom-right): "8/15 dogs"
- Title
- Organizer avatar + name
- Date & time
- Location
- Description preview
- Target audience chips (Puppy, Adult, Small, Medium, etc.)

**My Events Tab:**
- Events user has joined
- Empty state: "No events yet" with "Browse Events" button

**Hosting Tab:**
- Events user created/hosting
- Empty state: "No hosted events" with "Create Event" button

**User Actions:**
- Tap event card → EventDetailScreen
- Tap "+" → CreateEventScreen
- Tap filter → Filter bottom sheet (category selection)
- Pull down → Refresh events

### Tab 4: Playdates Screen 📅
**File:** `lib/screens/playdates_screen.dart`

**What User Sees:**

**Header:**
- "Playdates" title

**3 Sub-Tabs:**

**Requests Tab:**
- **Incoming Requests** (user is invitee)
  - "Playdate Invitation!"
  - "From: [Dog Name] (human: [Human Name])"
  - Date, time, location
  - "Accept" (green) and "Decline" (red) buttons
  
- **Sent Requests** (user is requester)
  - "Sent to [Dog Name]!"
  - "Human: [Human Name]"
  - Date, time, location
  - "Cancel Request" button

**Upcoming Tab:**
- Confirmed playdates in the future
- Card shows: Title, date, time, location
- "With: [Dog Name] and their human"
- Tap → Action menu (View Details, Cancel, Reschedule)

**Past Tab:**
- Completed playdates
- Card shows: Title, date, participants
- Tap → Playdate recap (photos, memories)

**User Actions:**
- Tap "Accept" → Playdate confirmed, moves to Upcoming
- Tap "Decline" → Request removed
- Tap "Cancel Request" → Sent request cancelled
- Tap upcoming playdate → Action popup
- Tap past playdate → Recap screen
- Pull down → Refresh playdates

### Tab 5: Messages Screen 💬
**File:** `lib/screens/messages_screen.dart`

**What User Sees:**

**Header:**
- "Messages" title
- New message "+" button (top-right)

**Chat Preview List:**
Each preview shows:
- Dog photo (circular avatar)
- Dog name (bold)
- "with [Dog Name] (human: [Human Name])"
- Last message preview
- Timestamp
- Unread badge (if unread messages)

**Empty State:**
- "No messages yet"
- "Start chatting with other dogs!"

**User Actions:**
- Tap chat preview → ChatDetailScreen
- Tap "+" → New message (select dog)
- Pull down → Refresh messages
- Swipe chat → Delete option

### Tab 6: Profile Screen 👤
**File:** `lib/screens/profile_screen.dart`

**What User Sees:**

**Header:**
- "Profile" title
- Edit menu icon (top-right with 3 dots)

**Edit Menu Options:**
- Edit Dog Profile
- Edit My Human
- Add Dog Profile
- Edit Both

**Dog Profile Section (Hero):**
- Large photo carousel (swipeable)
- Dog name (large, bold)
- Breed, age, size, gender
- Bio text
- Stats: Playdates, Friends, Barks

**"My Human" Section:**
- Section title: "My Human"
- Human avatar (circular)
- Human name
- Location
- "Edit" button

**Menu Items:**
- 📅 My Playdates
- 📱 Social Feed
- 🏆 Achievements
- ⭐ Premium
- ❓ Help & Support
- 🔒 Privacy Policy
- ⚙️ Settings

**User Actions:**
- Tap edit menu → Select edit mode
- Tap "Edit Dog Profile" → Create Profile (edit dog mode)
- Tap "Edit My Human" → Create Profile (edit human mode)
- Tap photo → Photo gallery
- Tap menu item → Navigate to that screen
- Tap "Settings" → SettingsScreen

---

## 🔄 Secondary Screen Flows

### Dog Profile Detail
**File:** `lib/screens/dog_profile_detail.dart`

**Accessed From:** Feed (tap dog card)

**What User Sees:**
- Full-screen dog profile
- Photo gallery (swipeable)
- Complete bio
- Owner info
- Action buttons: Bark, Message, Invite

**User Actions:**
- Tap "Bark" → Send bark, close sheet
- Tap "Message" → ChatDetailScreen
- Tap "Invite" → Playdate request modal
- Swipe down → Close

### Event Detail
**File:** `lib/screens/event_detail_screen.dart`

**Accessed From:** Events screen (tap event card)

**What User Sees:**
- Large header image with gradient
- Category icon and price badge
- Event title (large)
- Organizer info (avatar, name, type)
- Date & time
- Location
- Participant count
- Full description
- Target audience (age groups, sizes)
- "Join Event" or "Leave Event" button

**User Actions:**
- Tap "Join Event" → Join, button changes to "Leave Event"
- Tap "Leave Event" → Confirm, leave event
- Tap back → Return to Events screen

### Create Event
**File:** `lib/screens/create_event_screen.dart`

**Accessed From:** Events screen (tap "+" button)

**What User Sees:**
- Form with fields:
  - Event title
  - Category selection (chips)
  - Description
  - Date picker
  - Start time picker
  - End time picker
  - Location
  - Max participants (slider)
  - Price (optional)
  - Target age groups (chips)
  - Target sizes (chips)
  - Registration requirement (checkbox)
- "Create" button (top-right)

**User Actions:**
- Fill form → Tap "Create"
- **Success** → Return to Events screen, event appears in Hosting tab
- **Error** → Red snackbar

### Chat Detail
**File:** `lib/screens/chat_detail_screen.dart`

**Accessed From:** Messages screen (tap chat preview)

**What User Sees:**
- Header: Other dog's name
- Message bubbles (left = received, right = sent)
- Timestamps
- Message input field at bottom
- Send button
- Attachment button

**User Actions:**
- Type message → Tap send
- Tap attachment → Photo picker
- Scroll up → Load older messages
- Tap back → Return to Messages

### Notifications Screen
**File:** `lib/screens/notifications_screen.dart`

**Accessed From:** Feed dashboard (tap Notifications card)

**What User Sees:**
- List of notifications:
  - Bark received: "[Dog] barked at you!"
  - Playdate request: "[Dog] invited you to a playdate"
  - Playdate confirmed: "Playdate with [Dog] confirmed"
  - Message received: "New message from [Dog]"
  - Match: "You and [Dog] are a match!"
- Each notification has icon, message, timestamp
- Tap notification → Navigate to relevant screen

**User Actions:**
- Tap notification → Navigate to context (playdate, message, etc.)
- Pull down → Refresh
- Swipe → Mark as read

### Settings Screen
**File:** `lib/screens/settings_screen.dart`

**Accessed From:** Profile menu

**What User Sees:**
- Account section: Email, password
- Preferences: Notifications, location, theme (light/dark)
- Privacy: Block list, data settings
- About: Version, terms, privacy policy
- "Sign Out" button (red)

**User Actions:**
- Toggle settings
- Tap "Sign Out" → Confirm dialog → Sign out → AuthScreen

---

## 🎨 What Each Screen Should Look Like

### Feed Screen Visual Layout

```
┌─────────────────────────────────────┐
│ BarkDate          [Filter] [Settings]│
├─────────────────────────────────────┤
│                                     │
│  ┌──────────┐  ┌──────────┐       │
│  │ Calendar │  │   Bell   │       │
│  │Playdates │  │  Notifs  │       │
│  │3 upcoming│  │  5 new   │       │
│  └──────────┘  └──────────┘       │
│                                     │
│  ┌──────────┐  ┌──────────┐       │
│  │   Paw    │  │  Heart   │       │
│  │Check In  │  │ Matches  │       │
│  │At park!  │  │ 2 mutual │       │
│  └──────────┘  └──────────┘       │
│                                     │
│  Nearby Dogs (12)          [Filter] │
│  ────────────────────────────────  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ [Dog Photo]                 │  │
│  │ Max, 2y • Golden Retriever  │  │
│  │ 1.2 km away                 │  │
│  │              [Bark Button]  │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ [Dog Photo]                 │  │
│  │ Luna, 3y • Labrador         │  │
│  │ 2.5 km away                 │  │
│  │              [Bark Button]  │  │
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
[Feed] [Map] [Events] [Playdates] [Messages] [Profile]
```

### Map Screen Visual Layout

```
┌─────────────────────────────────────┐
│ Map                  [My Location]  │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐│
│ │ Currently at Central Park       ││
│ │ Checked in 45m ago  [Check Out] ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │ 🔍 Search for dog-friendly...   ││
│ └─────────────────────────────────┘│
│                                     │
│ ┌─────────────────────────────────┐│
│ │                                 ││
│ │      [Google Map View]          ││
│ │      📍 Parks with dog counts   ││
│ │      • You are here             ││
│ │                                 ││
│ └─────────────────────────────────┘│
│                                     │
│  Featured Parks                     │
│  ────────────────────────────────  │
│  [Park 1] [Park 2] [Park 3] →      │
│                                     │
│  Nearby Parks                       │
│  ────────────────────────────────  │
│  Central Park • 0.5km • 🐕 12 dogs │
│  Golden Gate Park • 1.2km • 🐕 8   │
│                                     │
│                    [Check In FAB]   │
└─────────────────────────────────────┘
[Feed] [Map] [Events] [Playdates] [Messages] [Profile]
```

### Events Screen Visual Layout

```
┌─────────────────────────────────────┐
│ Events        [Filter] [+ Create]   │
│ [Browse] [My Events] [Hosting]      │
├─────────────────────────────────────┤
│                                     │
│  [All] [Birthday] [Training]...     │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ [Event Image with gradient] │  │
│  │ 🎂           FREE             │  │
│  │                               │  │
│  │ Birthday Party                │  │
│  ├─────────────────────────────┤  │
│  │ Puppy Playtime at Central Park│ │
│  │ 👤 By Sarah Johnson          │  │
│  │ 🕐 Tomorrow at 10:00 AM      │  │
│  │ 📍 Central Park Dog Run      │  │
│  │ Join us for puppies...       │  │
│  │ [Puppy] [Small] [Medium]     │  │
│  │ 🐕 8/15 dogs                 │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ [Event Image]                │  │
│  │ 🎓           $45.00           │  │
│  │ Training Class                │  │
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
[Feed] [Map] [Events] [Playdates] [Messages] [Profile]
```

### Playdates Screen Visual Layout

```
┌─────────────────────────────────────┐
│ Playdates                           │
│ [Requests] [Upcoming] [Past]        │
├─────────────────────────────────────┤
│                                     │
│  Incoming (1)                       │
│  ────────────────────────────────  │
│  ┌─────────────────────────────┐  │
│  │ 🎉 Playdate Invitation!     │  │
│  │ From: Max (human: Sarah)    │  │
│  │ For: Buddy (Golden Retriever)│  │
│  │ 📅 Tomorrow at 3:00 PM      │  │
│  │ 📍 Central Park             │  │
│  │ [Accept] [Decline]          │  │
│  └─────────────────────────────┘  │
│                                     │
│  Sent (1)                           │
│  ────────────────────────────────  │
│  ┌─────────────────────────────┐  │
│  │ Sent to Luna!               │  │
│  │ Human: Mike Chen            │  │
│  │ ⏳ Pending...               │  │
│  │ [Cancel Request]            │  │
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
[Feed] [Map] [Events] [Playdates] [Messages] [Profile]
```

### Messages Screen Visual Layout

```
┌─────────────────────────────────────┐
│ Messages                      [+]   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐  │
│  │ 🐕 Max                      │  │
│  │ with Max (human: Sarah)     │  │
│  │ Hey! Want to meet at the... │  │
│  │                    2:30 PM  │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ 🐕 Luna                     │  │
│  │ with Luna (human: Mike)     │  │
│  │ That sounds great! See you..│  │
│  │                  Yesterday  │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │ 🐕 Buddy                    │  │
│  │ with Buddy (human: Alex)    │  │
│  │ Thanks for the playdate!    │  │
│  │                    Oct 10   │  │
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
[Feed] [Map] [Events] [Playdates] [Messages] [Profile]
```

### Profile Screen Visual Layout

```
┌─────────────────────────────────────┐
│ Profile                       [⋮]   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐  │
│  │                             │  │
│  │     [Large Dog Photo]       │  │
│  │                             │  │
│  │  Buddy                      │  │
│  │  Golden Retriever • 2y • M  │  │
│  │  Loves playing fetch and... │  │
│  │                             │  │
│  │  12 Playdates • 8 Friends   │  │
│  └─────────────────────────────┘  │
│                                     │
│  My Human                  [Edit]   │
│  ────────────────────────────────  │
│  ┌─────────────────────────────┐  │
│  │ 👤 Sarah Johnson            │  │
│  │ 📍 San Francisco, CA        │  │
│  └─────────────────────────────┘  │
│                                     │
│  📅 My Playdates              →    │
│  📱 Social Feed               →    │
│  🏆 Achievements              →    │
│  ⭐ Premium                   →    │
│  ❓ Help & Support            →    │
│  🔒 Privacy Policy            →    │
│  ⚙️ Settings                  →    │
│                                     │
└─────────────────────────────────────┘
[Feed] [Map] [Events] [Playdates] [Messages] [Profile]
```

---

## 🔗 Navigation Connections

### From Feed:
- Dashboard cards → Playdates, Notifications, Map (check-in), Matches
- Dog card → Dog profile detail → Message/Invite
- Filter → Filter sheet
- Settings → Settings screen

### From Map:
- Check-in FAB → Check-in options → Select park → Checked in
- Park marker → Park detail → Check-in or Directions
- Search → Place results → Place detail

### From Events:
- Event card → Event detail → Join/Leave
- Create button → Create event form → Submit → Back to Events
- Filter → Category filter sheet

### From Playdates:
- Request → Accept/Decline → Moves to Upcoming/Removed
- Upcoming playdate → Action menu → Details/Cancel/Reschedule
- Past playdate → Recap screen

### From Messages:
- Chat preview → Chat detail → Send messages
- New message button → Select dog → New chat

### From Profile:
- Edit menu → Create profile (edit mode)
- Menu items → Various screens
- Settings → Settings screen → Sign out

---

## ✅ Dog-Centric Language Examples

Throughout the app, language is from the dog's perspective:

- ❌ "Your playdates" → ✅ "My Playdates"
- ❌ "You barked at Max" → ✅ "Woof! I barked at Max!"
- ❌ "Owner: Sarah" → ✅ "Human: Sarah" or "My Human"
- ❌ "with Sarah" → ✅ "with Max and their human"
- ❌ "Your profile" → ✅ Dog profile is primary, human is "My Human"

---

## 🎯 Key User Journeys

### Journey 1: Find and Connect with a Dog
1. Open app → Feed screen
2. Scroll through nearby dogs
3. Tap dog card → Profile detail opens
4. Tap "Bark" → Bark sent, notification created
5. If mutual bark → Match notification
6. Tap "Message" → Chat screen opens
7. Send message → Start conversation

### Journey 2: Schedule a Playdate
1. From Feed → Tap dog card
2. Tap "Invite" → Playdate request modal
3. Fill date, time, location
4. Send invitation
5. Other user receives notification
6. They accept → Playdate confirmed
7. Both users see in Playdates → Upcoming tab

### Journey 3: Join an Event
1. Tap Events tab
2. Browse events → Tap event card
3. Event detail opens
4. Tap "Join Event"
5. Event added to "My Events" tab
6. Receive reminder before event

### Journey 4: Check In at Park
1. Go to Map tab
2. Tap floating "Check In" button
3. Select park from list
4. Checked in → Status banner appears
5. Other users see increased dog count at that park
6. When leaving → Tap "Check Out"

---

## 🐕 Design Philosophy

**Dog-First Perspective:**
- Dogs are the primary users
- Humans are support characters ("My Human")
- All actions from dog's point of view
- Playful, friendly language

**Clean, Modern UI:**
- Airbnb-inspired cards and spacing
- Generous whitespace
- Clear visual hierarchy
- Consistent styling

**Simple Navigation:**
- 6 clear tabs
- Intuitive icons
- Minimal taps to reach features
- Clear back navigation

**Real-Time Updates:**
- Live dog counts at parks
- Instant message delivery
- Playdate notifications
- Match notifications
