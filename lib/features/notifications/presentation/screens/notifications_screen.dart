import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:barkdate/supabase/notification_service.dart';

/// Provider for notifications
final notificationsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return Stream.value([]);
  
  return NotificationService.streamUserNotifications(user.id);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Notifications', style: AppTypography.h2()),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(context, ref),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: AppTypography.bodyMedium().copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see barks, playdate requests,\nand more here',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall().copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationItem(context, notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error loading notifications: $error'),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, Map<String, dynamic> notification) {
    final type = notification['type'] as String? ?? 'general';
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final isRead = notification['is_read'] as bool? ?? false;
    final createdAt = DateTime.tryParse(notification['created_at'] ?? '') ?? DateTime.now();

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'bark':
        icon = Icons.pets;
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'playdate_request':
        icon = Icons.calendar_today;
        iconColor = const Color(0xFFED924D);
        break;
      case 'playdate_confirmed':
        icon = Icons.check_circle;
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'message':
        icon = Icons.chat_bubble_outline;
        iconColor = const Color(0xFFE885DC);
        break;
      case 'event':
        icon = Icons.event;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium().copyWith(
          fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              style: AppTypography.bodySmall().copyWith(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            timeago.format(createdAt),
            style: AppTypography.caption().copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
      trailing: !isRead
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    );
  }

  void _markAllAsRead(BuildContext context, WidgetRef ref) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);

      ref.invalidate(notificationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }
}
