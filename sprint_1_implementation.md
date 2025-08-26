# Sprint 1: Foundation & Navigation Implementation 🚀

## Sprint Goal
Create all missing screens and establish complete navigation flow with excellent UX. No dead ends, no "rabbit holes" - every button leads somewhere meaningful!

## 🎯 Sprint 1 Tasks Breakdown

### Task 1: Create Authentication Flow Screens

#### 1.1 Sign In Screen (`sign_in_screen.dart`)
**Components:**
- [ ] App logo/illustration at top
- [ ] Email input field
- [ ] Password input field (with show/hide toggle)
- [ ] "Remember me" checkbox
- [ ] Sign In button (primary color, rounded)
- [ ] "Forgot Password?" link
- [ ] Divider with "OR"
- [ ] Social login buttons (Google, Apple)
- [ ] "Don't have an account? Sign Up" link at bottom

**Navigation:**
- Sign In button → Validate → Main Navigation (Feed)
- Forgot Password → Forgot Password Screen
- Sign Up link → Sign Up Screen
- Social login → OAuth flow → Main Navigation

#### 1.2 Sign Up Screen (`sign_up_screen.dart`)
**Components:**
- [ ] Back button (top left)
- [ ] "Create Account" title
- [ ] Name input field
- [ ] Email input field
- [ ] Password input field (with strength indicator)
- [ ] Confirm password field
- [ ] Terms & Conditions checkbox
- [ ] Sign Up button
- [ ] "Already have an account? Sign In" link

**Navigation:**
- Back button → Sign In Screen
- Sign Up button → Validate → Create Profile Screen
- Sign In link → Sign In Screen

#### 1.3 Forgot Password Screen (`forgot_password_screen.dart`)
**Components:**
- [ ] Back button
- [ ] Illustration (dog with mail)
- [ ] "Reset Password" title
- [ ] Instruction text
- [ ] Email input field
- [ ] Send Reset Link button
- [ ] Success message (after sending)

**Navigation:**
- Back button → Sign In Screen
- After success → Show "Check email" message → Return to Sign In button

### Task 2: Create Onboarding Screens

#### 2.1 Welcome Screen (`welcome_screen.dart`)
**Components:**
- [ ] Skip button (top right)
- [ ] Page indicator dots
- [ ] Carousel with 3 slides:
  1. "Find Nearby Dog Friends" - Map illustration
  2. "Schedule Playdates" - Dogs playing illustration
  3. "Build Your Pack" - Community illustration
- [ ] Get Started button (appears on last slide)

**Navigation:**
- Skip → Location Permission Screen
- Get Started → Location Permission Screen
- Auto-advance through carousel

#### 2.2 Location Permission Screen (`location_permission_screen.dart`)
**Components:**
- [ ] Friendly illustration (dog in park with location pin)
- [ ] Title: "Enable Location Services"
- [ ] Explanation text (why we need location)
- [ ] Benefits list (3 items with icons)
- [ ] Enable Location button (primary)
- [ ] "Maybe Later" link (secondary)

**Navigation:**
- Enable Location → Request permission → Create Profile Screen
- Maybe Later → Create Profile Screen (with limited features flag)

#### 2.3 Create Profile Screen (`create_profile_screen.dart`)
**Components:**
- [ ] Progress bar (2 steps: Your Info, Your Dog)
- [ ] Step 1: Owner Info
  - [ ] Profile photo upload (circular)
  - [ ] Name field
  - [ ] Bio field (optional)
  - [ ] Location (auto-filled or manual)
- [ ] Step 2: Dog Info
  - [ ] Dog photo upload
  - [ ] Dog name
  - [ ] Breed (dropdown/search)
  - [ ] Age
  - [ ] Size (Small/Medium/Large)
  - [ ] Gender
  - [ ] Bio/personality
- [ ] Create Profile button

**Navigation:**
- Next (Step 1) → Step 2
- Back (Step 2) → Step 1
- Create Profile → Save to Supabase → Main Navigation (Feed)

### Task 3: Create Additional Screens

#### 3.1 Settings Screen (`settings_screen.dart`)
**Components:**
- [ ] Back button
- [ ] "Settings" title
- [ ] Sections:
  - **Account**
    - [ ] Profile (navigate to edit profile)
    - [ ] App Preferences
    - [ ] Privacy
  - **Support**
    - [ ] Help Center
    - [ ] Contact Us
    - [ ] Report a Bug
  - **Legal**
    - [ ] Terms of Service
    - [ ] Privacy Policy
- [ ] App version at bottom
- [ ] Sign Out button (red text)

