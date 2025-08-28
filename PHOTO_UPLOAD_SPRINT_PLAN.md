# Photo Upload System - Complete Implementation Sprint 📸

*Comprehensive plan for photo uploads across the entire BarkDate app*

## 🎯 **Sprint Overview**

**Goal**: Implement a complete photo upload system that allows users to upload, store, and manage photos across all app features - profiles, posts, chats, playdates, and multi-image galleries.

**Duration**: 2-3 weeks (depending on complexity)

**Key Features**:
- User profile photos & dog galleries (Tinder-style scrolling)
- Social feed post images  
- Chat photo sharing
- Playdate memory albums
- Secure user-specific storage structure
- Image optimization & compression

---

## 🗄️ **Backend Architecture Changes**

### **1. Supabase Storage Structure**

#### **Current Issues to Fix:**
- ❌ Storage buckets don't exist
- ❌ RLS (Row Level Security) policies missing
- ❌ Bucket permissions not configured

#### **New Storage Bucket Architecture:**
```
Supabase Storage Buckets:
├── user-avatars/          (Public bucket)
│   └── {user_id}/
│       └── avatar.jpg
│
├── dog-photos/            (Public bucket) 
│   └── {user_id}/
│       └── {dog_id}/
│           ├── photo_1.jpg
│           ├── photo_2.jpg
│           └── photo_n.jpg
│
├── post-images/          (Public bucket)
│   └── {user_id}/
│       └── posts/
│           ├── {post_id}_1.jpg
│           └── {post_id}_2.jpg
│
├── chat-media/           (Private bucket)
│   └── {match_id}/
│       ├── {user_id}/
│       │   ├── {message_id}.jpg
│       │   └── {message_id}.mp4
│       └── {other_user_id}/
│
└── playdate-albums/      (Semi-private bucket)
    └── {playdate_id}/
        ├── {user_id}/
        │   ├── memory_1.jpg
        │   └── memory_2.jpg
        └── organizer_photos/
```

#### **Database Schema Updates:**

**Add to existing tables:**
```sql
-- Add photo_order to dogs table for gallery ordering
ALTER TABLE dogs ADD COLUMN photo_order jsonb DEFAULT '[]';

-- Add image_metadata to posts table
ALTER TABLE posts ADD COLUMN image_metadata jsonb DEFAULT '[]';

-- Update messages table for media support
ALTER TABLE messages ADD COLUMN media_url text;
ALTER TABLE messages ADD COLUMN media_type text CHECK (media_type IN ('image', 'video'));
ALTER TABLE messages ADD COLUMN thumbnail_url text;

-- Add playdate_photos table for memory albums
CREATE TABLE playdate_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  photo_url text NOT NULL,
  caption text,
  photo_order integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(playdate_id, user_id, photo_order)
);

-- Add indexes for performance
CREATE INDEX idx_playdate_photos_playdate_id ON playdate_photos(playdate_id);
CREATE INDEX idx_playdate_photos_user_id ON playdate_photos(user_id);
```

#### **RLS Security Policies:**
```sql
-- User avatars: Users can manage their own avatars
CREATE POLICY "Users can upload their own avatars"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'user-avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Dog photos: Users can manage their own dogs' photos  
CREATE POLICY "Users can upload their dogs photos"
ON storage.objects FOR INSERT  
WITH CHECK (bucket_id = 'dog-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Post images: Users can upload to their own posts
CREATE POLICY "Users can upload post images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'post-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Chat media: Only matched users can upload to their conversations
CREATE POLICY "Users can upload to their chats"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'chat-media' AND 
  EXISTS (
    SELECT 1 FROM matches m 
    WHERE m.id::text = (storage.foldername(name))[1]
    AND (m.user_id = auth.uid() OR m.target_user_id = auth.uid())
  ));

-- Playdate albums: Participants can upload memories
CREATE POLICY "Participants can upload playdate photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'playdate-albums' AND
  EXISTS (
    SELECT 1 FROM playdate_participants pp
    WHERE pp.playdate_id::text = (storage.foldername(name))[1]
    AND pp.user_id = auth.uid()
  ));
```

