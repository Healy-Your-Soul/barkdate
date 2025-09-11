import 'package:flutter/foundation.dart';
import 'package:barkdate/services/firebase_messaging_service.dart';
import 'package:barkdate/services/in_app_notification_service.dart';
import 'package:barkdate/services/notification_sound_service.dart';
import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/models/notification.dart';

/// Central notification manager that coordinates all notification services
class NotificationManager {
  static bool _initialized = false;
  
  /// Initialize all notification services
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize Firebase messaging first
      await FirebaseMessagingService.initialize();
      
      // Initialize in-app notification service
      await InAppNotificationService.initialize();
      
      // Initialize sound service (fallback if no custom sounds)
      await NotificationSoundService.initialize();
      
      // Set up real-time subscription for current user notifications
      _setupRealtimeNotifications();
      
      _initialized = true;
      debugPrint('✅ NotificationManager initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize NotificationManager: $e');
      rethrow;
    }
  }
  
  /// Set up real-time notification listening for the current user
  static void _setupRealtimeNotifications() {
    final currentUser = SupabaseConfig.auth.currentUser;
    if (currentUser == null) return;
    
    // Listen to real-time notifications
    NotificationService.streamUserNotifications(currentUser.id).listen(
      (notifications) {
        if (notifications.isNotEmpty) {
          // Get the latest notification
          final latestNotification = notifications.first;
          
          // Check if it's unread and recent (within last 10 seconds)
          final isUnread = latestNotification['is_read'] == false;
          final createdAt = DateTime.parse(latestNotification['created_at']);
          final isRecent = DateTime.now().difference(createdAt).inSeconds < 10;
          
          if (isUnread && isRecent) {
            // Show in-app notification for recent unread notifications
            try {
              final notification = BarkDateNotification.fromMap(latestNotification);
              InAppNotificationService.showNotification(notification);
            } catch (e) {
              debugPrint('Error showing real-time notification: $e');
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Real-time notification error: $error');
      },
    );
  }
  
  /// Create and send a comprehensive notification
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    String? actionType,
    String? relatedId,
    Map<String, dynamic>? metadata,
    bool sendPush = true,
    bool showInApp = true,
    bool playSound = true,
  }) async {
    try {
      // Create notification in database
      await NotificationService.createNotification(
        userId: userId,
        title: title,
        body: body,
        type: type.toString().split('.').last,
        actionType: actionType,
        relatedId: relatedId,
        metadata: metadata,
      );
      
      // Play sound if requested
      if (playSound) {
        try {
          await NotificationSoundService.playNotificationFeedback(type);
        } catch (e) {
          debugPrint('Failed to play notification sound: $e');
        }
      }
      
      debugPrint('✅ Notification sent successfully to user $userId');
    } catch (e) {
      debugPrint('❌ Failed to send notification: $e');
      rethrow;
    }
  }
  
  /// Send a bark notification
  static Future<void> sendBarkNotification({
    required String receiverUserId,
    required String senderDogName,
    required String receiverDogName,
    String? senderUserId,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: '🐕 New Bark!',
      body: '$senderDogName wants to play with $receiverDogName!',
      type: NotificationType.bark,
      actionType: 'open_matches',
      metadata: {
        'sender_user_id': senderUserId,
        'sender_dog_name': senderDogName,
        'receiver_dog_name': receiverDogName,
      },
    );
  }
  
  /// Send a playdate invitation notification
  static Future<void> sendPlaydateInviteNotification({
    required String receiverUserId,
    required String senderName,
    required String playdateId,
    required DateTime playdateDate,
    required String location,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: '🎾 New Playdate Invitation!',
      body: '$senderName invited you to a playdate on ${NotificationManager._formatDate(playdateDate)} at $location',
      type: NotificationType.playdateRequest,
      actionType: 'open_playdate',
      relatedId: playdateId,
      metadata: {
        'sender_name': senderName,
        'playdate_date': playdateDate.toIso8601String(),
        'location': location,
      },
    );
  }
  
  /// Send a playdate response notification
  static Future<void> sendPlaydateResponseNotification({
    required String receiverUserId,
    required String responderName,
    required String playdateId,
    required bool accepted,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: accepted ? '✅ Playdate Accepted!' : '❌ Playdate Declined',
      body: accepted
          ? '$responderName accepted your playdate invitation!'
          : '$responderName declined your playdate invitation.',
      type: NotificationType.playdate,
      actionType: 'open_playdate',
      relatedId: playdateId,
      metadata: {
        'responder_name': responderName,
        'accepted': accepted,
      },
    );
  }
  
  /// Send a playdate reminder notification
  static Future<void> sendPlaydateReminderNotification({
    required String userId,
    required String playdateId,
    required DateTime playdateDate,
    required String location,
  }) async {
    await sendNotification(
      userId: userId,
      title: '⏰ Playdate Reminder',
      body: 'Your playdate is starting soon at $location!',
      type: NotificationType.playdate,
      actionType: 'open_playdate',
      relatedId: playdateId,
      metadata: {
        'playdate_date': playdateDate.toIso8601String(),
        'location': location,
      },
    );
  }
  
  /// Send a match notification
  static Future<void> sendMatchNotification({
    required String userId,
    required String matchedDogName,
    required String matchId,
  }) async {
    await sendNotification(
      userId: userId,
      title: '💝 It\'s a Match!',
      body: 'You and $matchedDogName liked each other!',
      type: NotificationType.match,
      actionType: 'open_matches',
      relatedId: matchId,
      metadata: {
        'matched_dog_name': matchedDogName,
      },
    );
  }
  
  /// Format date for notifications
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) {
      return 'today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'tomorrow at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// Clean up notification services
  static void dispose() {
    _initialized = false;
  }
}
