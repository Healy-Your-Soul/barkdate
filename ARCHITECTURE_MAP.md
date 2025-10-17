# BarkDate Architecture Map

## Current Navigation Structure (5 Tabs)
```
MainNavigation (lib/screens/main_navigation.dart)
├── FeedScreen (index 0) - Dashboard, nearby dogs, quick actions
├── MapScreen (index 1) - Google Maps, parks, search, dog counts  
├── PlaydatesScreen (index 2) - 3 tabs: Requests, Upcoming, Past
├── MessagesScreen (index 3) - Chat list with dog owners
└── ProfileScreen (index 4) - Dog profile primary, owner secondary
```

## Screen Navigation Flows
```
Auth Flow:
SupabaseAuthWrapper → WelcomeScreen → CreateProfileScreen → MainNavigation

Profile Creation:
CreateProfileScreen (supports edit modes: editDog, editOwner, editBoth, createProfile)

Secondary Screens (accessed via navigation):
├── SettingsScreen (from Profile menu)
├── HelpScreen (from Settings)
├── AchievementsScreen (from Profile menu)
├── PremiumScreen (from Profile menu)
├── SocialFeedScreen (from Profile menu)
├── NotificationsScreen (from Feed notifications)
├── DogProfileDetail (from Feed dog cards)
├── ChatDetailScreen (from Messages)
└── CatchScreen (from Feed matches)
```

## Service Layer Architecture
```
lib/services/
├── auth_service.dart - Authentication management
├── settings_service.dart - App settings and theme
├── notification_manager.dart - Push notifications
├── firebase_messaging_service.dart - FCM integration
├── in_app_notification_service.dart - In-app notifications
├── notification_sound_service.dart - Sound management
├── park_service.dart - Park data management
├── places_service.dart - Google Places integration
├── unified_map_service.dart - Map functionality
├── playdate_service.dart - Playdate CRUD operations
├── photo_upload_service.dart - Image upload to Supabase Storage
├── dog_sharing_service.dart - Dog profile sharing
├── shared_dog_service.dart - Multi-owner dog management
├── calendar_integration_service.dart - Calendar sync
└── google_calendar_service.dart - Google Calendar
```

## Supabase Services
```
lib/supabase/
├── supabase_config.dart - Configuration and client
├── barkdate_services.dart - Core CRUD operations
├── bark_playdate_services.dart - Playdate-specific operations
├── notification_service.dart - Notification management
└── [SQL files] - Database schemas and migrations
```

## Widget Architecture
```
lib/widgets/
├── dog_card.dart - Dog display cards (Feed)
├── dog_profile_sheet.dart - Dog profile modals
├── dog_share_dialog.dart - Sharing functionality
├── filter_sheet.dart - Filtering interface
├── enhanced_image_picker.dart - Image selection
├── photo_gallery.dart - Image galleries
├── playdate_request_modal.dart - Playdate creation
├── playdate_response_bottom_sheet.dart - Playdate responses
├── playdate_action_popup.dart - Playdate actions
├── playdate_action_button.dart - Playdate buttons
├── comment_modal.dart - Comments interface
├── notification_banner.dart - Notification display
├── notification_tile.dart - Notification items
└── supabase_auth_wrapper.dart - Auth wrapper
```

## Data Models
```
lib/models/
├── dog.dart - Dog profile model
├── enhanced_dog.dart - Extended dog model
├── message.dart - Chat messages
├── notification.dart - App notifications
├── park.dart - Park locations
├── playdate.dart - Playdate data
├── playdate_request.dart - Playdate requests
├── post.dart - Social posts
├── featured_park.dart - Featured parks
└── dog_share_link.dart - Sharing links
```

## Database Schema (Supabase)
```
Tables:
├── users - User profiles (linked to auth.users)
├── dogs - Dog profiles (user_id FK)
├── matches - Tinder-style matching
├── messages - Real-time chat
├── playdates - Playdate data
├── playdate_participants - Many-to-many participants
├── playdate_requests - Playdate invitations
├── posts - Social feed posts
├── post_likes - Post interactions
├── post_comments - Post comments
├── notifications - App notifications
├── achievements - Badge system
├── user_achievements - Earned badges
├── premium_subscriptions - Premium features
└── parks - Dog park locations
```

## UI/UX Inconsistencies Identified

### Spacing & Padding
- Inconsistent EdgeInsets.all() values: 4, 8, 12, 16, 24
- No standardized spacing system
- Mixed padding patterns across screens

### Border Radius
- Inconsistent BorderRadius.circular() values: 6, 8, 12, 20
- No standardized corner radius system
- Cards and buttons use different radius values

### Language Issues
- "Owner" terminology throughout (needs "Human" replacement)
- Owner-centric language in ProfileScreen
- Mixed dog/owner perspective in notifications

### Color Usage
- Hard-coded colors in some places instead of theme
- Inconsistent use of Theme.of(context).colorScheme
- Some screens use direct color values

### Component Reusability
- Similar card patterns implemented multiple times
- No standardized button components
- Inconsistent empty states across screens

## Theme System
```
lib/theme.dart
├── LightModeColors - Light theme color palette
├── DarkModeColors - Dark theme color palette  
├── FontSizes - Typography scale
├── lightTheme - Material 3 light theme
└── darkTheme - Material 3 dark theme

Colors:
- Primary: Green (#2D7D32)
- Secondary: Brown (#8D6E63)  
- Tertiary: Orange (#FF8A65)
- Error: Red (#D32F2F)
```

## Real-time Features
- Supabase real-time subscriptions for:
  - Messages (chat)
  - Notifications
  - Playdate updates
  - Dog count at parks
  - Match notifications

## File Storage (Supabase Storage)
```
Buckets:
├── dog-photos - Dog profile images
├── user-avatars - User profile pictures
├── post-images - Social post images
├── chat-media - Chat attachments
└── playdate-albums - Playdate photos
```

## Performance Considerations
- IndexedStack for tab navigation (maintains state)
- Image compression in PhotoUploadService
- Lazy loading for dog lists
- Real-time subscriptions with proper cleanup
- Supabase RLS (Row Level Security) policies

## Areas for Improvement
1. Standardize spacing system (8px grid)
2. Create reusable UI components
3. Implement consistent design patterns
4. Add proper error boundaries
5. Improve loading states
6. Add skeleton loaders
7. Implement proper state management
8. Add comprehensive testing