**Navigation:**
- Back → Previous screen
- Each item → Respective screen/modal
- Sign Out → Confirm dialog → Sign In Screen

#### 3.2 Help & Support Screen (`help_screen.dart`)
**Components:**
- [ ] Back button
- [ ] Search bar ("Search for answers")
- [ ] FAQ sections (expandable):
  - Getting Started
  - Using the App
  - Account Settings
  - Safety & Privacy
  - Premium Features
- [ ] "Still need help?" section
- [ ] Contact Support button

**Navigation:**
- Back → Settings Screen
- Contact Support → Opens email/chat

#### 3.3 Dog Profile Detail (Modal/Screen) (`dog_profile_detail.dart`)
**Components:**
- [ ] Close button (X) or back arrow
- [ ] Photo carousel (swipeable)
- [ ] Dog name, age, breed
- [ ] Distance badge
- [ ] Owner info (small section)
- [ ] Personality traits (chips)
- [ ] Bio section
- [ ] Play preferences
- [ ] Action buttons:
  - [ ] Bark button (like)
  - [ ] Message button
  - [ ] Suggest Playdate button
- [ ] Report/Block option (three dots menu)

**Navigation:**
- Close → Return to previous screen
- Bark → Show feedback animation
- Message → Chat Detail Screen
- Suggest Playdate → Create Playdate Screen (pre-filled)
- Report → Report Screen

#### 3.4 Filter Bottom Sheet (`filter_sheet.dart`)
**Components:**
- [ ] Handle bar (draggable)
- [ ] "Filter" title with Reset button
- [ ] Distance slider (0-50 miles)
- [ ] Dog Size checkboxes (Small, Medium, Large)
- [ ] Age range slider
- [ ] Breed multi-select
- [ ] Energy Level (Low, Medium, High)
- [ ] Availability toggle (Available for playdates)
- [ ] Apply Filters button
- [ ] Active filter count badge

**Navigation:**
- Drag down/tap outside → Close
- Reset → Clear all filters
- Apply → Close sheet and refresh list

#### 3.5 Report/Block Screen (`report_screen.dart`)
**Components:**
- [ ] Back button
- [ ] User/Dog info being reported
- [ ] "Report or Block" title
- [ ] Explanation text
- [ ] Reason selection (radio buttons):
  - Inappropriate content
  - Harassment or bullying
  - Spam or fake account
  - Safety concern
  - Other (with text field)
- [ ] Additional details text field
- [ ] Block user checkbox
- [ ] Submit button

**Navigation:**
- Back → Previous screen
- Submit → Show confirmation → Return to feed

### Task 4: Update Feed Screen with Dashboard

#### 4.1 Dashboard Cards Implementation
**Location:** Top of Feed Screen, below app bar

**Card 1: Upcoming Playdates**
- [ ] Icon: Calendar
- [ ] Title: "Playdates"
- [ ] Subtitle: "3 upcoming" (dynamic count)
- [ ] Tap → Playdates Screen

**Card 2: Notifications**
- [ ] Icon: Bell
- [ ] Title: "Notifications"
- [ ] Badge: Red circle with count
- [ ] Tap → Notifications Screen

**Card 3: Find Friends**
- [ ] Icon: Heart/Paw
- [ ] Title: "Catch"
- [ ] Subtitle: "Find new friends"
- [ ] Tap → Catch Screen

**Card 4: Social Feed**
- [ ] Icon: Photo/Grid
- [ ] Title: "Social"
- [ ] Subtitle: "Community posts"
- [ ] Tap → Social Feed Screen

**Layout:**
- 2x2 grid
- Cards with subtle shadow
- Hover/press states
- Consistent padding

### Task 5: Connect All Navigation

#### 5.1 Navigation Connections Checklist

**Feed Screen:**
- [x] Catch button → Catch Screen
- [x] Notifications icon → Notifications Screen
- [ ] Filter icon → Filter Bottom Sheet
- [ ] Hamburger menu → Settings Drawer
- [ ] Dog card tap → Dog Profile Detail
- [ ] Dashboard cards → Respective screens
- [ ] Pull to refresh → Reload data

**Map Screen:**
- [ ] Dog marker tap → Dog Profile popup
- [ ] Check-in button → Check-in dialog
- [ ] Filter button → Filter sheet
- [ ] Current location button → Center map

**Messages Screen:**
- [x] Conversation item → Chat Detail Screen
- [ ] New message FAB → User selection → Chat Detail
- [ ] Search bar → Filter conversations
- [ ] Long press → Delete/Archive options