---

## 🛠️ **Frontend Implementation Tasks**

### **Sprint 1: Core Photo Upload Service (Week 1)**

#### **Task 1.1: Enhanced PhotoUploadService**
**File**: `lib/services/photo_upload_service.dart`

**Requirements:**
- ✅ Fix bucket creation with proper RLS
- 🆕 Add image compression/optimization
- 🆕 Add multi-image upload support
- 🆕 Add progress tracking
- 🆕 Add error handling & retry logic
- 🆕 Add different upload paths for different features

**New Methods Needed:**
```dart
class PhotoUploadService {
  // Enhanced single upload with compression
  static Future<String?> uploadImage({
    required File imageFile,
    required String bucketName, 
    required String filePath,
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
    Function(double)? onProgress,
  });

  // Multi-image upload for galleries
  static Future<List<String>> uploadMultipleImages({
    required List<File> imageFiles,
    required String bucketName,
    required String baseFilePath,
    Function(int current, int total)? onProgress,
  });

  // Specific upload methods
  static Future<String?> uploadUserAvatar({required File imageFile, required String userId});
  static Future<List<String>> uploadDogPhotos({required List<File> imageFiles, required String dogId, required String userId});
  static Future<String?> uploadPostImage({required File imageFile, required String postId, required String userId});
  static Future<String?> uploadChatMedia({required File mediaFile, required String matchId, required String messageId, required String userId});
  static Future<String?> uploadPlaydatePhoto({required File imageFile, required String playdateId, required String userId, String? caption});

  // Gallery management
  static Future<void> reorderDogPhotos({required String dogId, required List<String> photoUrls});
  static Future<void> deleteDogPhoto({required String dogId, required String photoUrl});
}
```

#### **Task 1.2: Image Picker Enhancement**
**File**: `lib/widgets/enhanced_image_picker.dart` (NEW)

**Features:**
- 🆕 Multi-image selection
- 🆕 Camera vs Gallery options
- 🆕 Image preview before upload
- 🆕 Crop/edit functionality
- 🆕 Progress indicators

```dart
class EnhancedImagePicker extends StatefulWidget {
  final bool allowMultiple;
  final int maxImages;
  final Function(List<File>) onImagesSelected;
  final Widget? placeholder;
}
```

#### **Task 1.3: Photo Gallery Widget**
**File**: `lib/widgets/photo_gallery.dart` (NEW)

**Features:**
- 🆕 Tinder-style swipe navigation
- 🆕 Thumbnail grid view
- 🆕 Full-screen photo viewer
- 🆕 Zoom & pan support
- 🆕 Delete/reorder functionality

```dart
class PhotoGallery extends StatefulWidget {
  final List<String> photoUrls;
  final bool isEditable;
  final Function(List<String>)? onReorder;
  final Function(String)? onDelete;
  final Widget? emptyState;
}
```

---

### **Sprint 2: Profile & Dog Photo Integration (Week 2)**

#### **Task 2.1: User Avatar Upload**
**Files**: 
- `lib/screens/profile_screen.dart`
- `lib/screens/onboarding/create_profile_screen.dart`

**Changes:**
- ✅ Re-enable avatar upload in profile creation
- 🆕 Add "Change Avatar" button in ProfileScreen
- 🆕 Show upload progress
- 🆕 Handle upload errors gracefully

#### **Task 2.2: Dog Photo Gallery**
**Files**:
- `lib/screens/onboarding/create_profile_screen.dart`
- `lib/screens/dog_profile_detail.dart`
- `lib/widgets/dog_card.dart`

**Features:**
- 🆕 **Multi-photo upload** during dog profile creation
- 🆕 **Tinder-style swipe** in dog detail view
- 🆕 **Photo thumbnails** in dog cards
- 🆕 **Reorder photos** in edit mode
- 🆕 **Add/delete photos** after creation

