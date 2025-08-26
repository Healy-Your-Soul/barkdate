# BarkDate App Architecture & Sprint Plan 🐕

## 📱 App Overview
BarkDate is a social platform connecting dog owners for playdates and community building. Think of it as a neighborhood where every dog has their own social network - like a dog park that exists in your pocket!

## 🏗️ Architecture Overview

### Core Navigation Structure
```
App Entry
    ├── Onboarding Flow (First-time users)
    │   ├── Welcome Screen
    │   ├── Location Permission
    │   └── Create Profile
    │
    ├── Authentication Flow
    │   ├── Sign In
    │   ├── Sign Up
    │   └── Forgot Password
    │
    └── Main App (Bottom Navigation)
        ├── Feed Tab (Home Dashboard)
        │   ├── Dashboard Cards (4 Quick Actions)
        │   ├── Nearby Dogs List
        │   └── Filter Options
        │
        ├── Map Tab
        │   ├── Real-time Dog Locations
        │   ├── Park Information
        │   └── Check-in Feature
        │
        ├── Messages Tab
        │   ├── Conversations List
        │   ├── Chat Detail
        │   └── Smart Replies
        │
        └── Profile Tab
            ├── User Profile
            ├── Dog Profile(s)
            └── Settings Menu
```

## 📋 Screen Inventory & Functions

### 1. **Authentication Screens**
- **Sign In Screen** (`sign_in_screen.dart`)
  - Email/password login
  - Social login options
  - "Remember me" functionality
  - Navigate to Sign Up or Forgot Password

- **Sign Up Screen** (`sign_up_screen.dart`)
  - User registration form
  - Email verification
  - Terms acceptance
  - Auto-login after signup

- **Forgot Password Screen** (`forgot_password_screen.dart`)
  - Email input for reset link
  - Success confirmation
  - Return to Sign In

### 2. **Onboarding Screens**
- **Welcome Screen** (`welcome_screen.dart`)
  - App introduction
  - Key features carousel
  - Get Started button

- **Location Permission Screen** (`location_permission_screen.dart`)
  - Explain why location is needed
  - Request permission
  - Skip option (limited features)

- **Create Profile Screen** (`create_profile_screen.dart`)
  - Owner information
  - Add first dog profile
  - Photo upload
  - Bio and preferences

### 3. **Main Navigation Screens**

#### **Feed Screen** (Home Dashboard) ✅ Existing
**Current Features:**
- Nearby dogs list
- "Catch" button navigation
- Basic filtering (not connected)

**Needed Improvements:**
- Add 4 dashboard cards at top:
  1. Upcoming Playdates (with count badge)
  2. New Notifications (with count badge)
  3. Find Friends (navigate to Catch)
  4. Social Feed (navigate to social posts)
- Connect filter button to filter bottom sheet
- Add pull-to-refresh
- Dog card click → Dog profile popup
- Hamburger menu → Settings drawer

#### **Map Screen** ✅ Existing
**Needed Features:**
- Google Maps integration
- Real-time dog markers
- Park boundaries and info
- Check-in button
- Filter by distance
- Navigate to dog profile on marker tap

#### **Messages Screen** ✅ Existing
**Needed Features:**
- Conversation list with last message
- Unread count badges
- Search conversations
- New message FAB
- Navigate to chat detail

#### **Profile Screen** ✅ Existing
**Current Features:**
- User info display
- Navigation to sub-screens

**Needed Improvements:**
- Edit profile functionality
- Add/manage multiple dogs
- Settings button → Settings screen
- Photo gallery section

### 4. **Feature Screens**

#### **Catch Screen** (Swipe Matching) ✅ Existing
**Current Features:**
- Swipe cards UI
- Accept/Decline buttons

**Needed Improvements:**
- Filter preferences button
- Super Like feature
- Match notification → Start conversation
- Daily limit for free users
- Undo last swipe (premium)

#### **Chat Detail Screen** ✅ Existing
**Needed Features:**
- Real-time messaging
- Photo sharing
- Voice messages
- Smart reply suggestions
- Schedule playdate button
- View dog profile button

#### **Playdates Screen** ✅ Existing
**Needed Features:**
- Upcoming playdates list
- Past playdates history
- Accept/Decline invitations
- Create new playdate
- Calendar integration
- Location suggestions

#### **Social Feed Screen** ✅ Existing
**Needed Features:**
- Photo/video posts
- Like and comment
- Share functionality
- Create post FAB
- Filter by following/nearby

#### **Achievements Screen** ✅ Existing
**Current Features:**
- Badge display grid

**Needed Improvements:**
- Progress tracking
- Unlock animations
- Share achievement
- Leaderboard section

#### **Premium Screen** ✅ Existing
**Current Features:**
- Feature list display

**Needed Improvements:**
- Pricing tiers
- Payment integration
- Current plan status
- Upgrade benefits comparison

#### **Notifications Screen** ✅ Existing
**Needed Features:**
- Grouped by type (Barks, Messages, Playdates)
- Mark as read
- Clear all option
- Deep linking to relevant screens

### 5. **Additional Screens Needed**

