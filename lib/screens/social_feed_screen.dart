import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/post.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/selected_image.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/comment_modal.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  List<Post> _posts = [];
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void didUpdateWidget(SocialFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh feed when widget updates (e.g., user returns from profile edit)
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Social Feed',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.add_box_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              onPressed: _showCreatePostDialog,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadFeed,
                child: _posts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          // Rebuild each post card to update timestamps
                          return _buildPostCard(context, post);
                        },
                      ),
              ),
      ), // Close GestureDetector
    );
  }

  Widget _buildPostCard(BuildContext context, Post post) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.userPhoto.isNotEmpty &&
                          !post.userPhoto.contains('placeholder')
                      ? NetworkImage(post.userPhoto)
                      : null,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  onBackgroundImageError: post.userPhoto.isNotEmpty &&
                          !post.userPhoto.contains('placeholder')
                      ? (exception, stackTrace) {
                          debugPrint('Error loading profile image: $exception');
                        }
                      : null,
                  child: post.userPhoto.isEmpty ||
                          post.userPhoto.contains('placeholder')
                      ? Icon(
                          Icons.person,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.dogName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      Text(
                        'with ${post.userName} • ${_formatPostTime(post.timestamp)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_horiz,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Post content
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                post.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),

          // Hashtags
          if (post.hashtags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: post.hashtags
                    .map((hashtag) => Text(
                          hashtag,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ))
                    .toList(),
              ),
            ),

          // Post image
          if (post.imageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 300,
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    child: Icon(
                      Icons.image,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),

          // Post actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildActionButton(
                      context,
                      icon:
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                      count: post.likes,
                      color: post.isLiked ? Colors.red : null,
                      onPressed: () => _toggleLike(post),
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      context,
                      icon: Icons.chat_bubble_outline,
                      count: post.comments,
                      onPressed: () => _showComments(post),
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      context,
                      icon: Icons.share_outlined,
                      count: post.shares,
                      onPressed: () => _sharePost(post),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required int count,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: color ??
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color ??
                        Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPostTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays >= 365) {
      final years = difference.inDays ~/ 365;
      return '${years}y';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  void _toggleLike(Post post) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index >= 0) {
        _posts[index] = post.copyWith(
          isLiked: !post.isLiked,
          likes: post.isLiked ? post.likes - 1 : post.likes + 1,
        );
      }
    });
  }

  void _showComments(Post post) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Transparent barrier
      builder: (context) => CommentModal(post: post),
    ).then((_) {
      // Reload feed when comment modal closes to update comment counts
      _loadFeed();
    });
  }

  void _sharePost(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Post shared! 📤'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCreatePostDialog() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Make the route transparent
        barrierColor: Colors.transparent, // Transparent barrier
        pageBuilder: (context, animation, secondaryAnimation) =>
            _CreatePostScreen(
          onPost: _handleCreatePost,
          isPosting: _isPosting,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  /// Handle post creation from new screen
  Future<void> _handleCreatePost(String content, SelectedImage? image) async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;

      // Upload image if selected
      if (image != null) {
        final postId = DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await PhotoUploadService.uploadPostImage(
          image: image,
          postId: postId,
          userId: userId,
        );
      }

      // Get user's dog for the post
      final userDogs = await BarkDateUserService.getUserDogs(userId);
      final dogId = userDogs.isNotEmpty ? userDogs.first['id'] : null;

      // Create post in database
      await BarkDateSocialService.createPost(
        userId: userId,
        content: content,
        dogId: dogId,
        imageUrls: imageUrl != null ? [imageUrl] : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        _loadFeed();
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load feed posts from Supabase
  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);

    try {
      // Load posts from Supabase
      final postsData = await BarkDateSocialService.getFeedPosts();

      // Convert to Post objects
      final posts = postsData.map((postData) {
        // Debug logging
        debugPrint('=== POST DEBUG ===');
        debugPrint('Post ID: ${postData['id']}');
        debugPrint('Post content: ${postData['content']}');
        debugPrint('User ID: ${postData['user_id']}');
        debugPrint('Dog ID: ${postData['dog_id']}');
        debugPrint('Full post data: ${postData.toString()}');
        debugPrint('Dog data: ${postData['dog']?.toString() ?? 'null'}');
        debugPrint('User data: ${postData['user']?.toString() ?? 'null'}');

        final dogPhoto = postData['dog']?['main_photo_url'];
        final userAvatar = postData['user']?['avatar_url'];
        final finalPhoto =
            dogPhoto ?? userAvatar ?? 'https://via.placeholder.com/150';

        debugPrint('Dog photo: $dogPhoto');
        debugPrint('User avatar: $userAvatar');
        debugPrint('Final photo: $finalPhoto');
        debugPrint('Dog name: ${postData['dog']?['name'] ?? 'null'}');
        debugPrint('=== END POST DEBUG ===');

        return Post(
          id: postData['id'] ?? '',
          userId: postData['user_id'] ?? '',
          userName: postData['user']?['name'] ?? 'Unknown User',
          userPhoto: finalPhoto,
          dogName: postData['dog']?['name'] ?? 'Unnamed Dog',
          content: postData['content'] ?? '',
          imageUrl: postData['image_urls']?.isNotEmpty == true
              ? postData['image_urls'][0]
              : null,
          timestamp: DateTime.tryParse(postData['created_at'] ?? '') ??
              DateTime.now().subtract(const Duration(
                  minutes: 5)), // Fallback to 5 minutes ago instead of "now"
          likes: postData['likes_count'] ?? 0,
          comments: postData['comments_count'] ?? 0,
          hashtags: _extractHashtags(postData['content'] ?? ''),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading feed: $e');
      if (mounted) {
        setState(() {
          _posts = List.from(SampleData.socialPosts); // Fallback to sample data
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed: $e')),
        );
      }
    }
  }

  /// Extract hashtags from post content
  List<String> _extractHashtags(String content) {
    final hashtagRegex = RegExp(r'#\w+');
    return hashtagRegex
        .allMatches(content)
        .map((match) => match.group(0)!)
        .toList();
  }

  /// Build empty state when no posts
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 80,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Posts Yet!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share your dog\'s adventure!\nTap the + button to create a post.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreatePostDialog,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Create First Post'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }
}

/// New full-screen create post screen with tabs
class _CreatePostScreen extends StatefulWidget {
  final Function(String content, SelectedImage? image) onPost;
  final bool isPosting;

  const _CreatePostScreen({
    required this.onPost,
    required this.isPosting,
  });

  @override
  State<_CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<_CreatePostScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  SelectedImage? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Start with Image tab (index 0)
    _tabController.index = 0;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await PhotoUploadService.pickImage();
    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  /// Get the current user's dog for display
  Future<List<Map<String, dynamic>>> _getUserDog() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return [];

      return await BarkDateUserService.getUserDogs(userId);
    } catch (e) {
      debugPrint('Error getting user dog: $e');
      return [];
    }
  }

  Future<void> _handlePost() async {
    if (_textController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content or a photo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.onPost(_textController.text.trim(), _selectedImage);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Error handling is done in the parent widget
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.8; // 80% of screen height

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color:
                Colors.transparent, // Transparent overlay to remove grey tint
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping modal content
                child: Container(
                  height: modalHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header with Cancel, Create Post, and Post button
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Row(
                          children: [
                            // Cancel button on left
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ),

                            // Create Post title in center
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Create Post',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                ),
                              ),
                            ),

                            // Post button on right
                            ElevatedButton(
                              onPressed: (_isLoading || widget.isPosting)
                                  ? null
                                  : _handlePost,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Post',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Subtle tab bar (like in the image)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            // Text tab
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _tabController.index = 1),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _tabController.index == 1
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Text',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: _tabController.index == 1
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ),
                            ),

                            // Image tab
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _tabController.index = 0),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _tabController.index == 0
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Image',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: _tabController.index == 0
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tab content
                      Expanded(
                        child: IndexedStack(
                          index: _tabController.index,
                          children: [
                            _buildImageTab(),
                            _buildTextTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User avatar and prompt (same as text tab)
            Row(
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getUserDog(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final dog = snapshot.data!.first;
                      final dogPhotoUrl = dog['main_photo_url'];
                      return CircleAvatar(
                        radius: 20,
                        backgroundImage: dogPhotoUrl != null &&
                                dogPhotoUrl.toString().isNotEmpty
                            ? NetworkImage(dogPhotoUrl)
                            : null,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        onBackgroundImageError: (exception, stackTrace) {
                          debugPrint('Error loading dog image: $exception');
                        },
                        child: dogPhotoUrl == null ||
                                dogPhotoUrl.toString().isEmpty
                            ? Icon(
                                Icons.pets,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                size: 20,
                              )
                            : null,
                      );
                    }
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.pets,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  "Share a photo of your adventure!",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Image picker area
            SizedBox(
              height: 180, // Reduced height to prevent overflow
              child: _selectedImage != null
                  ? _buildImagePreview()
                  : _buildImagePicker(),
            ),

            const SizedBox(height: 16),

            // Caption field (fixed height)
            Container(
              height: 120, // Fixed height instead of Expanded
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                decoration: InputDecoration(
                  hintText:
                      'Tap here to share something about your dog adventures...',
                  hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // User avatar and prompt (like in the image)
          Row(
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getUserDog(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final dog = snapshot.data!.first;
                    final dogPhotoUrl = dog['main_photo_url'];
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: dogPhotoUrl != null &&
                              dogPhotoUrl.toString().isNotEmpty
                          ? NetworkImage(dogPhotoUrl)
                          : null,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      onBackgroundImageError: (exception, stackTrace) {
                        debugPrint('Error loading dog image: $exception');
                      },
                      child:
                          dogPhotoUrl == null || dogPhotoUrl.toString().isEmpty
                              ? Icon(
                                  Icons.pets,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  size: 20,
                                )
                              : null,
                    );
                  }
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.pets,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Text(
                "What's on your mind?",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Text input area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                decoration: InputDecoration(
                  hintText:
                      'Tap here to share something about your dog adventures...',
                  hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to add an image',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Show off your dog\'s adventures!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _selectedImage!.bytes,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Remove button
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _removeImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Change photo button
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Change',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
