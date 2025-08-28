import 'package:flutter/material.dart';
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
  SelectedImage? _selectedImage;
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
    return Scaffold(
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
                  backgroundImage: post.userPhoto.isNotEmpty && !post.userPhoto.contains('placeholder')
                      ? NetworkImage(post.userPhoto)
                      : null,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  onBackgroundImageError: post.userPhoto.isNotEmpty && !post.userPhoto.contains('placeholder')
                      ? (exception, stackTrace) {
                          debugPrint('Error loading profile image: $exception');
                        }
                      : null,
                  child: post.userPhoto.isEmpty || post.userPhoto.contains('placeholder')
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'with ${post.userName} • ${_formatPostTime(post.timestamp)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_horiz,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                children: post.hashtags.map((hashtag) => Text(
                  hashtag,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                )).toList(),
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
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                      icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
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
            color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Post',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _postController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share something about your dog adventures...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
              ),
              
              // Show selected image preview
              if (_selectedImage != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _selectedImage!.bytes,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo),
                      label: Text(_selectedImage != null ? 'Change Photo' : 'Add Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isPosting ? null : _createPost,
                      child: _isPosting 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Post'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick image for post
  Future<void> _pickImage() async {
    final image = await PhotoUploadService.pickImage();
    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  /// Create and upload post
  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content or a photo')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;
      
      // Upload image if selected
      if (_selectedImage != null) {
        final postId = DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await PhotoUploadService.uploadPostImage(
          image: _selectedImage!,
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
        content: _postController.text.trim(),
        dogId: dogId,
        imageUrls: imageUrl != null ? [imageUrl] : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        
        // Clear form
        _postController.clear();
        setState(() {
          _selectedImage = null;
        });
        
        // Reload feed to show new post
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
        setState(() => _isPosting = false);
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
        debugPrint('Post data: ${postData.toString()}');
        debugPrint('Dog data: ${postData['dog']?.toString() ?? 'null'}');
        debugPrint('User data: ${postData['user']?.toString() ?? 'null'}');
        
        final dogPhoto = postData['dog']?['main_photo_url'];
        final userAvatar = postData['user']?['avatar_url'];
        final finalPhoto = userAvatar ?? 'https://via.placeholder.com/150';
        
        debugPrint('Dog photo: $dogPhoto');
        debugPrint('User avatar: $userAvatar');
        debugPrint('Final photo: $finalPhoto');
        
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
          timestamp: DateTime.tryParse(postData['created_at'] ?? '') ?? DateTime.now(),
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
    return hashtagRegex.allMatches(content)
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreatePostDialog,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Create First Post'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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