**UI Flow:**
```
Dog Profile Creation:
1. Name, breed, etc. (existing)
2. Photo Upload Section:
   ├── "Add Photos" button
   ├── Thumbnail preview grid
   ├── Drag to reorder
   └── Upload progress bars

Dog Detail View:
1. Full-screen photo gallery
2. Swipe left/right navigation  
3. Photo counter (1/5)
4. Thumbnail strip at bottom
```

#### **Task 2.3: Feed Integration**
**Files**:
- `lib/screens/feed_screen.dart`
- `lib/widgets/dog_card.dart`

**Changes:**
- 🆕 Show first photo as card thumbnail
- 🆕 Add photo count indicator (📷 5)
- 🆕 Smooth transitions to detail view

---

### **Sprint 3: Social Features (Week 3)**

#### **Task 3.1: Post Image Upload**
**Files**:
- `lib/screens/social_feed_screen.dart`
- `lib/widgets/create_post_modal.dart` (NEW)

**Features:**
- 🆕 **Create Post** floating action button
- 🆕 **Multi-image post** support (up to 10 images)
- 🆕 **Image carousel** in post display
- 🆕 **Image captions** and tagging

#### **Task 3.2: Chat Media Sharing**
**Files**:
- `lib/screens/chat_detail_screen.dart`
- `lib/widgets/chat_media_message.dart` (NEW)

**Features:**
- 🆕 **Photo sharing** button in chat
- 🆕 **Media message bubbles** with thumbnails
- 🆕 **Full-screen image viewer** on tap
- 🆕 **Download/save** functionality

#### **Task 3.3: Playdate Memory Albums**
**Files**:
- `lib/screens/playdates_screen.dart`
- `lib/screens/playdate_album_screen.dart` (NEW)
- `lib/screens/playdate_recap_screen.dart`

**Features:**
- 🆕 **"Add Photos"** button in completed playdates
- 🆕 **Memory album** view with all participants' photos
- 🆕 **Photo upload** during recap submission
- 🆕 **Shared album** visible to all playdate participants

---

## 📱 **Screen-Specific Implementation Details**

### **1. Enhanced Create Profile Screen**

**New Photo Section UI:**
```dart
// In _buildOwnerStep()
Widget _buildAvatarUpload() {
  return Column(
    children: [
      GestureDetector(
        onTap: _selectAvatar,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _avatarFile != null 
                ? FileImage(_avatarFile!)
                : null,
              child: _avatarFile == null 
                ? Icon(Icons.add_a_photo, size: 30)
                : null,
            ),
            if (_avatarUploading)
              CircularProgressIndicator(),
          ],
        ),
      ),
      Text('Tap to add profile photo'),
    ],
  );
}

// In _buildDogStep() 
Widget _buildDogPhotoGallery() {
  return Column(
    children: [
      if (_dogPhotos.isNotEmpty)
        SizedBox(
          height: 100,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _dogPhotos.length,
            itemBuilder: (context, index) {
              return DogPhotoThumbnail(
                key: ValueKey(_dogPhotos[index]),
                imageFile: _dogPhotos[index],
                onDelete: () => _removeDogPhoto(index),
              );
            },
            onReorder: _reorderDogPhotos,
          ),
        ),
      ElevatedButton.icon(
        onPressed: _addDogPhotos,
        icon: Icon(Icons.add_photo_alternate),
        label: Text('Add Photos (${_dogPhotos.length}/10)'),
      ),
    ],
  );
}
```

### **2. Enhanced Dog Profile Detail**

**Tinder-Style Photo Gallery:**
```dart
class DogProfileDetail extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen photo gallery
          PageView.builder(
            controller: _pageController,
            itemCount: widget.dog.photoUrls.length,
            onPageChanged: (index) {
              setState(() => _currentPhotoIndex = index);
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Image.network(
                  widget.dog.photoUrls[index],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          
          // Photo counter overlay
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentPhotoIndex + 1}/${widget.dog.photoUrls.length}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          
          // Thumbnail strip at bottom
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.dog.photoUrls.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _jumpToPhoto(index),
                    child: Container(
                      width: 60,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: index == _currentPhotoIndex 
                            ? Colors.white 
                            : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          widget.dog.photoUrls[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### **3. Enhanced Chat Detail Screen**

**Media Message Support:**
```dart
// Add to chat input area
Widget _buildChatInput() {
  return Container(
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        // Media button
        IconButton(
          onPressed: _showMediaOptions,
          icon: Icon(Icons.add_circle_outline),
        ),
        
        // Text input
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        
        // Send button
        IconButton(
          onPressed: _sendMessage,
          icon: Icon(Icons.send),
        ),
      ],
    ),
  );
}

