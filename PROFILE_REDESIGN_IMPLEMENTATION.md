# BarkDate App - Complete Tab Architecture & User Journeys

## 🏗️ **Unified Profile Management Architecture**

### **Single Profile Creation System**
- **One unified screen**: `CreateProfileScreen` with multiple modes
- **No duplicate "add dog" flows** - everything routes to the same screen
- **Smart mode detection**: Create, edit dog only, edit owner only, edit both

### **Profile Screen Redesign**
- **Dog-centric main view** with owner as sub-section
- **Single edit points** that route to the unified profile system
- **Tab-based editing** when needed (Dog tab, Owner tab)

---

## 📱 **Tab 1: FEED SCREEN**

### **Purpose**: Social discovery and community engagement

### **User Journey**:
1. **Landing**: See nearby dogs' posts, playdates, and community updates
2. **Browse**: Infinite scroll of photo posts, playdate announcements, achievements
3. **Interact**: Like, comment, share posts
4. **Create**: Add new post with dog photos, location, status
5. **Discover**: Find dogs and owners through posts and mutual connections

### **Current State**: Basic feed structure exists
### **Integration Needed**:
- ✅ Supabase real-time for live feed updates
- ✅ Supabase storage for photo uploads
- ❌ **No Firebase dependency needed**

### **Sprint Plan**:
**Week 1-2**: Core Feed Infrastructure
- [ ] Real-time post loading from Supabase
- [ ] Photo upload integration with Supabase Storage
- [ ] Like/comment system with real-time updates
- [ ] Infinite scroll pagination

**Week 3**: Social Features
- [ ] Post creation UI with multiple photos
- [ ] User tagging and location tagging
- [ ] Post sharing and save functionality

**Week 4**: Community Features
- [ ] Trending posts and popular dogs
- [ ] Local community highlights
- [ ] Achievement celebrations

---

## 📱 **Tab 2: MAP SCREEN**

### **Purpose**: Location-based dog discovery and meetup coordination

### **User Journey**:
1. **Landing**: See map with nearby dogs, dog parks, and active playdates
2. **Explore**: Browse different areas, discover new dog-friendly locations
3. **Connect**: See real-time "dogs nearby" and initiate contact
4. **Navigate**: Get directions to dog parks, vet clinics, pet stores
5. **Create**: Host location-based playdates and events

### **Current State**: Basic map structure exists
### **Integration Needed**:
- ✅ **Google Maps API** (this requires Firebase/Google Cloud for API keys)
- ✅ Supabase for location data and user positions
- ✅ Real-time location updates

### **Sprint Plan**:
**Week 1**: Google Maps Integration
- [ ] Set up Google Maps API through Firebase console
- [ ] Basic map display with user location
- [ ] Location permission handling

**Week 2**: Dog Markers and Nearby Features
- [ ] Display nearby dogs as map markers
- [ ] Real-time position updates (with privacy controls)
- [ ] Dog park and pet-friendly location database

**Week 3**: Playdate and Event Mapping
- [ ] Show active playdates on map
- [ ] Location-based event creation
- [ ] Navigation integration for directions

**Week 4**: Advanced Features
- [ ] Geofencing for local notifications
- [ ] Popular routes and walking paths
- [ ] Emergency vet finder

---

## 📱 **Tab 3: MESSAGES SCREEN**

### **Purpose**: Direct communication between dog owners

### **User Journey**:
1. **Landing**: See conversation list with recent chats
2. **Browse**: Active conversations, playdate confirmations, group chats
3. **Chat**: Real-time messaging with photos, voice notes, location sharing
4. **Coordinate**: Plan playdates, share updates, emergency communication
5. **Groups**: Join local dog owner groups and community chats

### **Current State**: Basic message structure exists
### **Integration Needed**:
- ✅ Supabase real-time for instant messaging
- ✅ **Firebase Cloud Messaging (FCM)** for push notifications
- ✅ Supabase storage for media sharing

### **Sprint Plan**:
**Week 1**: Core Messaging
- [ ] Real-time chat with Supabase Realtime
- [ ] Message threading and conversation management
- [ ] Read receipts and online status

**Week 2**: Rich Media Support
- [ ] Photo and video sharing through Supabase Storage
- [ ] Voice message recording and playback
- [ ] Location sharing integration

**Week 3**: Group Features
- [ ] Group chat creation and management
- [ ] Playdate coordination chats
- [ ] Local community group discovery

**Week 4**: Advanced Features
- [ ] Push notifications via FCM
- [ ] Message encryption for privacy
- [ ] Emergency contact system

---

## 📱 **Tab 4: PROFILE SCREEN** (Redesigned)

### **Purpose**: Unified profile management and app settings

