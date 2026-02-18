import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/in_app_notification_service.dart';
import 'package:barkdate/models/notification.dart';

/// Service for managing notifications in BarkDate
class NotificationService {
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
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
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

      // Send push notification if Firebase is initialized
      try {
        // Store FCM token for the user (simplified for now)
        debugPrint('Would send push notification to user $userId: $title');
      } catch (e) {
        debugPrint('Failed to send push notification: $e');
        // Don't fail the whole operation if push fails
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