// Media options bottom sheet
void _showMediaOptions() {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera),
              title: Text('Take Photo'),
              onTap: () => _pickMedia(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () => _pickMedia(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
}
```

---

## 🔧 **Technical Implementation Details**

### **Image Optimization Strategy:**
```dart
class ImageOptimizer {
  static Future<File> compressImage(File imageFile, {
    int maxWidth = 1080,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    // Use flutter_image_compress
    final compressedImage = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
    );
    
    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await compressedFile.writeAsBytes(compressedImage!);
    
    return compressedFile;
  }
}
```

### **Progress Tracking:**
```dart
class UploadProgress {
  final int current;
  final int total;
  final double percentage;
  final String? currentFileName;
  
  UploadProgress({
    required this.current,
    required this.total,
    required this.percentage,
    this.currentFileName,
  });
}
```

---

## 📦 **Required Dependencies**

Add to `pubspec.yaml`:
```yaml
dependencies:
  image_picker: ^1.0.7              # Already added
  flutter_image_compress: ^2.1.0    # NEW - Image compression
  photo_view: ^0.14.0               # NEW - Full-screen image viewer
  reorderables: ^0.6.0              # NEW - Drag to reorder
  cached_network_image: ^3.3.1      # NEW - Image caching
  path_provider: ^2.1.1             # NEW - File paths
```

---

## ✅ **Success Criteria**

### **Sprint 1 Success:**
- [ ] Storage buckets created with proper RLS
- [ ] PhotoUploadService working with compression
- [ ] Multi-image picker widget functional
- [ ] Photo gallery widget with Tinder-style navigation

### **Sprint 2 Success:**
- [ ] User avatars uploading and displaying
- [ ] Dog photos: multi-upload, reorder, Tinder-style viewing
- [ ] Profile screens integrated with photo system
- [ ] Feed showing dog thumbnails correctly

### **Sprint 3 Success:**
- [ ] Social posts with image carousels
- [ ] Chat media sharing functional
- [ ] Playdate memory albums working
- [ ] All photo features user-specific and secure

---

## 🧪 **Testing Strategy**

### **Manual Testing Checklist:**
1. **Profile Photos:**
   - [ ] Upload avatar during signup
   - [ ] Change avatar from profile screen
   - [ ] Upload multiple dog photos
   - [ ] Reorder dog photos
   - [ ] View dog gallery in Tinder style

2. **Social Features:**
   - [ ] Create post with multiple images
   - [ ] Share photo in chat
   - [ ] View full-screen images
   - [ ] Upload playdate memories

3. **Error Scenarios:**
   - [ ] Network failure during upload
   - [ ] Invalid file formats
   - [ ] Large file sizes
   - [ ] Storage quota exceeded

### **Performance Testing:**
- [ ] Upload speed with compression
- [ ] Memory usage during multi-upload
- [ ] Image loading performance
- [ ] Cache effectiveness

---

## 🚨 **Risk Mitigation**

### **Potential Issues:**
1. **Storage Costs**: Implement image compression and size limits
2. **Upload Failures**: Add retry logic and progress saving
3. **User Experience**: Show clear progress and error messages
4. **Security**: Ensure RLS policies are correctly configured
5. **Performance**: Use image caching and lazy loading

### **Backup Plans:**
- Start with single-image uploads, expand to multi-image
- Implement progressive enhancement (graceful degradation)
- Use local storage as fallback during development

---

*This sprint plan ensures a complete, production-ready photo system across the entire BarkDate app with proper security, performance, and user experience.*
