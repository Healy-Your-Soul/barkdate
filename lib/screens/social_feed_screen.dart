import 'package:flutter/material.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/post.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final List<Post> _posts = List.from(SampleData.socialPosts);

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
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(context, post);
        },
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
                  backgroundImage: NetworkImage(post.userPhoto),
                  onBackgroundImageError: (exception, stackTrace) {},
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'with ${post.dogName} • ${_formatPostTime(post.timestamp)}',
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

    if (difference.inDays > 0) {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 3, // Sample comments
                  itemBuilder: (context, index) => _buildCommentTile(context, index),
                ),
              ),
              _buildCommentInput(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentTile(BuildContext context, int index) {
    final sampleComments = [
      'What a beautiful dog! Looks like they\'re having a blast.',
      'I love seeing dogs so happy. Where is this park?',
      'Luna would love to play with your pup sometime!',
    ];

    final sampleNames = ['Sophie Bennett', 'Ethan Carter', 'Maya Lopez'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sampleNames[index],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sampleComments[index],
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${index + 1}d ago',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.person,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.send,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo),
                      label: const Text('Add Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Post'),
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
}