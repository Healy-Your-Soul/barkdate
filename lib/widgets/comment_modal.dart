import 'dart:async';
import 'package:flutter/material.dart';
import 'package:barkdate/models/post.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/models/dog.dart'; // Import Dog model
import 'package:go_router/go_router.dart'; // Import go_router

/// Instagram-style comment modal with post image and real comment functionality
class CommentModal extends StatefulWidget {
  final Post post;

  const CommentModal({
    super.key,
    required this.post,
  });

  @override
  State<CommentModal> createState() => _CommentModalState();
}

class _CommentModalState extends State<CommentModal> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  String? _currentUserId;
  StreamSubscription? _commentsSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadComments();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _getCurrentUser() {
    final user = SupabaseConfig.auth.currentUser;
    _currentUserId = user?.id;
  }

  /// Get the current user's dog for display
  Future<List<Map<String, dynamic>>> _getCurrentUserDog() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return [];

      return await BarkDateUserService.getUserDogs(userId);
    } catch (e) {
      debugPrint('Error getting user dog: $e');
      return [];
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    _commentsSubscription?.cancel();
    _commentsSubscription =
        BarkDateSocialService.streamComments(widget.post.id).listen(
      (comments) {
        if (mounted) {
          setState(() {
            _comments = comments;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        debugPrint('Error streaming comments: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _currentUserId == null) {
      return;
    }

    setState(() => _isPosting = true);

    try {
      await BarkDateSocialService.addComment(
        postId: widget.post.id,
        userId: _currentUserId!,
        content: _commentController.text.trim(),
      );

      _commentController.clear();
      // await _loadComments(); // Requirement for real-time means we don't need manual reload

      if (mounted) {
        // Hide keyboard
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
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
    return GestureDetector(
      onTap: () => Navigator.pop(context), // Tap blur background to close
      child: Container(
        color: Colors.black.withValues(alpha: 0.5), // Blur background
        child: GestureDetector(
          onTap:
              () {}, // Prevent tap from propagating when tapping modal content
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) => Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar for drag indication
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Post header with image
                    _buildPostHeader(),

                    const Divider(height: 1),

                    // Comments list
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _comments.isEmpty
                              ? _buildEmptyComments()
                              : ListView.builder(
                                  controller: scrollController,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _comments.length,
                                  itemBuilder: (context, index) {
                                    return _buildCommentTile(_comments[index]);
                                  },
                                ),
                    ),

                    // Comment input
                    _buildCommentInput(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Post image thumbnail (if exists)
          if (widget.post.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.post.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  child: Icon(
                    Icons.image,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Post info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: widget.post.userPhoto.isNotEmpty
                          ? NetworkImage(widget.post.userPhoto)
                          : null,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      onBackgroundImageError: widget.post.userPhoto.isNotEmpty
                          ? (exception, stackTrace) {
                              debugPrint(
                                  'Error loading modal header image: $exception');
                            }
                          : null,
                      child: widget.post.userPhoto.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.post.dogName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'with ${widget.post.userName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                if (widget.post.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.post.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Comments count
          Text(
            'Comments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyComments() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No comments yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to comment!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final user = comment['user'] ?? {};
    final userName = user['name'] ?? 'Unknown User';
    final userAvatar = user['avatar_url'] ?? '';
    final content = comment['content'] ?? '';
    final createdAt = DateTime.tryParse(comment['created_at'] ?? '') ??
        DateTime.now()
            .subtract(const Duration(minutes: 2)); // Fallback to 2 minutes ago

    // Get dog data for the commenting user
    final dog = comment['dog'] ?? {};
    final dogName = dog['name'] ?? 'Unknown Dog';
    final dogPhoto = dog['main_photo_url'] ?? '';
    final ownerFirstName = userName.split(' ').first; // Get first name only

    // Attempt to get dog ID for navigation
    final dogId = dog['id'] as String?;

    final displayName = '$dogName & $ownerFirstName';
    final profileImage = dogPhoto.isNotEmpty ? dogPhoto : userAvatar;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: dogId != null ? () => _navigateToDogProfile(dogId) : null,
            child: CircleAvatar(
              radius: 18,
              backgroundImage: profileImage.isNotEmpty &&
                      !profileImage.contains('placeholder')
                  ? NetworkImage(profileImage)
                  : null,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              onBackgroundImageError: profileImage.isNotEmpty &&
                      !profileImage.contains('placeholder')
                  ? (exception, stackTrace) {
                      debugPrint(
                          'Error loading comment profile image: $exception');
                    }
                  : null,
              child:
                  profileImage.isEmpty || profileImage.contains('placeholder')
                      ? Icon(
                          Icons.pets, // Use pet icon for dog-focused comments
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap:
                      dogId != null ? () => _navigateToDogProfile(dogId) : null,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: displayName,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        TextSpan(
                          text: ' $content',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCommentTime(createdAt),
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
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    // Get keyboard height for padding
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + keyboardHeight, // Add keyboard height as bottom padding
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false, // Don't add extra padding at top
        child: Row(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getCurrentUserDog(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final dog = snapshot.data!.first;
                  final dogPhotoUrl = dog['main_photo_url'];
                  return CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        dogPhotoUrl != null && dogPhotoUrl.toString().isNotEmpty
                            ? NetworkImage(dogPhotoUrl)
                            : null,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    onBackgroundImageError: (exception, stackTrace) {
                      debugPrint('Error loading dog image: $exception');
                    },
                    child: dogPhotoUrl == null || dogPhotoUrl.toString().isEmpty
                        ? Icon(
                            Icons.pets,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : null,
                  );
                }
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.pets,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isPosting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: _addComment,
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _formatCommentTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

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
}
