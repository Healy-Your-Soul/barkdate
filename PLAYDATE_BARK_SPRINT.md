# BarkDate: Bark Notifications & Playdate System Sprint 🐕

## 📋 Sprint Overview

**Goal**: Implement a complete bark notification and playdate management system that allows users to:
1. **Bark** at other dogs (like saying hello) - sends notification without commitment
2. **Schedule Playdates** with other dog owners with time/location selection
3. **Manage Playdate Requests** (approve, edit, decline)
4. **View Upcoming Playdates** in organized sections
5. **Create Playdate Recaps** with photos/posts after meetings

---

## 🏗️ Current Architecture Analysis

### ✅ **What We Already Have**
- **Database Schema**: Complete tables for `users`, `dogs`, `matches`, `playdates`, `playdate_participants`, `notifications`
- **Dog Discovery UI**: Feed screen with nearby dogs display
- **DogCard Component**: Shows dog info with basic "Bark" button
- **Playdates Screen**: Basic upcoming/past playdate display
- **Social Feed**: Post creation and sharing system
- **Notification System**: Database table and basic UI for notifications
- **Matching System**: Already tracks bark/pass actions in `matches` table

### 🔧 **What Needs Enhancement**

#### **Backend Services** 
- ✅ Basic playdate queries exist but need enhancement
- ❌ No bark notification creation service
- ❌ No real-time playdate request management
- ❌ No playdate status update workflows
- ❌ No notification delivery system

#### **Frontend Components**
- ✅ Basic DogCard with bark button exists
- ❌ No playdate request UI/modal
- ❌ No playdate editing interface
- ❌ No notification management
- ❌ No real-time updates

---

## 🎯 Sprint Features & User Stories

### **1. Bark Notification System**
**User Story**: *"As a dog owner, I want to bark at other dogs to show interest and start a conversation without any commitment."*

**Features**:
- Tap "Bark" button on any dog card
- Creates instant notification to dog owner
- Recipient sees: "Charlie barked at Luna! 🐕"
- Can lead to conversation or playdate invitation
- Track bark history (prevent spam)

### **2. Playdate Request System**
**User Story**: *"As a dog owner, I want to invite another dog for a playdate by selecting time, location, and additional details."*

**Features**:
- "Playdate" button next to "Bark" button
- Modal with: Date/Time picker, Location selector, Message field
- Can invite multiple dogs to same playdate
- Sends notification with playdate details
- Recipient can: Accept, Decline, Counter-propose

### **3. Playdate Management**
**User Story**: *"As a dog owner, I want to manage my playdate invitations and see all upcoming meetings in one place."*

**Features**:
- View incoming playdate requests
- Accept/Decline with optional message
- Edit playdate details (time/location) if organizer
- Real-time status updates for all participants
- Calendar integration showing upcoming playdates

### **4. Playdate Experience & Follow-up**
**User Story**: *"After a playdate, I want to share how it went and add photos to remember the fun."*

**Features**:
- Playdate recap screen with rating system
- Photo upload capability
- Option to post recap to social feed
- Rate the location for future recommendations
- Add participating dogs as "friends"

---

## 🔧 Technical Implementation Plan

### **Phase 1: Database Enhancements** ⏱️ 2 hours

#### **New Tables/Fields Needed**:

```sql
-- Add bark tracking to prevent spam
ALTER TABLE matches ADD COLUMN bark_count integer DEFAULT 0;
ALTER TABLE matches ADD COLUMN last_bark_at timestamp with time zone;

-- Enhanced playdate requests table
CREATE TABLE playdate_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'counter_proposed')),
  message text,
  counter_proposal jsonb, -- For time/location changes
  created_at timestamp with time zone DEFAULT now(),
  responded_at timestamp with time zone,
  UNIQUE(playdate_id, invitee_id)
);

-- Playdate recaps
CREATE TABLE playdate_recaps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  location_rating integer CHECK (location_rating >= 1 AND location_rating <= 5),
  recap_text text,
  photos text[] DEFAULT '{}',
  shared_to_feed boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(playdate_id, user_id)
);

-- Enhanced notifications with better typing
ALTER TABLE notifications ADD COLUMN action_type text;
ALTER TABLE notifications ADD COLUMN related_id uuid; -- playdate_id, user_id, etc.
```

