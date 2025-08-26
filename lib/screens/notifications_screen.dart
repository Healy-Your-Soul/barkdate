import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      NotificationItem(
        icon: Icons.favorite,
        title: 'New Match!',
        message: 'You and Buddy are a perfect match! Start chatting now.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead: false,
      ),
      NotificationItem(
        icon: Icons.message,
        title: 'New Message',
        message: 'Sarah sent you a message about tomorrow\'s playdate.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationItem(
        icon: Icons.calendar_today,
        title: 'Playdate Reminder',
        message: 'Don\'t forget your playdate with Max at Central Park tomorrow at 10 AM.',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isRead: true,
      ),
      NotificationItem(
        icon: Icons.emoji_events,
        title: 'Achievement Unlocked!',
        message: 'You earned the "Social Butterfly" badge! 🎉',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationItem(
        icon: Icons.pets,
        title: 'Someone Barked at Luna!',
        message: 'Charlie thinks Luna would be a great playmate.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
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
          TextButton(
            onPressed: () {},
            child: Text(
              'Mark all read',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationTile(context, notification);
        },
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, NotificationItem notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead 
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getNotificationIconColor(context, notification.icon),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            notification.icon,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 24,
          ),
        ),
        title: Text(
          notification.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatNotificationTime(notification.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        trailing: !notification.isRead 
          ? Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
        onTap: () {
          // Handle notification tap
        },
      ),
    );
  }

  Color _getNotificationIconColor(BuildContext context, IconData icon) {
    switch (icon) {
      case Icons.favorite:
        return Colors.pink;
      case Icons.message:
        return Theme.of(context).colorScheme.primary;
      case Icons.calendar_today:
        return Theme.of(context).colorScheme.secondary;
      case Icons.emoji_events:
        return Theme.of(context).colorScheme.tertiary;
      case Icons.pets:
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatNotificationTime(DateTime time) {
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

class NotificationItem {
  final IconData icon;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}