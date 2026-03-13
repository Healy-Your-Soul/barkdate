import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Provider for managing the total unread notifications count globally
final notificationCountProvider =
    StateNotifierProvider<NotificationCountNotifier, int>((ref) {
  return NotificationCountNotifier();
});

class NotificationCountNotifier extends StateNotifier<int> {
  StreamSubscription? _subscription;
  RealtimeChannel? _channel;

  NotificationCountNotifier() : super(0) {
    _init();
  }

  Future<void> _init() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    // 1. Initial fetch of unread count
    try {
      final response = await SupabaseConfig.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (mounted) {
        state = response.length;
      }
    } catch (e) {
      // Ignore initial load errors
    }

    // 2. Setup Realtime Listener for the user's notifications
    _channel = SupabaseConfig.client
        .channel('public:notifications_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            _handleNotificationChange(payload);
          },
        )
        .subscribe();
  }

  void _handleNotificationChange(PostgresChangePayload payload) {
    final eventType = payload.eventType;

    if (eventType == PostgresChangeEvent.insert) {
      // New notification arrived, increment if unread
      final isRead = payload.newRecord['is_read'] == true;
      if (!isRead && mounted) {
        state = state + 1;
      }
    } else if (eventType == PostgresChangeEvent.update) {
      // Notification updated (e.g. marked as read)
      final wasRead = payload.oldRecord['is_read'] == true;
      final isRead = payload.newRecord['is_read'] == true;

      if (!wasRead && isRead && mounted) {
        state = (state - 1).clamp(0, double.infinity).toInt();
      } else if (wasRead && !isRead && mounted) {
        state = state + 1;
      }
    } else if (eventType == PostgresChangeEvent.delete) {
      // Notification deleted
      final wasRead = payload.oldRecord['is_read'] == true;
      if (!wasRead && mounted) {
        state = (state - 1).clamp(0, double.infinity).toInt();
      }
    }
  }

  void markAllAsRead() {
    state = 0;
  }

  void decrement() {
    state = (state - 1).clamp(0, double.infinity).toInt();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