### **Phase 2: Backend Service Layer** ⏱️ 4 hours

#### **Enhanced BarkDate Services**:

**New Service Methods Needed**:
1. `BarkNotificationService.sendBark(fromUserId, toUserId, dogId)`
2. `PlaydateRequestService.createPlaydateRequest(organizer, participants, details)`
3. `PlaydateRequestService.respondToRequest(requestId, response, message)`
4. `PlaydateRequestService.updatePlaydateDetails(playdateId, changes)`
5. `NotificationService.createNotification(userId, type, data)`
6. `PlaydateRecapService.createRecap(playdateId, userId, recap)`

### **Phase 3: UI Components Enhancement** ⏱️ 6 hours

#### **Enhanced DogCard Component**:
```dart
// Add playdate button next to bark button
Row(
  children: [
    ElevatedButton(
      onPressed: onBarkPressed,
      child: Text('Bark'),
    ),
    SizedBox(width: 8),
    OutlinedButton.icon(
      onPressed: onPlaydatePressed,
      icon: Icon(Icons.calendar_today),
      label: Text('Playdate'),
    ),
  ],
)
```

#### **New Components to Create**:
1. **PlaydateRequestModal** - For creating playdate invitations
2. **PlaydateRequestCard** - Display incoming requests
3. **PlaydateEditModal** - Edit existing playdate details  
4. **PlaydateRecapScreen** - Rate experience and add photos
5. **NotificationListItem** - Enhanced notification display
6. **PlaydateCalendarView** - Calendar widget for upcoming playdates

### **Phase 4: Screen Enhancements** ⏱️ 4 hours

#### **Enhanced Notifications Screen**:
- Group notifications by type (Barks, Playdates, Messages)
- Real-time updates when new notifications arrive
- Action buttons for playdate requests (Accept/Decline)
- Deep linking to relevant screens

#### **Enhanced Playdates Screen**:
- Real-time updates for playdate status changes
- Swipe actions for quick accept/decline
- Filter by status (Pending, Confirmed, Completed)
- FAB for creating new playdate

#### **Enhanced Dog Profile Detail**:
- Add Bark and Playdate buttons
- Show mutual friends/previous playdates
- Display bark/interaction history

### **Phase 5: Real-time Features** ⏱️ 3 hours

#### **Supabase Real-time Integration**:
```dart
// Listen for new notifications
SupabaseConfig.client
  .from('notifications')
  .stream(primaryKey: ['id'])
  .eq('user_id', currentUserId)
  .listen((data) {
    // Update UI with new notifications
  });

// Listen for playdate updates
SupabaseConfig.client
  .from('playdates')
  .stream(primaryKey: ['id'])
  .or('organizer_id.eq.$userId,participant_id.eq.$userId')
  .listen((data) {
    // Update playdate list
  });
```

---

## 📱 User Experience Flow

### **Bark Flow**:
1. User sees interesting dog on feed
2. Taps "Bark" button on DogCard
3. Confirmation snackbar: "You barked at Luna! 🐕"
4. Recipient gets notification: "Charlie barked at Luna!"
5. Recipient can tap notification to view Charlie's profile
6. Can lead to conversation or playdate invitation

### **Playdate Request Flow**:
1. User taps "Playdate" button on DogCard
2. PlaydateRequestModal opens with:
   - Date/Time picker (default: next weekend)
   - Location selector (nearby parks suggested)
   - Message field ("Let's have a playdate!")
   - Duration selector (30min, 1hr, 2hr)
3. User fills details and taps "Send Request"
4. Recipient gets notification: "Sarah invited Luna for a playdate!"
5. Recipient opens notification → PlaydateRequestCard shows:
   - Playdate details
   - Accept/Decline/Counter-propose buttons
