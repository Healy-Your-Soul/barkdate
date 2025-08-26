# BarkDate - Architecture Plan

## Overview
BarkDate is a social-first app for dog owners to connect, schedule playdates, and share adventures. Think Instagram meets Tinder for dogs with a warm, outdoorsy vibe.

## Core Features (MVP)
1. **Dog Profile Feed** - Browse nearby dogs with "Bark" interactions
2. **Swipe Matching (Catch)** - Tinder-style dog matching
3. **Direct Messaging** - 1:1 chat with smart replies
4. **Playdate Management** - Schedule, accept/decline playdates
5. **Social Feed** - Share posts, photos, interact with community
6. **Achievements System** - Badges for engagement
7. **Premium Plan** - Upsell screen with enhanced features
8. **Notifications Hub** - Central notification management
9. **Park Map** - Simple map showing nearby parks and check-ins
10. **Profile Management** - Create/edit dog profiles

## Technical Architecture

### Data Models
- `Dog` - Profile data (name, breed, age, photos, bio)
- `User` - Owner information 
- `Message` - Chat messages
- `Playdate` - Scheduled meetups
- `Post` - Social feed content
- `Achievement` - Badges and progress
- `ParkLocation` - Park data with check-ins

### Screen Structure
1. **Main Navigation** (4 tabs):
   - Feed (home social feed)
   - Map (park locations) 
   - Messages (chat list)
   - Profile (user/dog profile)

2. **Secondary Screens**:
   - Catch (swipe matching)
   - Chat Detail (individual conversations)
   - Playdate Management
   - Achievements
   - Premium Plan
   - Notifications
   - Settings

### File Organization
- `lib/main.dart` - App entry point
- `lib/theme.dart` - Earthy green theme
- `lib/models/` - Data models
- `lib/screens/` - Main screens
- `lib/widgets/` - Reusable components
- `lib/data/` - Sample data and storage

## Design System
- **Colors**: Earthy greens, warm neutrals, playful accent colors
- **Typography**: Inter font family, clear hierarchy
- **UI Style**: Clean, flat, modern with rounded corners
- **Icons**: Material icons with paw prints, park symbols
- **Layout**: Card-based design, generous whitespace

## Implementation Priority
1. Theme and navigation structure
2. Dog profile feed and data models
3. Swipe matching (Catch) feature
4. Basic messaging system
5. Playdate management
6. Social feed
7. Achievements and premium features
8. Park map integration