#### **Settings Screen** (`settings_screen.dart`) 🆕
- Account settings
- Privacy controls
- Notification preferences
- App preferences
- Help & Support
- Terms & Privacy
- Logout option

#### **Dog Profile Popup/Screen** (`dog_profile_detail.dart`) 🆕
- Full profile view
- Photo gallery
- Personality traits
- Play preferences
- Owner info
- Action buttons (Bark, Message, Playdate)

#### **Filter Bottom Sheet** (`filter_sheet.dart`) 🆕
- Distance radius
- Dog size
- Age range
- Breed selection
- Energy level
- Availability

#### **Create/Edit Dog Profile** (`edit_dog_profile_screen.dart`) 🆕
- Dog information form
- Photo upload (multiple)
- Personality quiz
- Medical info (private)
- Play preferences

#### **Create Playdate Screen** (`create_playdate_screen.dart`) 🆕
- Select participants
- Date/time picker
- Location selection (map)
- Activity type
- Notes/description
- Send invitations

#### **Help & Support Screen** (`help_screen.dart`) 🆕
- FAQ section
- Contact support
- Report issue
- App tutorial
- Community guidelines

#### **Report/Block Screen** (`report_screen.dart`) 🆕
- Report user/content
- Block user
- Safety resources
- Submit feedback

## 🔗 Screen Connections & Navigation Flow

### Navigation Hierarchy
```
1. Bottom Navigation (Persistent)
   - Always visible except in:
     - Auth screens
     - Onboarding screens
     - Full-screen modals

2. Stack Navigation
   - Push/pop for detail screens
   - Modal sheets for filters/options
   - Full-screen modals for create/edit

3. Deep Links
   - Notifications → Relevant screen
   - Messages → Chat detail
   - Playdates → Playdate detail
```

### Key User Flows

#### **New User Flow:**
1. Welcome → Location Permission → Sign Up → Create Profile → Feed (Dashboard)

#### **Returning User Flow:**
1. Sign In → Feed (Dashboard)

#### **Find & Connect Flow:**
1. Feed → Catch → Match → Message → Schedule Playdate

#### **Social Interaction Flow:**
1. Feed → Dog Card → Dog Profile → Bark/Message → Chat

#### **Playdate Flow:**
1. Dashboard Card → Playdates → Create → Select Friends → Confirm → Notification sent

## 🗄️ Supabase Integration Plan

### Database Tables Structure
```sql
-- Users table (owners)
users
  - id (uuid, primary key)
  - email (text, unique)
  - name (text)
  - avatar_url (text)
  - location (geography)
  - created_at (timestamp)

-- Dogs table
dogs
  - id (uuid, primary key)
  - owner_id (uuid, foreign key → users)
  - name (text)
  - breed (text)
  - age (integer)
  - size (text)
  - gender (text)
  - bio (text)
  - photos (text[])
  - personality_traits (jsonb)

-- Matches table (from Catch feature)
matches
  - id (uuid, primary key)
  - dog1_id (uuid, foreign key → dogs)
  - dog2_id (uuid, foreign key → dogs)
  - status (text) // 'pending', 'matched', 'declined'
  - created_at (timestamp)

-- Messages table
messages
  - id (uuid, primary key)
  - sender_id (uuid, foreign key → users)
  - receiver_id (uuid, foreign key → users)
  - content (text)
  - created_at (timestamp)

-- Playdates table
playdates
  - id (uuid, primary key)
  - organizer_id (uuid, foreign key → users)
  - location (geography)
  - scheduled_at (timestamp)
  - status (text)
  - participants (uuid[])

-- Posts table (social feed)
posts
  - id (uuid, primary key)
  - user_id (uuid, foreign key → users)
  - dog_id (uuid, foreign key → dogs)
  - content (text)
  - media_urls (text[])
  - likes_count (integer)
  - created_at (timestamp)

-- Notifications table
notifications
  - id (uuid, primary key)
  - user_id (uuid, foreign key → users)
  - type (text)
  - title (text)
  - body (text)
  - data (jsonb)
  - read (boolean)
  - created_at (timestamp)
```

### Real-time Features
- Messages: Subscribe to new messages
- Notifications: Push notifications for matches, messages, playdates
- Map: Live location updates
- Feed: Real-time post updates

## 📈 Sprint Plan

### Sprint 1: Foundation & Navigation (Week 1)
**Goal:** Create missing screens and establish all navigation connections

**Tasks:**
1. ✅ Create architecture documentation
2. Create missing screens:
   - [ ] Authentication screens (Sign In, Sign Up, Forgot Password)
   - [ ] Onboarding screens (Welcome, Location Permission, Create Profile)
   - [ ] Settings screen
   - [ ] Help & Support screen
   - [ ] Report/Block screen
3. Implement navigation:
   - [ ] Add navigation from all buttons to correct screens
   - [ ] Implement back navigation
   - [ ] Add bottom sheet for filters
   - [ ] Create dog profile popup/modal
4. Add dashboard to Feed screen:
   - [ ] Create 4 dashboard cards
   - [ ] Connect cards to respective screens
   - [ ] Add pull-to-refresh

