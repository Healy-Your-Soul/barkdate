import 'package:flutter/material.dart';
import 'package:barkdate/widgets/dog_loading_widget.dart';
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
import 'package:barkdate/services/notification_manager.dart';

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

class _SocialFeedScreenState extends State<SocialFeedScreen>
    with SingleTickerProviderStateMixin {
  List<Post> _posts = [];
  final TextEditingController _postController = TextEditingController();
  SelectedImage? _selectedImage;
  final bool _isPosting = false;
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
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Sniff Around',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.grey[800], size: 26),
            onPressed: _showCreatePostDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter chips row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('For You', 0),
                  const SizedBox(width: 8),
                  _buildFilterChip('Following', 1),
                  const SizedBox(width: 8),
                  _buildFilterChip('Puppies', 2),
                  const SizedBox(width: 8),
                  _buildFilterChip('Adventures', 3),
                ],
              ),
            ),
          ),

          // Grid content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: DogLoadingWidget(message: 'Sniffing for posts...'))
                : RefreshIndicator(
                    onRefresh: _loadFeed,
                    child: _posts.isEmpty
                        ? _buildEmptyState()
                        : _buildPinterestGrid(),
                  ),
          ),
        ],
      ),
      // Floating Paw FAB
      floatingActionButton: _PawFloatingButton(
        onPhotoPressed: () => _showCreatePostDialog(photoMode: true),
        onTextPressed: () => _showCreatePostDialog(photoMode: false),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
        _loadFeed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Pinterest-style staggered grid
  Widget _buildPinterestGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (crossAxisCount + 1))) /
                crossAxisCount;

        // Split posts into columns
        List<List<Post>> columns = List.generate(crossAxisCount, (_) => []);
        for (int i = 0; i < _posts.length; i++) {
          columns[i % crossAxisCount].add(_posts[i]);
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(spacing),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columns.map((columnPosts) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                  child: Column(
                    children: columnPosts
                        .map((post) => _buildGridPostCard(post, itemWidth))
                        .toList(),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// Modern grid card for Pinterest layout
  Widget _buildGridPostCard(Post post, double width) {
    // Vary heights for Pinterest effect
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openExpandedPost(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (hasImage)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dog avatar + name
                  GestureDetector(
                    onTap: post.dogId != null
                        ? () => _navigateToDogProfile(post.dogId!)
                        : null,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: post.userPhoto.isNotEmpty &&
                                  !post.userPhoto.contains('placeholder')
                              ? NetworkImage(post.userPhoto)
                              : null,
                          child: post.userPhoto.isEmpty ||
                                  post.userPhoto.contains('placeholder')
                              ? Icon(Icons.pets,
                                  size: 14, color: Colors.grey[500])
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.dogName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Caption
                  if (post.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      post.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],

                  // Stats row
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.pets, size: 14, color: Colors.orange[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${post.comments}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(post.timestamp),
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Open expanded view of a post
  void _openExpandedPost(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExpandedPostWithComments(
        post: post,
        currentUserId: _currentUserId,
        likedPostIds: _likedPostIds,
        onLikeToggle: () => _toggleLike(post),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
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
            onTap: post.dogId != null
                ? () => _navigateToDogProfile(post.dogId!)
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
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
                            debugPrint(
                                'Error loading profile image: $exception');
                          }
                        : null,
                    child: post.userPhoto.isEmpty ||
                            post.userPhoto.contains('placeholder')
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            if (post.dogId != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'with ${post.userName} • ${_formatPostTime(post.timestamp)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // More options menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePost(post);
                      } else if (value == 'report') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Report feature coming soon')),
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
                              Text('Delete Post',
                                  style: TextStyle(color: Colors.red)),
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

          // Tagged dogs display (like Instagram - small text under image)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPostTags(post.id),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              if (tags.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tags.length == 1
                            ? 'with ${tags.first['dog_name'] ?? 'a friend'}'
                            : 'with ${tags.first['dog_name'] ?? 'a friend'} and ${tags.length - 1} others',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
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
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
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

  void _showCreatePostDialog({bool? photoMode}) {
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
  Future<void> _handleCreatePost(
      String content, SelectedImage? image, List<Dog> taggedDogs) async {
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
        // Fetch tagging dog name for notification
        final taggerDogName = userDogs.first['name'] ?? 'A friend';

        for (final taggedDog in taggedDogs) {
          try {
            await SupabaseConfig.client.from('post_tags').insert({
              'post_id': postId,
              'tagger_dog_id': dogId,
              'tagged_dog_id': taggedDog.id,
              'is_collaborator': false,
            });

            // Send notification to tagged dog's owner
            // We need the owner ID. If it's not in the Dog object, we might miss it.
            // Dog search usually includes ownerId.
            if (taggedDog.ownerId.isNotEmpty && taggedDog.ownerId != userId) {
              await NotificationManager.sendPostTagNotification(
                receiverUserId: taggedDog.ownerId,
                taggerDogName: taggerDogName,
                postId: postId,
              );
            }
          } catch (e) {
            debugPrint('Error tagging/notifying dog ${taggedDog.name}: $e');
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
        _likedPostIds =
            await BarkDateSocialService.getUserLikedPostIds(_currentUserId!);
      }

      // Convert to Post objects
      final posts = postsData.map((postData) {
        final dogPhoto = postData['dog']?['main_photo_url'];
        final userAvatar = postData['user']?['avatar_url'];
        final finalPhoto =
            dogPhoto ?? userAvatar ?? 'https://via.placeholder.com/150';
        final postId = postData['id'] ?? '';

        return Post(
          id: postId,
          userId: postData['user_id'] ?? '',
          userName: postData['user']?['name'] ?? 'Unknown User',
          userPhoto: finalPhoto,
          dogName: postData['dog']?['name'] ?? 'Unnamed Dog',
          dogId: postData['dog']?['id'], // Include dogId for navigation
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
    return hashtagRegex
        .allMatches(content)
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
          actionLabel:
              isFollowingTab ? 'Find Dogs to Follow' : 'Create First Post',
          onAction:
              isFollowingTab ? () => context.pop() : _showCreatePostDialog,
        ),
      ),
    );
  }

  /// Get approved tags for a post
  Future<List<Map<String, dynamic>>> _getPostTags(String postId) async {
    try {
      final result = await SupabaseConfig.client.from('post_tags').select('''
            id,
            tagged_dog_id,
            is_collaborator,
            dogs!post_tags_tagged_dog_id_fkey(id, name, photos)
          ''').eq('post_id', postId).eq('status', 'approved');

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
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (tag['is_collaborator'] == true)
                              Text(
                                '✨ Contributor',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
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
  final Function(String content, SelectedImage? image, List<Dog> taggedDogs)
      onPost;
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
  final List<Dog> _taggedDogs = []; // Tagged dogs for this post (max 15)

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
      await widget.onPost(
          _textController.text.trim(), _selectedImage, _taggedDogs);
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
                      // Safe area padding for status bar when modal is near top
                      SizedBox(
                          height: MediaQuery.of(context).viewPadding.top > 0
                              ? MediaQuery.of(context).viewPadding.top * 0.5
                              : 0),
                      // Header with Cancel, Create Post, and Post button
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
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
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                  child: Center(
                                    child: Text(
                                      'Text',
                                      style: TextStyle(
                                        color: _tabController.index == 1
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
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
                                onTap: () =>
                                    setState(() => _tabController.index = 0),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                  child: Center(
                                    child: Text(
                                      'Photo',
                                      style: TextStyle(
                                        color: _tabController.index == 0
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
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
                          physics:
                              const NeverScrollableScrollPhysics(), // Disable swipe to change tabs
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: _selectedImage != null
                                          ? Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
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
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.5),
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .add_photo_alternate_outlined,
                                                  size: 48,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Add a photo',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          fontSize: 18,
                                        ),
                                    decoration: InputDecoration(
                                      hintText: 'What\'s on your dog\'s mind?',
                                      hintStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
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
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
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
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
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

/// Expandable Paw Floating Action Button
class _PawFloatingButton extends StatefulWidget {
  final VoidCallback onPhotoPressed;
  final VoidCallback onTextPressed;

  const _PawFloatingButton({
    required this.onPhotoPressed,
    required this.onTextPressed,
  });

  @override
  State<_PawFloatingButton> createState() => _PawFloatingButtonState();
}

class _PawFloatingButtonState extends State<_PawFloatingButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded options
        ScaleTransition(
          scale: _expandAnimation,
          alignment: Alignment.bottomRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Photo option
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text('Photo',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'photo_fab',
                      backgroundColor: Colors.orange[400],
                      onPressed: () {
                        _toggle();
                        widget.onPhotoPressed();
                      },
                      child: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Text option
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text('Text',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'text_fab',
                      backgroundColor: Colors.orange[300],
                      onPressed: () {
                        _toggle();
                        widget.onTextPressed();
                      },
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Main Paw FAB
        FloatingActionButton(
          heroTag: 'paw_fab',
          backgroundColor: Theme.of(context).colorScheme.primary,
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.pets, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

/// Expanded post view with inline comments
class _ExpandedPostWithComments extends StatefulWidget {
  final Post post;
  final String? currentUserId;
  final Set<String> likedPostIds;
  final VoidCallback onLikeToggle;

  const _ExpandedPostWithComments({
    required this.post,
    this.currentUserId,
    required this.likedPostIds,
    required this.onLikeToggle,
  });

  @override
  State<_ExpandedPostWithComments> createState() =>
      _ExpandedPostWithCommentsState();
}

class _ExpandedPostWithCommentsState extends State<_ExpandedPostWithComments> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments =
          await BarkDateSocialService.getPostComments(widget.post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPostingComment) return;

    setState(() => _isPostingComment = true);

    try {
      final userId = widget.currentUserId;
      if (userId == null) throw Exception('Not logged in');
      await BarkDateSocialService.addComment(
        postId: widget.post.id,
        userId: userId,
        content: text,
      );
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isLiked = widget.likedPostIds.contains(post.id);

    return GestureDetector(
      onTap: () => Navigator.pop(context), // Tap outside to dismiss
      child: Container(
        color: Colors.transparent, // Catch taps on transparent area
        child: GestureDetector(
          onTap: () {}, // Prevent taps on content from dismissing
          child: DraggableScrollableSheet(
            initialChildSize: 0.95,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle - make it tappable to dismiss too
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Post header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: post.dogId != null
                                      ? () => _navigateToDogProfile(post.dogId!)
                                      : null,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage:
                                            post.userPhoto.isNotEmpty
                                                ? NetworkImage(post.userPhoto)
                                                : null,
                                        child: post.userPhoto.isEmpty
                                            ? Icon(Icons.pets,
                                                color: Colors.grey[500])
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.dogName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'with ${post.userName}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      color: Colors.grey[600]),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),

                          // Post image
                          if (post.imageUrl != null &&
                              post.imageUrl!.isNotEmpty)
                            Image.network(
                              post.imageUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: Icon(Icons.image,
                                    size: 48, color: Colors.grey[400]),
                              ),
                            ),

                          // Action buttons with paw icon
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Paw like button
                                GestureDetector(
                                  onTap: widget.onLikeToggle,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.pets,
                                        size: 24,
                                        color: isLiked
                                            ? Colors.orange
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${post.likes}',
                                        style: TextStyle(
                                          color: isLiked
                                              ? Colors.orange
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Comment count
                                Row(
                                  children: [
                                    Icon(Icons.chat_bubble_outline,
                                        size: 22, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_comments.length}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Icon(Icons.share_outlined,
                                    size: 22, color: Colors.grey[600]),
                              ],
                            ),
                          ),

                          // Caption
                          if (post.content.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                      height: 1.4),
                                  children: [
                                    TextSpan(
                                      text: '${post.dogName} ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(text: post.content),
                                  ],
                                ),
                              ),
                            ),

                          const Divider(height: 32),

                          // Comments section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Comments',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Comments list
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                  child: DogLoadingWidget(
                                      message: 'Loading comments...')),
                            )
                          else if (_comments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'No comments yet. Be the first!',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                return _buildCommentTile(comment);
                              },
                            ),

                          const SizedBox(height: 80), // Space for input
                        ],
                      ),
                    ),
                  ),

                  // Comment input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isPostingComment ? null : _postComment,
                            icon: _isPostingComment
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: DogCircularProgress(
                                        size: 20, strokeWidth: 2),
                                  )
                                : Icon(Icons.send,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    // Extract dog data from nested object
    final dogData = comment['dog'] as Map<String, dynamic>?;
    final userData = comment['user'] as Map<String, dynamic>?;
    final dogName = dogData?['name'] as String? ??
        userData?['name'] as String? ??
        'Unknown';
    final text =
        comment['text'] as String? ?? comment['content'] as String? ?? '';
    final createdAt = comment['created_at'] as String?;
    final dogPhoto = dogData?['main_photo_url'] as String? ??
        userData?['avatar_url'] as String?;
    final dogId = dogData?['id'] as String?; // Extract dog ID

    String timeAgo = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m';
        } else if (diff.inHours < 24)
          timeAgo = '${diff.inHours}h';
        else
          timeAgo = '${diff.inDays}d';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: dogId != null ? () => _navigateToDogProfile(dogId) : null,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[200],
              backgroundImage: dogPhoto != null ? NetworkImage(dogPhoto) : null,
              child: dogPhoto == null
                  ? Icon(Icons.pets, size: 14, color: Colors.grey[500])
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap:
                      dogId != null ? () => _navigateToDogProfile(dogId) : null,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                      children: [
                        TextSpan(
                          text: '$dogName ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: text),
                      ],
                    ),
                  ),
                ),
                if (timeAgo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      timeAgo,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
