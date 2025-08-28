# Social Feed System - Instagram for Dogs Sprint 📸🐕

*Complete implementation plan for Instagram-style social feed with global search*

## 🎯 **Sprint Overview**

**Goal**: Create a complete Instagram-like social feed where dog owners can share posts, photos, locations, and discover other dogs through a global search system.

**Duration**: 2-3 weeks  
**Priority**: High (Core social feature)

---

## 📋 **Current State Analysis**

### ✅ **What's Already Working:**
- Basic social feed UI exists (`social_feed_screen.dart`)
- Post model defined (`models/post.dart`)
- Basic post creation modal
- `BarkDateSocialService` with `createPost` method
- `post-images` bucket defined in `PhotoUploadService`
- Database schema for posts exists

### ❌ **What's Missing/Broken:**
- **Post image upload not connected** to UI
- No actual post creation functionality 
- No global search system
- No location/GPS integration
- No buddy/following system
- No privacy controls (public vs private profiles)
- No post interactions (likes, comments)

---

## 🔧 **Technical Architecture Plan**

### **1. Database Schema Updates Needed:**

```sql
-- Update posts table
ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility text DEFAULT 'public'; -- 'public', 'friends', 'private'
ALTER TABLE posts ADD COLUMN IF NOT EXISTS likes_count integer DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS comments_count integer DEFAULT 0;

-- Create search/discovery tables
CREATE TABLE IF NOT EXISTS user_follows (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  follower_id uuid REFERENCES users(id) ON DELETE CASCADE,
  following_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(follower_id, following_id)
);

CREATE TABLE IF NOT EXISTS post_likes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE TABLE IF NOT EXISTS post_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id uuid REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following ON user_follows(following_id);
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON posts(visibility);
CREATE INDEX IF NOT EXISTS idx_posts_location ON posts(latitude, longitude);
```

### **2. Storage Buckets Verification:**
Need to ensure all buckets exist and work:
- ✅ `dog-photos` 
- ✅ `user-avatars`
- ❓ `post-images` (needs testing)
- ❓ `chat-media` (needs testing)  
- ❓ `playdate-albums` (needs testing)

---

## 🚀 **Implementation Sprint Tasks**

### **PHASE 1: Fix Image Upload (1-2 days)**
- [ ] **1.1** Test `post-images` bucket functionality
- [ ] **1.2** Fix post image upload connection in UI
- [ ] **1.3** Test all other buckets (`chat-media`, `playdate-albums`)
- [ ] **1.4** Create bucket test/verification screen

### **PHASE 2: Enhanced Post Creation (2-3 days)**
- [ ] **2.1** Create dedicated `CreatePostScreen` (full-screen, not modal)
- [ ] **2.2** Integrate image upload with `PhotoUploadService`
- [ ] **2.3** Add location picker with GPS integration
- [ ] **2.4** Add hashtag support and parsing
- [ ] **2.5** Add dog tagging (which dog is in the post)
- [ ] **2.6** Add privacy controls (public/friends/private)

### **PHASE 3: Global Search System (3-4 days)**
- [ ] **3.1** Create `SearchScreen` with search bar
- [ ] **3.2** Implement user/dog search functionality
- [ ] **3.3** Add location-based search
- [ ] **3.4** Add hashtag search
- [ ] **3.5** Implement search filters (distance, age, breed, etc.)
- [ ] **3.6** Add search history and suggestions

### **PHASE 4: Social Features (2-3 days)**
- [ ] **4.1** Implement follow/unfollow system
- [ ] **4.2** Create "buddies" concept (mutual followers)
- [ ] **4.3** Add post likes functionality
- [ ] **4.4** Add basic commenting system
- [ ] **4.5** Update feed algorithm (buddies first, then public)

### **PHASE 5: Feed Enhancement (2-3 days)**
- [ ] **5.1** Improve feed loading (pagination, infinite scroll)
- [ ] **5.2** Add pull-to-refresh
- [ ] **5.3** Add post interactions UI
- [ ] **5.4** Add location display on posts
- [ ] **5.5** Add "Nearby Posts" feature

---

## 📱 **User Experience Flow**

### **Post Creation Flow:**
1. Tap "+" floating action button
2. Open `CreatePostScreen`
3. Write post content
4. Add photo(s) via `EnhancedImagePicker`
5. Add location (GPS or manual)
6. Select which dog is featured
7. Choose privacy level
8. Add hashtags
9. Publish post

### **Search Flow:**
1. Tap search icon in app bar
2. Open `SearchScreen` with search bar
3. Type to search users, dogs, locations, hashtags
4. See results categorized:
   - **Buddies** (people you follow)
   - **Nearby Dogs** (location-based)
   - **Popular Posts** (trending)
   - **Matched Dogs** (from your matches)
5. Apply filters (distance, breed, etc.)
6. Tap result to view profile or post

### **Feed Algorithm:**
1. **Buddies First**: Posts from dogs/users you follow
2. **Nearby**: Public posts from nearby dogs
3. **Matched**: Posts from dogs you've matched with
4. **Popular**: Trending posts with high engagement

---

## 🔐 **Privacy & Security**

### **Profile Privacy Levels:**
- **Public**: Anyone can see posts and profile
- **Friends Only**: Only buddies can see posts  
- **Private**: Only approved followers can see

### **Post Privacy Levels:**
- **Public**: Visible to everyone
- **Friends**: Only visible to buddies
- **Private**: Only visible to you

---

## 🎨 **UI/UX Components Needed**

### **New Screens:**
1. **`CreatePostScreen`** - Full-screen post composer
2. **`SearchScreen`** - Global search with filters
3. **`UserProfileScreen`** - View other users' profiles
4. **`PostDetailScreen`** - Individual post view with comments

### **New Widgets:**
1. **`PostComposer`** - Rich post creation widget
2. **`LocationPicker`** - GPS + manual location selection
3. **`HashtagInput`** - Smart hashtag parsing
4. **`SearchBar`** - Global search with suggestions
5. **`UserCard`** - Search result user display
6. **`PostInteractions`** - Like, comment, share buttons

### **Enhanced Existing:**
1. **`PostCard`** - Add interactions, location, better image handling
2. **`SocialFeedScreen`** - Add search, better navigation

---

## 🧪 **Testing Strategy**

### **Image Upload Testing:**
1. Test each bucket individually
2. Test cross-platform (Web, iOS, Android)
3. Test multiple image formats
4. Test large file handling

### **Search Testing:**
1. Test with various search terms
2. Test location-based search accuracy
3. Test performance with large datasets
4. Test search filters combinations

### **Social Features Testing:**
1. Test follow/unfollow flow
2. Test privacy controls
3. Test feed algorithm
4. Test post interactions

---

## 📊 **Success Metrics**

- [ ] All 5 storage buckets working correctly
- [ ] Post creation with images works on all platforms
- [ ] Global search returns relevant results
- [ ] Users can find and follow other dog owners
- [ ] Feed shows relevant content based on social connections
- [ ] Location-based discovery working
- [ ] Privacy controls respected

---

## 🔄 **Integration Points**

### **Existing Systems:**
- **Matches**: Include matched dogs in search results
- **Playdates**: Allow creating posts about playdates
- **Profile**: Link social posts to dog profiles
- **Messages**: Allow sharing posts in chat

### **Future Features:**
- Stories (Instagram-style temporary posts)
- Live location sharing
- Dog meetup events
- Social challenges/contests

---

This plan ensures we build a complete, Instagram-style social system that's perfectly integrated with the existing dog-focused architecture while maintaining privacy and security standards.