**Profile Screen:**
- [x] Playdates → Playdates Screen
- [x] Social Feed → Social Feed Screen
- [x] Achievements → Achievements Screen
- [x] Premium → Premium Screen
- [ ] Settings icon → Settings Screen
- [ ] Edit profile → Edit Profile Screen
- [ ] My Dog edit → Edit Dog Profile Screen
- [ ] Help → Help Screen
- [ ] Privacy → Privacy Screen

**Catch Screen:**
- [ ] Filter icon → Filter preferences modal
- [ ] Info icon on card → Dog Profile Detail
- [ ] Match notification → Navigate to Messages

**Chat Detail Screen:**
- [ ] Back → Messages Screen
- [ ] Profile pic/name → Dog Profile Detail
- [ ] Attachment → Photo picker
- [ ] Schedule playdate → Create Playdate (pre-filled)

**All Screens:**
- [ ] Proper back navigation
- [ ] Loading states
- [ ] Error states with retry [[memory:3803813]]
- [ ] Empty states with CTAs

### Task 6: Create Navigation Service

#### 6.1 Navigation Service (`navigation_service.dart`)
```dart
class NavigationService {
  // Central navigation management
  - Route management
  - Deep linking support
  - Navigation guards (auth check)
  - Transition animations
  - Bottom nav visibility control
}
```

### Task 7: Implement Drawer Menu

#### 7.1 App Drawer (`app_drawer.dart`)
**Components:**
- [ ] User header (photo, name, email)
- [ ] Menu items:
  - My Profile
  - My Dogs
  - Settings
  - Help & Support
  - Invite Friends
  - Rate App
  - Sign Out

**Navigation:**
- Each item → Respective screen
- Close drawer on selection

## 📊 Success Metrics

### Completion Checklist
- [ ] All screens created and styled
- [ ] All navigation paths working
- [ ] No dead-end screens
- [ ] Back navigation consistent
- [ ] Loading/error states implemented
- [ ] Animations smooth
- [ ] Responsive on all screen sizes
- [ ] Dark mode support
- [ ] Accessibility labels added

### User Flow Tests
1. **New User:** Can complete entire onboarding
2. **Returning User:** Can sign in and access all features
3. **Discovery:** Can find and connect with dogs
4. **Communication:** Can message and schedule playdates
5. **Profile:** Can edit all profile information
6. **Settings:** Can access all settings and help

## 🛠️ Implementation Order

### Day 1-2: Authentication & Onboarding
1. Create auth screens (Sign In, Sign Up, Forgot Password)
2. Create onboarding screens (Welcome, Location, Create Profile)
3. Implement navigation between auth screens
4. Add form validation

### Day 3-4: Core Missing Screens
1. Create Settings screen
2. Create Help & Support screen
3. Create Dog Profile Detail modal
4. Create Filter bottom sheet
5. Create Report/Block screen

### Day 5-6: Navigation Connections
1. Update Feed screen with dashboard
2. Connect all buttons to destinations
3. Implement navigation service
4. Add drawer menu
5. Test all navigation paths

### Day 7: Polish & Testing
1. Add loading states
2. Add error handling
3. Add animations
4. Test on different devices
5. Fix any navigation issues

## 🎨 UI Components to Reuse

### Custom Widgets Needed
1. **DashboardCard** - For feed dashboard
2. **CustomTextField** - Consistent input styling
3. **PrimaryButton** - App's main CTA button
4. **ProfileAvatar** - User/dog profile pictures
5. **LoadingOverlay** - Consistent loading states
6. **EmptyState** - When no data available
7. **ErrorState** - When something goes wrong

## 📝 Notes

### Navigation Principles
1. **Always provide a way back** - No screen should trap the user
2. **Show where you are** - Clear active states in bottom nav
3. **Predictable behavior** - Similar actions work the same way
4. **Smooth transitions** - Use appropriate animations
5. **Preserve state** - Don't lose user input on navigation

### UX Best Practices
1. **Progressive disclosure** - Don't overwhelm new users
2. **Clear CTAs** - One primary action per screen
3. **Helpful empty states** - Guide users on what to do
4. **Inline validation** - Show errors as user types
5. **Optimistic updates** - Show success before server confirms

### Technical Considerations
1. Use `Navigator 2.0` for complex routing
2. Implement deep linking from start
3. Handle back button on Android properly
4. Save form state before navigation
5. Lazy load heavy screens
6. Cache user data locally

## ✅ Definition of Done

A screen/feature is considered DONE when:
1. UI matches design/description
2. All navigation paths work
3. Forms have validation
4. Loading/error states exist
5. Responsive on phones/tablets
6. Tested on iOS and Android
7. No console errors
8. Code is clean and documented

This sprint sets the foundation for the entire app. Once complete, we'll have a fully navigable skeleton ready for backend integration!