### **User Journey**:
1. **Landing**: Dog-centric profile view with owner info below
2. **View**: See dog stats, recent posts, achievements, playdate history
3. **Edit**: Unified editing system for dog and owner profiles
4. **Manage**: Access app settings, premium features, help
5. **Share**: Show profile to other users, generate QR codes

### **Current State**: Good structure, needs unification
### **Integration Needed**:
- ✅ Supabase for all profile data
- ✅ Supabase storage for photos
- ❌ **No Firebase dependency needed**

### **Redesign Plan**:

#### **New Layout**:
```
┌─────────────────────────────────────┐
│ [Settings Icon]        Profile     │
├─────────────────────────────────────┤
│           Dog Profile               │
│  ┌─────────┐  Max (Golden Retriever)│
│  │ Dog Pic │  "Loves fetch & treats" │
│  │  [Edit] │  📍 San Francisco       │
│  └─────────┘                        │
│  📊 23 Playdates | 89 Friends       │
├─────────────────────────────────────┤
│          Owner Section              │
│  👤 John Doe [Edit]                 │
│  📧 john@example.com                │
│  📱 Dog trainer & weekend hiker     │
├─────────────────────────────────────┤
│ 📅 My Playdates                     │
│ 🏆 Achievements                     │
│ ⭐ Go Premium                       │
│ ❓ Help & Support                   │
└─────────────────────────────────────┘
```

---

## 🎯 **Unified Profile Management Implementation**

### **Step 1: Consolidate Edit Flows**

<function_calls>
<invoke name="create_file">
<parameter name="content">// Updated Profile Screen with unified editing

```dart
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ... existing code ...

  // Single edit navigation function
  Future<void> _editProfile({
    required EditMode mode,
    String? title,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProfileScreen(
          userId: SupabaseConfig.auth.currentUser?.id,
          editMode: mode,
        ),
      ),
    );
    
    if (result == true) {
      _loadProfileData(); // Refresh data
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'edit_dog':
                  await _editProfile(mode: EditMode.editDog);
                  break;
                case 'edit_owner':
                  await _editProfile(mode: EditMode.editOwner);
                  break;
                case 'edit_both':
                  await _editProfile(mode: EditMode.editBoth);
                  break;
                case 'add_dog':
                  await _editProfile(mode: EditMode.createProfile);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit_dog',
                child: Row(
                  children: [
                    Icon(Icons.pets),
                    SizedBox(width: 12),
                    Text('Edit Dog Profile'),
                  ],
                ),
              ),
              if (_dogProfile == null)
                const PopupMenuItem(
                  value: 'add_dog',
                  child: Row(
                    children: [
                      Icon(Icons.add),
                      SizedBox(width: 12),
                      Text('Add Dog Profile'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit_owner',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 12),
                    Text('Edit Owner Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_both',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 12),
                    Text('Edit All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dog Profile Section (Main)
            _buildDogProfileSection(),
            
            // Owner Section (Secondary)
            _buildOwnerSection(),
            
            // Menu Items
            _buildMenuItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildDogProfileSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        children: [
          // Dog Photo with Edit Button
          Stack(
            children: [
              GestureDetector(
                onTap: () => _editProfile(mode: EditMode.editDog),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 57,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: _dogProfile?['main_photo_url'] != null
                        ? NetworkImage(_dogProfile!['main_photo_url'])
                        : null,
                    child: _dogProfile?['main_photo_url'] == null
                        ? Icon(
                            _dogProfile == null ? Icons.add : Icons.pets,
                            size: 50,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _dogProfile == null ? Icons.add : Icons.edit,
                    size: 16,
                    color: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Dog Name and Info
          Text(
            _dogProfile?['name'] ?? 'Add Your Dog',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          
          if (_dogProfile != null) ...[
            Text(
              '${_dogProfile!['breed']} • ${_dogProfile!['size']} • ${_dogProfile!['gender']}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          Text(
            _dogProfile?['bio'] ?? 'Add your dog to start connecting with other pups!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          
          if (_dogProfile != null) ...[
            const SizedBox(height: 24),
            // Dog Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(context, '23', 'Playdates'),
                _buildStatItem(context, '89', 'Friends'),
                _buildStatItem(context, '156', 'Photos'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOwnerSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: _userProfile?['avatar_url'] != null
              ? NetworkImage(_userProfile!['avatar_url'])
              : null,
          child: _userProfile?['avatar_url'] == null
              ? Icon(
                  Icons.person,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
        ),
        title: Text(
          _userProfile?['name'] ?? 'Owner Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_userProfile?['location'] != null)
              Text(
                '📍 ${_userProfile!['location']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (_userProfile?['bio'] != null)
              Text(
                _userProfile!['bio'],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editProfile(mode: EditMode.editOwner),
        ),
        onTap: () => _editProfile(mode: EditMode.editOwner),
      ),
    );
  }
  
  // ... rest of existing methods ...
}
```
