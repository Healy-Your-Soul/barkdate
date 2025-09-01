import 'package:flutter/material.dart';
import 'package:barkdate/models/notification.dart';
import 'package:barkdate/widgets/notification_tile.dart';
import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/screens/playdates_screen.dart';
import 'package:barkdate/screens/chat_detail_screen.dart';
import 'package:barkdate/screens/social_feed_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<BarkDateNotification> _notifications = [];
  List<NotificationGroup> _notificationGroups = [];
  bool _isLoading = true;
  String? _error;
  String _selectedView = 'all'; // 'all', 'unread', 'grouped'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
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
          // View toggle button
          PopupMenuButton<String>(
            icon: Icon(
              Icons.view_list,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onSelected: (value) {
              setState(() => _selectedView = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('All Notifications'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unread',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread),
                    SizedBox(width: 8),
                    Text('Unread Only'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'grouped',
                child: Row(
                  children: [
                    Icon(Icons.group_work),
                    SizedBox(width: 8),
                    Text('Grouped by Type'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Mark all read button
          TextButton(
            onPressed: _markAllAsRead,
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
      body: _buildBody(),
    );
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser == null) {
        // Show sample data for demo
        _loadSampleNotifications();
        return;
      }

      // Load real notifications from database
      final notificationsData = await NotificationService.getUnreadNotifications(currentUser.id);
      
      // Convert to BarkDateNotification objects
      final notifications = notificationsData.map((data) => 
        BarkDateNotification.fromMap(data)
      ).toList();

      // Add some sample notifications for demo purposes
      notifications.addAll(_getSampleNotifications());

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _notificationGroups = _groupNotifications(notifications);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadSampleNotifications(); // Fallback to sample data
          _isLoading = false;
        });
      }
    }
  }

  void _loadSampleNotifications() {
    final notifications = _getSampleNotifications();
    setState(() {
      _notifications = notifications;
      _notificationGroups = _groupNotifications(notifications);
    });
  }

  List<BarkDateNotification> _getSampleNotifications() {
    return [
      BarkDateNotification(
        id: '1',
        userId: 'current_user',
        title: 'Charlie barked at Luna! 🐕',
        body: 'Someone is interested in meeting your pup!',
        type: NotificationType.bark,
        metadata: {
          'from_dog_name': 'Charlie',
          'from_user_id': 'user_123',
        },
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      BarkDateNotification(
        id: '2',
        userId: 'current_user',
        title: 'New Playdate Invitation! 🐕',
        body: 'Sarah invited Max for a playdate at Central Park',
        type: NotificationType.playdateRequest,
        metadata: {
          'organizer_name': 'Sarah',
          'organizer_dog_name': 'Max',
          'location': 'Central Park',
          'scheduled_at': '2024-01-15T14:00:00Z',
        },
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      BarkDateNotification(
        id: '3',
        userId: 'current_user',
        title: 'It\'s a match! 🎉',
        body: 'Luna and Buddy both barked at each other!',
        type: NotificationType.match,
        metadata: {
          'other_dog_name': 'Buddy',
          'other_user_id': 'user_456',
        },
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      BarkDateNotification(
        id: '4',
        userId: 'current_user',
        title: 'New Message from Sarah',
        body: 'Hi! How is Luna doing?',
        type: NotificationType.message,
        metadata: {
          'sender_name': 'Sarah',
          'sender_id': 'user_123',
        },
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      BarkDateNotification(
        id: '5',
        userId: 'current_user',
        title: 'Someone liked your post! 👍',
        body: 'Charlie liked your post about Luna\'s adventure',
        type: NotificationType.social,
        metadata: {
          'action': 'liked',
          'post_type': 'your post',
          'user_name': 'Charlie',
        },
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading notifications...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'When you get barks, playdate requests, or messages, they\'ll appear here!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Filter notifications based on selected view
    final filteredNotifications = _getFilteredNotifications();
    
    switch (_selectedView) {
      case 'grouped':
        return _buildGroupedView();
      case 'unread':
        return _buildUnreadView(filteredNotifications);
      default:
        return _buildAllView(filteredNotifications);
    }
  }

  Widget _buildAllView(List<BarkDateNotification> notifications) {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return NotificationTile(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onActionPressed: (action) => _handleNotificationAction(notification, action),
          );
        },
      ),
    );
  }

  Widget _buildUnreadView(List<BarkDateNotification> notifications) {
    final unreadNotifications = notifications.where((n) => !n.isRead).toList();
    
    if (unreadNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_email_read,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up! 🎉',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No unread notifications',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: unreadNotifications.length,
        itemBuilder: (context, index) {
          final notification = unreadNotifications[index];
          return NotificationTile(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onActionPressed: (action) => _handleNotificationAction(notification, action),
          );
        },
      ),
    );
  }

  Widget _buildGroupedView() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notificationGroups.length,
        itemBuilder: (context, index) {
          final group = _notificationGroups[index];
          return _buildNotificationGroup(group);
        },
      ),
    );
  }

  Widget _buildNotificationGroup(NotificationGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            children: [
              Icon(
                _getGroupIcon(group.title),
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                group.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (group.hasUnread)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${group.unreadCount}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Group notifications
        ...group.notifications.map((notification) => 
          NotificationTile(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onActionPressed: (action) => _handleNotificationAction(notification, action),
            showActions: true,
          ),
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  IconData _getGroupIcon(String groupTitle) {
    switch (groupTitle) {
      case 'Barks':
        return Icons.pets;
      case 'Playdates':
        return Icons.calendar_today;
      case 'Messages':
        return Icons.chat_bubble;
      case 'Matches':
        return Icons.favorite;
      case 'Social':
        return Icons.thumb_up;
      case 'Achievements':
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  List<BarkDateNotification> _getFilteredNotifications() {
    switch (_selectedView) {
      case 'unread':
        return _notifications.where((n) => !n.isRead).toList();
      default:
        return _notifications;
    }
  }

  List<NotificationGroup> _groupNotifications(List<BarkDateNotification> notifications) {
    final Map<String, List<BarkDateNotification>> grouped = {};
    
    for (final notification in notifications) {
      final groupKey = _getNotificationGroupKey(notification.type);
      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(notification);
    }
    
    // Sort each group by creation time (newest first)
    for (final group in grouped.values) {
      group.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    
    // Convert to NotificationGroup objects
    return grouped.entries.map((entry) => 
      NotificationGroup(
        title: entry.key,
        notifications: entry.value,
      ),
    ).toList()
      ..sort((a, b) => b.notifications.first.createdAt.compareTo(a.notifications.first.createdAt));
  }

  String _getNotificationGroupKey(NotificationType type) {
    switch (type) {
      case NotificationType.bark:
        return 'Barks';
      case NotificationType.playdate:
      case NotificationType.playdateRequest:
        return 'Playdates';
      case NotificationType.message:
        return 'Messages';
      case NotificationType.match:
        return 'Matches';
      case NotificationType.social:
        return 'Social';
      case NotificationType.achievement:
        return 'Achievements';
      case NotificationType.system:
        return 'System';
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser != null) {
        await NotificationService.markAllAsRead(currentUser.id);
      }
      
      // Update local state
      setState(() {
        _notifications = _notifications.map((notification) => 
          notification.copyWith(isRead: true)
        ).toList();
        _notificationGroups = _groupNotifications(_notifications);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleNotificationTap(BarkDateNotification notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.playdateRequest:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlaydatesScreen()),
        );
        break;
      case NotificationType.message:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatDetailScreen(
            recipientName: notification.metadata?['sender_name'] ?? 'Unknown',
            dogName: 'Unknown',
          )),
        );
        break;
      case NotificationType.social:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SocialFeedScreen()),
        );
        break;
      default:
        _markNotificationAsRead(notification);
        break;
    }
  }

  Future<void> _handleNotificationAction(BarkDateNotification notification, String action) async {
    try {
      switch (action) {
        case 'accept_playdate':
          _showPlaydateResponseDialog(notification, 'accepted');
          break;
        case 'decline_playdate':
          _showPlaydateResponseDialog(notification, 'declined');
          break;
        case 'counter_propose':
          _showPlaydateResponseDialog(notification, 'counter_proposed');
          break;
        case 'reply_message':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatDetailScreen(
              recipientName: notification.metadata?['sender_name'] ?? 'Unknown',
              dogName: 'Unknown',
            )),
          );
          break;
        case 'start_chat':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatDetailScreen(
              recipientName: notification.metadata?['other_user_name'] ?? 'Unknown',
              dogName: notification.metadata?['other_dog_name'] ?? 'Unknown',
            )),
          );
          break;
        case 'schedule_playdate':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlaydatesScreen()),
          );
          break;
        case 'mark_read':
          await _markNotificationAsRead(notification);
          break;
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPlaydateResponseDialog(BarkDateNotification notification, String response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Playdate ${response == 'accepted' ? 'Accepted' : response == 'declined' ? 'Declined' : 'Counter-Proposed'}'),
        content: Text(
          response == 'accepted' 
            ? 'Great! The playdate is now confirmed.'
            : response == 'declined'
              ? 'The playdate invitation has been declined.'
              : 'You can now suggest alternative times or locations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _markNotificationAsRead(BarkDateNotification notification) async {
    try {
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser != null) {
        await NotificationService.markAsRead(notification.id);
      }
      
      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(isRead: true);
          _notificationGroups = _groupNotifications(_notifications);
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }
}
