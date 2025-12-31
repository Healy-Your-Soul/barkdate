import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/post.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/selected_image.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/comment_modal.dart';
import 'package:barkdate/core/presentation/widgets/cute_empty_state.dart';
import 'package:barkdate/features/playdates/presentation/widgets/dog_search_sheet.dart';


class SocialFeedScreen extends StatefulWidget {
  final int initialTab;
  final bool openCreatePost;
  
  const SocialFeedScreen({
    super.key,
    this.initialTab = 0,
    this.openCreatePost = false,
  });

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> with SingleTickerProviderStateMixin {
  List<Post> _posts = [];
  final TextEditingController _postController = TextEditingController();
  SelectedImage? _selectedImage;
  bool _isPosting = false;
  bool _isLoading = false;
  
  // New: Track current user and their likes
  String? _currentUserId;
  Set<String> _likedPostIds = {};
  
  // New: Tab controller for "For You" / "Following"
  late TabController _tabController;
  int _selectedTab = 0; // 0 = For You, 1 = Following

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _selectedTab = _tabController.index);
      _loadFeed();
    });
    _currentUserId = SupabaseConfig.auth.currentUser?.id;
    _loadFeed();
    
    // Auto-open create post dialog if requested
    if (widget.openCreatePost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreatePostDialog();
      });
    }
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐕', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              'Sniff Around',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              size: 28,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: _showCreatePostDialog,
            tooltip: 'Create Post',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFeed,
              child: _posts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
    final isOwnPost = post.userId == _currentUserId;
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header - tappable to view dog profile
          InkWell(
            onTap: post.dogId != null ? () => _navigateToDogProfile(post.dogId!) : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
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
                            Icons.pets,
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
                        Row(
                          children: [
                            Text(
                              post.dogName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (post.dogId != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'with ${post.userName} • ${_formatPostTime(post.timestamp)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // More options menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePost(post);
                      } else if (value == 'report') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report feature coming soon')),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      if (isOwnPost)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Post', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      if (!isOwnPost)
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined),
                              SizedBox(width: 8),
                              Text('Report'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    child: Icon(
                      Icons.image,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          
          // Tagged dogs display (like Instagram - small text under image)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPostTags(post.id),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              if (tags.isEmpty) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    // Show all tagged dogs
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => _buildTaggedDogsSheet(tags),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.pets,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tags.length == 1
                            ? 'with ${tags.first['dog_name'] ?? 'a friend'}'
                            : 'with ${tags.first['dog_name'] ?? 'a friend'} and ${tags.length - 1} others',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Post actions - using bone emoji 🦴 instead of hearts
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Bone button (like) 🦴
                    _buildBoneButton(context, post),
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
  
  /// Build the bone "like" button using emoji
  Widget _buildBoneButton(BuildContext context, Post post) {
    final isLiked = _likedPostIds.contains(post.id);
    
    return GestureDetector(
      onTap: () => _toggleLike(post),
      child: Row(
        children: [
          Text(
            '🦴',
            style: TextStyle(
              fontSize: 22,
              color: isLiked ? null : Colors.grey,
            ),
          ),
          if (post.likes > 0) ...[
            const SizedBox(width: 4),
            Text(
              post.likes.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLiked 
                    ? Colors.amber[700] 
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
            color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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

  /// Toggle like on a post - now persists to database
  Future<void> _toggleLike(Post post) async {
    if (_currentUserId == null) return;
    
    final isCurrentlyLiked = _likedPostIds.contains(post.id);
    
    // Optimistic UI update
    setState(() {
      if (isCurrentlyLiked) {
        _likedPostIds.remove(post.id);
      } else {
        _likedPostIds.add(post.id);
      }
      
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index >= 0) {
        _posts[index] = post.copyWith(
          isLiked: !isCurrentlyLiked,
          likes: isCurrentlyLiked ? post.likes - 1 : post.likes + 1,
        );
      }
    });
    
    // Persist to database
    try {
      await BarkDateSocialService.togglePostLike(post.id, _currentUserId!);
    } catch (e) {
      debugPrint('Error toggling like: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          if (isCurrentlyLiked) {
            _likedPostIds.add(post.id);
          } else {
            _likedPostIds.remove(post.id);
          }
          
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index >= 0) {
            _posts[index] = post.copyWith(
              isLiked: isCurrentlyLiked,
              likes: isCurrentlyLiked ? post.likes + 1 : post.likes - 1,
            );
          }
        });
      }
    }
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
              isPosting: _isLoading,
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

  /// Pick image for post
  Future<void> _pickImage() async {
    final image = await PhotoUploadService.pickImage();
    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  /// Handle post creation from new screen
  Future<void> _handleCreatePost(String content, SelectedImage? image, List<Dog> taggedDogs) async {
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
      final postResult = await SupabaseConfig.client
          .from('posts')
          .insert({
            'user_id': userId,
            'dog_id': dogId,
            'content': content,
            'image_urls': imageUrl != null ? [imageUrl] : null,
          })
          .select()
          .single();
      
      final postId = postResult['id'] as String;

      // Save tags if any
      if (taggedDogs.isNotEmpty && dogId != null) {
        for (final taggedDog in taggedDogs) {
          try {
            await SupabaseConfig.client.from('post_tags').insert({
              'post_id': postId,
              'tagger_dog_id': dogId,
              'tagged_dog_id': taggedDog.id,
              'is_collaborator': false,
            });
          } catch (e) {
            debugPrint('Error tagging dog ${taggedDog.name}: $e');
            // Continue with other tags even if one fails
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(taggedDogs.isNotEmpty 
                ? 'Post created with ${taggedDogs.length} tags!' 
                : 'Post created successfully!'),
          ),
        );
        
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
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load feed posts from Supabase
  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    
    try {
      List<Map<String, dynamic>> postsData;
      
      // Load different feeds based on selected tab
      if (_selectedTab == 0) {
        // "For You" tab - all public posts
        postsData = await BarkDateSocialService.getFeedPosts();
      } else {
        // "Following" tab - posts from dog friends only
        if (_currentUserId == null) {
          postsData = [];
        } else {
          postsData = await BarkDateSocialService.getFollowingFeedPosts(
            userId: _currentUserId!,
          );
        }
      }
      
      // Load user's liked posts for UI state
      if (_currentUserId != null) {
        _likedPostIds = await BarkDateSocialService.getUserLikedPostIds(_currentUserId!);
      }
      
      // Convert to Post objects
      final posts = postsData.map((postData) {
        
        final dogPhoto = postData['dog']?['main_photo_url'];
        final userAvatar = postData['user']?['avatar_url'];
        final finalPhoto = dogPhoto ?? userAvatar ?? 'https://via.placeholder.com/150';
        final postId = postData['id'] ?? '';
        
        return Post(
          id: postId,
          userId: postData['user_id'] ?? '',
          userName: postData['user']?['name'] ?? 'Unknown User',
          userPhoto: finalPhoto,
          dogName: postData['dog']?['name'] ?? 'Unnamed Dog',
          dogId: postData['dog']?['id'],  // Include dogId for navigation
          content: postData['content'] ?? '',
          imageUrl: postData['image_urls']?.isNotEmpty == true 
              ? postData['image_urls'][0] 
              : null,
          timestamp: DateTime.tryParse(postData['created_at'] ?? '') ?? 
              DateTime.now().subtract(const Duration(minutes: 5)),
          likes: postData['likes_count'] ?? 0,
          comments: postData['comments_count'] ?? 0,
          hashtags: _extractHashtags(postData['content'] ?? ''),
          isLiked: _likedPostIds.contains(postId),
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
          _posts = List.from(SampleData.socialPosts);
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
  
  /// Navigate to dog profile
  Future<void> _navigateToDogProfile(String dogId) async {
    try {
      // Fetch dog data and navigate
      final dogData = await SupabaseConfig.client
          .from('dogs')
          .select('*, user:users(name, avatar_url)')
          .eq('id', dogId)
          .single();
      
      if (mounted) {
        final dog = Dog.fromJson(dogData);
        context.push('/dog/${dog.id}', extra: dog);
      }
    } catch (e) {
      debugPrint('Error navigating to dog profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load dog profile')),
        );
      }
    }
  }
  
  /// Delete a post
  Future<void> _deletePost(Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await BarkDateSocialService.deletePost(post.id);
        
        setState(() {
          _posts.removeWhere((p) => p.id == post.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting post: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    }
  }

  /// Build empty state when no posts
  Widget _buildEmptyState() {
    final isFollowingTab = _selectedTab == 1;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: CuteEmptyState(
          icon: isFollowingTab ? Icons.group : Icons.pets,
          title: isFollowingTab ? 'No Friend Posts Yet!' : 'No Posts Yet!',
          message: isFollowingTab 
              ? 'Once your dog makes friends, their posts will appear here! Start barking to connect.'
              : 'Be the first to share your dog\'s adventure! Tap the + button to create a post.',
          actionLabel: isFollowingTab ? 'Find Dogs to Follow' : 'Create First Post',
          onAction: isFollowingTab ? () => context.pop() : _showCreatePostDialog,
        ),
      ),
    );
  }

  /// Get approved tags for a post
  Future<List<Map<String, dynamic>>> _getPostTags(String postId) async {
    try {
      final result = await SupabaseConfig.client
          .from('post_tags')
          .select('''
            id,
            tagged_dog_id,
            is_collaborator,
            dogs!post_tags_tagged_dog_id_fkey(id, name, photos)
          ''')
          .eq('post_id', postId)
          .eq('status', 'approved');
      
      return (result as List).map((tag) {
        final dog = tag['dogs'] as Map<String, dynamic>?;
        return {
          'id': tag['id'],
          'dog_id': tag['tagged_dog_id'],
          'dog_name': dog?['name'] ?? 'Unknown',
          'dog_photo': (dog?['photos'] as List?)?.isNotEmpty == true 
              ? dog!['photos'][0] 
              : null,
          'is_collaborator': tag['is_collaborator'] ?? false,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching post tags: $e');
      return [];
    }
  }

  /// Build sheet showing all tagged dogs
  Widget _buildTaggedDogsSheet(List<Map<String, dynamic>> tags) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Tagged Dogs',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...tags.map((tag) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _navigateToDogProfile(tag['dog_id']);
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: tag['dog_photo'] != null 
                        ? NetworkImage(tag['dog_photo']) 
                        : null,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: tag['dog_photo'] == null 
                        ? const Icon(Icons.pets) 
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag['dog_name'],
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (tag['is_collaborator'] == true)
                          Text(
                            '✨ Contributor',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postController.dispose();
    super.dispose();
  }
}

/// New full-screen create post screen with tabs
class _CreatePostScreen extends StatefulWidget {
  final Function(String content, SelectedImage? image, List<Dog> taggedDogs) onPost;
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
  List<Dog> _taggedDogs = []; // Tagged dogs for this post (max 15)

  void _openTagSearch() async {
    final result = await showModalBottomSheet<List<Dog>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DogSearchSheet(
        excludedDogIds: _taggedDogs.map((d) => d.id).toList(),
      ),
    );
    
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        // Enforce max 15 tags
        final remaining = 15 - _taggedDogs.length;
        _taggedDogs.addAll(result.take(remaining));
      });
    }
  }

  void _removeTag(Dog dog) {
    setState(() {
      _taggedDogs.removeWhere((d) => d.id == dog.id);
    });
  }

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

  Future<void> _handlePost() async {
    if (_textController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content or a photo')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await widget.onPost(_textController.text.trim(), _selectedImage, _taggedDogs);
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
            color: Colors.transparent, // Transparent overlay to remove grey tint
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          
                          // Create Post title in center
                          Expanded(
                            child: Center(
                              child: Text(
                                'Create Post',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          
                          // Post button on right
                          ElevatedButton(
                            onPressed: (_isLoading || widget.isPosting) ? null : _handlePost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                              onTap: () => setState(() => _tabController.index = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _tabController.index == 1 
                                          ? Theme.of(context).colorScheme.primary 
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Text',
                                    style: TextStyle(
                                      color: _tabController.index == 1 
                                          ? Theme.of(context).colorScheme.primary 
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Image tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _tabController.index = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _tabController.index == 0 
                                          ? Theme.of(context).colorScheme.primary 
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Photo',
                                    style: TextStyle(
                                      color: _tabController.index == 0 
                                          ? Theme.of(context).colorScheme.primary 
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      fontWeight: FontWeight.w600,
                                    ),
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
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(), // Disable swipe to change tabs
                        children: [
                          // Photo Tab Content
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                // Image picker area
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    height: 250,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: _selectedImage != null
                                        ? Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: Image.memory(
                                                  _selectedImage!.bytes,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: GestureDetector(
                                                  onTap: _removeImage,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.5),
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
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_photo_alternate_outlined,
                                                size: 48,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Add a photo',
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Caption input
                                TextField(
                                  controller: _textController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Write a caption...',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Tag Dogs Section
                                _buildTagDogsSection(),
                              ],
                            ),
                          ),

                          // Text Tab Content
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _textController,
                                  maxLines: 8,
                                  autofocus: true,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 18,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'What\'s on your dog\'s mind?',
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                      fontSize: 18,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Tag Dogs Section
                                _buildTagDogsSection(),
                              ],
                            ),
                          ),
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

  /// Build the Tag Dogs section with button and avatar chips
  Widget _buildTagDogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag Dogs button
        GestureDetector(
          onTap: _taggedDogs.length < 15 ? _openTagSearch : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pets,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _taggedDogs.isEmpty 
                      ? 'Tag dogs...' 
                      : 'Tag more dogs (${_taggedDogs.length}/15)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.add,
                  size: 18,
                  color: _taggedDogs.length < 15 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        // Show tagged dogs as small chips
        if (_taggedDogs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _taggedDogs.map((dog) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: dog.photos.isNotEmpty 
                          ? NetworkImage(dog.photos.first) 
                          : null,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: dog.photos.isEmpty 
                          ? const Icon(Icons.pets, size: 12) 
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dog.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeTag(dog),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
