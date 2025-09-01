import 'package:barkdate/supabase/supabase_config.dart';

/// Service for managing notifications in BarkDate
class NotificationService {
  /// Get unread notifications for a user
  static Future<List<Map<String, dynamic>>> getUnreadNotifications(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(data ?? []);
    } catch (e) {
      print('Error getting unread notifications: $e');
      return [];
    }
  }

  /// Get all notifications for a user
  static Future<List<Map<String, dynamic>>> getAllNotifications(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(data ?? []);
    } catch (e) {
      print('Error getting all notifications: $e');
      return [];
    }
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } catch (e) {
      print('Error marking all notifications as read: $e');
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

      final result = await SupabaseService.insert('notifications', notificationData);
      return result.first;
    } catch (e) {
      print('Error creating notification: $e');
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
      print('Error deleting notification: $e');
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
      print('Error getting notification count: $e');
      return 0;
    }
  }

  /// Subscribe to real-time notification updates (placeholder for future implementation)
  static void subscribeToNotifications(String userId, Function(Map<String, dynamic>) onNotification) {
    // TODO: Implement real-time notifications
    print('Real-time notifications not yet implemented');
  }

  /// Unsubscribe from notification updates (placeholder for future implementation)
  static void unsubscribeFromNotifications() {
    // TODO: Implement real-time notifications
    print('Real-time notifications not yet implemented');
  }
}
