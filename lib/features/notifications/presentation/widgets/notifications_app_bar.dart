import 'package:flutter/material.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/services/app_badge_service.dart';
import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:go_router/go_router.dart';

import 'package:barkdate/features/notifications/presentation/screens/notifications_screen.dart'; // To access notificationsProvider

class NotificationsAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const NotificationsAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: Text('Notifications', style: AppTypography.h2()),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            const SplashRoute().go(context);
          }
        },
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) {
            if (value == 'read') {
              _markAllAsRead(context, ref);
            } else if (value == 'clear') {
              _clearAllNotifications(context, ref);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'read',
              child: Row(
                children: [
                  Icon(Icons.done_all, color: Colors.grey, size: 20),
                  SizedBox(width: 12),
                  Text('Mark all read'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Clear all', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _markAllAsRead(BuildContext context, WidgetRef ref) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      await NotificationService.markAllAsRead(user.id);

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

  void _clearAllNotifications(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      await SupabaseConfig.client
          .from('notifications')
          .delete()
          .eq('user_id', user.id);

      await AppBadgeService.clearBadge();

      ref.invalidate(notificationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing notifications: $e')),
        );
      }
    }
  }
}
