import 'package:flutter/material.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/message.dart';
import 'package:barkdate/screens/chat_detail_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messages',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: SampleData.chatPreviews.length,
        itemBuilder: (context, index) {
          final chat = SampleData.chatPreviews[index];
          return _buildChatPreviewTile(context, chat);
        },
      ),
    );
  }

  Widget _buildChatPreviewTile(BuildContext context, ChatPreview chat) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(chat.otherDogPhoto),
            onBackgroundImageError: (exception, stackTrace) {},
            child: chat.otherDogPhoto.isEmpty 
              ? Icon(Icons.pets, color: Theme.of(context).colorScheme.primary)
              : null,
          ),
          if (chat.unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Center(
                  child: Text(
                    chat.unreadCount.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chat.otherUserName,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'with ${chat.otherDogName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chat.lastMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: chat.unreadCount > 0 
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatMessageTime(chat.lastMessageTime),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (chat.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(chat: chat),
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}