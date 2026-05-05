import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/app_badge_service.dart';
import 'package:barkdate/services/in_app_notification_service.dart';
import 'package:barkdate/models/notification.dart';

// Defined here to avoid a circular import with firebase_messaging_service.dart.
// FirebaseMessagingService.initialize() calls registerPushDelegate() to wire
// itself in, so every createNotification call gets a real FCM push.
typedef PushNotificationDelegate = Future<bool> Function({
  required String userToken,
  required String title,
  required String body,
  required NotificationType type,
  Map<String, dynamic>? data,
  int? badgeCount,
});

/// Service for managing notifications in BarkDate
class NotificationService {
  static PushNotificationDelegate? _pushDelegate;

  /// Called once by FirebaseMessagingService.initialize() to register the
  /// real FCM sender. Keeps this file free of a circular import.
  static void registerPushDelegate(PushNotificationDelegate delegate) {
    _pushDelegate = delegate;
  }

  /// Get unread notifications for a user
  static Future<List<Map<String, dynamic>>> getUnreadNotifications(
      String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting unread notifications: $e');
      return [];
    }
  }

  /// Get all notifications for a user
  static Future<List<Map<String, dynamic>>> getAllNotifications(
      String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting all notifications: $e');
      return [];
    }
  }

  /// Real-time stream of notifications for a user (ordered newest first)
  static Stream<List<Map<String, dynamic>>> streamUserNotifications(
      String userId) {
    return SupabaseConfig.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);

      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        await syncBadgeCount(userId);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true}).eq('user_id', userId);

      await AppBadgeService.clearBadge();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Mark every notification matching [userId] + [relatedId] (and optionally
  /// [type]) as read. Used when we know the request/playdate id but not the
  /// notification id — e.g. an FCM payload arriving before the DB row is in
  /// our local cache, or a walk-invite sheet opened from a tap-from-background
  /// where we only have [related_id].
  ///
  /// Filters on `is_read=false` so we don't generate no-op realtime ticks.
  /// Fails open (logs but doesn't rethrow) so callers can use this in UI
  /// hot paths without wrapping in try/catch.
  static Future<void> markAsReadByRelatedId({
    required String userId,
    required String relatedId,
    String? type,
  }) async {
    try {
      var query = SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('related_id', relatedId)
          .eq('is_read', false);
      if (type != null) {
        query = query.eq('type', type);
      }
      await query;
      await syncBadgeCount(userId);
    } catch (e) {
      debugPrint('Error marking notifications as read by related_id: $e');
    }
  }

  /// Create a new notification
  static Future<Map<String, dynamic>> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? actionType,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'action_type': actionType,
        'related_id': relatedId,
        'metadata': metadata,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Try client insert first, fallback to RPC if RLS blocks
      Map<String, dynamic> result;
      try {
        final insertResult =
            await SupabaseService.insert('notifications', notificationData);
        result = insertResult.first;
      } catch (e) {
        final errMsg = e.toString();

        if (errMsg.contains('row-level security') ||
            errMsg.contains('violates row-level security')) {
          // Use server-side RPC for cross-user notifications
          try {
            final rpc = await SupabaseConfig.client
                .rpc('create_notification', params: notificationData);
            if (rpc is Map<String, dynamic>) result = rpc;
            if (rpc is List && rpc.isNotEmpty) {
              result = Map<String, dynamic>.from(rpc.first);
            }

            // Fallback return
            result = {
              'id': null,
              'user_id': userId,
              'title': title,
              'body': body,
            };
          } catch (rpcErr) {
            debugPrint('Notification RPC failed: $rpcErr');
            rethrow;
          }
        } else {
          debugPrint('Notification creation failed: $errMsg');
          rethrow;
        }
      }

      // Send push notification via the delegate registered by FirebaseMessagingService.
      // Failure here must never break the DB insert above.
      try {
        if (_pushDelegate != null) {
          final userResponse = await SupabaseConfig.client
              .from('users')
              .select('fcm_token')
              .eq('id', userId)
              .maybeSingle();

          final fcmToken = userResponse?['fcm_token'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            int badgeCount = 0;
            try {
              badgeCount = await getUnreadCount(userId);
            } catch (_) {}

            NotificationType notifType;
            switch (type) {
              case 'bark':
                notifType = NotificationType.bark;
                break;
              case 'playdate':
                notifType = NotificationType.playdate;
                break;
              case 'playdate_request':
                notifType = NotificationType.playdateRequest;
                break;
              case 'message':
                notifType = NotificationType.message;
                break;
              case 'match':
                notifType = NotificationType.match;
                break;
              case 'social':
                notifType = NotificationType.social;
                break;
              case 'achievement':
                notifType = NotificationType.achievement;
                break;
              default:
                notifType = NotificationType.system;
            }

            await _pushDelegate!(
              userToken: fcmToken,
              title: title,
              body: body,
              type: notifType,
              badgeCount: badgeCount,
              data: {
                'action_type': actionType,
                'related_id': relatedId,
                ...?metadata,
              },
            );
            debugPrint('📱 Push sent to user $userId');
          } else {
            debugPrint('⚠️ No FCM token for user $userId — skipping push');
          }
        }
      } catch (e) {
        debugPrint('Failed to send push notification: $e');
      }

      return result;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      rethrow;
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        await syncBadgeCount(userId);
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  /// Get notification count for a user
  static Future<int> getUnreadCount(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return data.length;
    } catch (e) {
      debugPrint('Error getting notification count: $e');
      return 0;
    }
  }

  /// Fetches the current unread count from the database and updates the iOS badge.
  /// Call this whenever the badge may be out of sync.
  static Future<void> syncBadgeCount(String userId) async {
    final unreadCount = await getUnreadCount(userId);
    debugPrint(
        '🔴 [NotificationService] syncBadgeCount: unreadCount=$unreadCount');
    await AppBadgeService.setBadgeCount(unreadCount);
  }

  /// Show in-app notification banner (for foreground notifications)
  static Future<void> showInAppNotification(
      BarkDateNotification notification) async {
    try {
      await InAppNotificationService.showNotification(notification);
    } catch (e) {
      debugPrint('Error showing in-app notification: $e');
    }
  }

  /// Create and show notification (both database and in-app if foreground)
  static Future<Map<String, dynamic>> createAndShowNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? actionType,
    String? relatedId,
    Map<String, dynamic>? metadata,
    bool showInApp = true,
  }) async {
    // Create in database
    final result = await createNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      actionType: actionType,
      relatedId: relatedId,
      metadata: metadata,
    );

    // Show in-app notification if requested
    if (showInApp) {
      try {
        final notification = BarkDateNotification.fromMap(result);
        await showInAppNotification(notification);
      } catch (e) {
        debugPrint('Error creating BarkDateNotification from result: $e');
      }
    }

    return result;
  }
}