### Sprint 2: Supabase Integration - Authentication (Week 2)
**Goal:** Connect authentication and user management

**Tasks:**
1. Database setup:
   - [ ] Create Supabase tables
   - [ ] Set up Row Level Security policies
   - [ ] Add sample data
2. Authentication:
   - [ ] Implement sign up with Supabase
   - [ ] Implement sign in
   - [ ] Add password reset
   - [ ] Persist auth state
3. Profile management:
   - [ ] Create user profile on signup
   - [ ] Edit profile functionality
   - [ ] Upload avatar to Supabase Storage

### Sprint 3: Core Features - Dogs & Matching (Week 3)
**Goal:** Connect dog profiles and matching system

**Tasks:**
1. Dog profiles:
   - [ ] CRUD operations for dog profiles
   - [ ] Photo upload to Storage
   - [ ] Fetch nearby dogs based on location
2. Catch (Matching) feature:
   - [ ] Save swipe decisions to database
   - [ ] Implement matching logic
   - [ ] Send match notifications
3. Feed improvements:
   - [ ] Real-time updates for nearby dogs
   - [ ] Implement filters with database queries
   - [ ] Add "Bark" interaction

### Sprint 4: Communication Features (Week 4)
**Goal:** Implement messaging and notifications

**Tasks:**
1. Messaging:
   - [ ] Real-time message sync
   - [ ] Conversation list from database
   - [ ] Smart reply suggestions (AI integration)
   - [ ] Media sharing
2. Notifications:
   - [ ] Push notification setup
   - [ ] In-app notification center
   - [ ] Notification preferences
3. Playdates:
   - [ ] Create playdate flow
   - [ ] Accept/decline invitations
   - [ ] Calendar integration

### Sprint 5: Social & Maps (Week 5)
**Goal:** Complete social features and map integration

**Tasks:**
1. Social feed:
   - [ ] Create/edit posts
   - [ ] Like and comment system
   - [ ] Follow/unfollow users
   - [ ] Media upload
2. Map integration:
   - [ ] Google Maps setup with API key
   - [ ] Display dog locations
   - [ ] Park information
   - [ ] Check-in feature
3. Achievements:
   - [ ] Track user activities
   - [ ] Unlock badges
   - [ ] Leaderboard

### Sprint 6: Premium & Polish (Week 6)
**Goal:** Add premium features and polish UX

**Tasks:**
1. Premium features:
   - [ ] Payment integration
   - [ ] Feature restrictions for free users
   - [ ] Premium badge display
2. UX improvements:
   - [ ] Loading states
   - [ ] Error handling [[memory:3803813]]
   - [ ] Empty states
   - [ ] Animations and transitions
3. Performance:
   - [ ] Image optimization
   - [ ] Lazy loading
   - [ ] Cache management
   - [ ] Offline support

## 🎨 UI/UX Guidelines

### Design Principles
1. **Warm & Welcoming**: Earthy colors, rounded corners, friendly illustrations
2. **Clear Hierarchy**: Important actions prominent, secondary actions accessible
3. **Consistent Patterns**: Similar actions behave the same way throughout
4. **Delightful Details**: Micro-animations, haptic feedback, sound effects
5. **Accessibility**: High contrast, clear labels, screen reader support

### Component Library
- **Cards**: Rounded corners (12px), subtle shadows, hover states
- **Buttons**: Primary (green), Secondary (outlined), Danger (red) [[memory:3653517]]
- **Forms**: Floating labels, clear validation, helpful hints
- **Navigation**: Clear active states, smooth transitions
- **Modals**: Slide-up sheets, full-screen for creation, popups for quick views

### Color Palette
- Primary: Forest Green (#2D5016)
- Secondary: Warm Brown (#8B4513)
- Accent: Sunny Yellow (#FFD700)
- Background: Soft Beige (#FAF7F0)
- Surface: White (#FFFFFF)
- Error: Soft Red (#DC3545)
- Success: Leaf Green (#28A745)

## 🚀 Implementation Priority

### Must Have (MVP)
1. Authentication flow
2. Dog profiles (view, create, edit)
3. Catch (matching) feature
4. Basic messaging
5. Feed with nearby dogs
6. Simple playdate scheduling

### Should Have
1. Social feed with posts
2. Map with dog locations
3. Notifications
4. Smart replies
5. Achievements
6. Filter options

### Nice to Have
1. Premium features
2. Voice messages
3. Video posts
4. Advanced matching algorithm
5. Event organization
6. Dog training resources

## 📝 Next Steps

1. **Immediate Actions:**
   - Create missing screen files
   - Implement navigation connections
   - Set up Supabase project
   - Design database schema

2. **Development Workflow:**
   - Create feature branches for each sprint
   - Daily commits with clear messages
   - Weekly progress reviews
   - User testing after each sprint

3. **Testing Strategy:**
   - Unit tests for business logic
   - Widget tests for UI components
   - Integration tests for user flows
   - Manual testing on iOS/Android

This architecture serves as our roadmap. Each sprint builds on the previous one, ensuring we maintain a working app at each stage while progressively adding features. The modular approach allows for flexibility if priorities change.