6. If accepted → Added to both users' "Upcoming Playdates"
7. Day of playdate → reminder notifications
8. After playdate → option to create recap

### **Playdate Management Flow**:
1. User opens Playdates screen
2. "Pending Requests" section shows incoming invitations
3. "Upcoming" section shows confirmed playdates
4. "Past" section shows completed playdates with recap option
5. Tap any playdate → detailed view with:
   - Participants list
   - Location (with directions)
   - Chat option with participants
   - Edit option (if organizer)

---

## 🚀 Implementation Priority

### **Week 1: Core Functionality** 
1. ✅ **Day 1-2**: Database schema updates
2. ✅ **Day 3-4**: Backend service implementation  
3. ✅ **Day 5**: Basic UI components (Bark/Playdate buttons)

### **Week 2: User Experience**
1. ✅ **Day 1-2**: Playdate request modal and flow
2. ✅ **Day 3-4**: Notifications integration
3. ✅ **Day 5**: Real-time updates

### **Week 3: Polish & Testing**
1. ✅ **Day 1-2**: Playdate recap system
2. ✅ **Day 3-4**: Integration testing
3. ✅ **Day 5**: UI polish and error handling

---

## 🧪 Testing Strategy

### **Unit Tests**:
- Service methods for bark/playdate operations
- Notification creation and delivery
- Data validation for playdate requests

### **Integration Tests**:
- End-to-end bark flow
- Complete playdate request cycle
- Real-time notification delivery
- Cross-user playdate management

### **User Testing Scenarios**:
1. **First-time Bark**: User discovers app and sends first bark
2. **Playdate Creation**: User schedules first playdate with another user
3. **Request Management**: User receives and responds to playdate request
4. **Playdate Day**: Users meet and complete playdate
5. **Recap Creation**: Users rate experience and share photos

---

## 📊 Success Metrics

### **Engagement Metrics**:
- **Bark Rate**: Average barks per user per week
- **Playdate Conversion**: % of barks that lead to playdate requests
- **Acceptance Rate**: % of playdate requests accepted
- **Completion Rate**: % of scheduled playdates that actually happen
- **Recap Sharing**: % of playdates that get shared to social feed

### **User Experience Metrics**:
- **Time to First Bark**: How quickly new users engage
- **Notification Response Time**: How quickly users respond to playdate requests
- **Repeat Playdates**: % of users who schedule multiple playdates
- **Friend Building**: Average new connections per user per month

---

## 🔧 Development Notes

### **Database Considerations**:
- Use Supabase real-time subscriptions for instant updates
- Implement proper indexing for notification queries
- Add RLS policies for playdate privacy
- Consider soft deletes for playdate history

### **Performance Optimizations**:
- Cache nearby dogs list to reduce API calls
- Batch notification creation for multiple recipients
- Optimize image uploads for playdate recaps
- Implement pagination for notification lists

### **Security & Privacy**:
- Validate all playdate request data server-side
- Implement spam prevention for bark notifications
- Ensure only participants can view playdate details
- Add block/report functionality for bad actors

### **Future Enhancements**:
- Group playdates (3+ dogs)
- Recurring playdates (weekly walks)
- Playdate templates (common locations/times)
- Integration with calendar apps
- Weather-based playdate suggestions
- Social features (playdate leaderboards, local groups)

---

## 📋 Implementation Checklist

- [ ] **Database schema updates**
- [ ] **Backend service methods**
- [ ] **Enhanced DogCard with Playdate button**
- [ ] **PlaydateRequestModal component**
- [ ] **Notification integration**
- [ ] **Real-time updates**
- [ ] **Playdates screen enhancement**
- [ ] **Playdate recap system**
- [ ] **Testing and polish**
- [ ] **Documentation updates**

---

*This sprint focuses on building the core social interaction features that will drive user engagement and create the foundation for BarkDate's community-building goals. The bark system provides low-commitment interaction, while the playdate system enables real-world connections between dog owners.*
