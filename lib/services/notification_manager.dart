import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/services/firebase_messaging_service.dart';
import 'package:barkdate/services/in_app_notification_service.dart';
import 'package:barkdate/services/notification_sound_service.dart';
import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/models/notification.dart';
import 'package:barkdate/core/router/app_router.dart';
import 'package:barkdate/widgets/receive_walk_sheet.dart';
import 'package:barkdate/features/messages/presentation/screens/chat_screen.dart';

/// Central notification manager that coordinates all notification services
class NotificationManager {
  static bool _initialized = false;
  static StreamSubscription<AuthState>? _authSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;
  static bool _streamsStarted = false;

  /// Initialize all core notification services
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase messaging first
      await FirebaseMessagingService.initialize();

      // Sync badge count on initialization for iOS
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser != null) {
        await NotificationService.syncBadgeCount(currentUser.id);
      }

      // Initialize in-app notification service
      await InAppNotificationService.initialize();

      // Initialize sound service (fallback if no custom sounds)
      await NotificationSoundService.initialize();

      // Listen for auth state changes to clean up notifications on sign-out
      _authSubscription?.cancel();
      _authSubscription =
          SupabaseConfig.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedOut) {
          debugPrint(
              '🔄 Auth sign-out detected, stopping notification streams');
          stopNotificationStreams();
        }
      });

      _initialized = true;
      debugPrint('✅ NotificationManager initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize NotificationManager: $e');
      rethrow;
    }
  }

  /// Called after the initial loading screen has completely finished
  /// This prevents unnecessary network calls during splash and ensures
  /// banners only show once the user is actually in the app.
  static void startNotificationStreams() {
    if (_streamsStarted) return;

    final currentUser = SupabaseConfig.auth.currentUser;
    if (currentUser == null) return;

    debugPrint('🚀 Starting notification streams for ${currentUser.id}');
    _setupRealtimeNotifications();
    _scanPendingWalkInvites();

    _streamsStarted = true;
  }

  /// Stops ongoing network streams for notifications
  static void stopNotificationStreams() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _streamsStarted = false;
  }

  /// Called when the app resumes from background.
  /// Re-scans for pending walk invites the user may have missed.
  static void onAppResumed() {
    if (_streamsStarted) {
      _scanPendingWalkInvites();
    }
  }

  /// One-time fetch of unread playdate_request notifications for the current
  /// user.  If any pending walk invite is found, open the ReceiveWalkSheet.
  /// Uses the same dedupe guard as the realtime path so we never double-open.
  static Future<void> _scanPendingWalkInvites() async {
    try {
      final uid = SupabaseConfig.auth.currentUser?.id;
      if (uid == null) return;

      // Fetch unread playdate_request notifications
      final rows = await SupabaseConfig.client
          .from('notifications')
          .select('*')
          .eq('user_id', uid)
          .eq('is_read', false)
          .eq('type', 'playdate_request')
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) return;
      final row = rows.first;

      // Build payload for the sheet opener
      final notification = BarkDateNotification.fromMap(row);
      final meta = notification.metadata ?? {};
      final payload = <String, dynamic>{
        ...meta,
        'related_id': notification.relatedId,
        'notification_id': notification.id, // Sprint 1: enable mark-as-read
        'type': 'playdate_request',
      };

      // Wait for navigator to be ready (post-frame callback + retry)
      void tryOpen([int attempt = 0]) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          openReceiveWalkSheetFromInvitePayload(ctx, payload);
        } else if (attempt < 3) {
          // Retry after a short delay if navigator isn't mounted yet
          Future.delayed(
            Duration(milliseconds: 300 * (attempt + 1)),
            () => WidgetsBinding.instance
                .addPostFrameCallback((_) => tryOpen(attempt + 1)),
          );
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => tryOpen());
    } catch (e) {
      debugPrint('Error scanning pending walk invites: $e');
    }
  }

  /// Set up real-time notification listening for the current user
  static void _setupRealtimeNotifications() {
    final currentUser = SupabaseConfig.auth.currentUser;
    if (currentUser == null) return;

    // Cancel any previous subscription before creating a new one
    _realtimeSubscription?.cancel();

    // Listen to real-time notifications
    _realtimeSubscription =
        NotificationService.streamUserNotifications(currentUser.id).listen(
      (notifications) async {
        if (notifications.isNotEmpty) {
          // Get the latest notification
          final latestNotification = notifications.first;

          final isUnread = latestNotification['is_read'] == false;
          final createdAt = DateTime.parse(latestNotification['created_at']);
          final isRecent = DateTime.now().difference(createdAt).inSeconds < 10;

          if (isUnread) {
            try {
              final notification =
                  BarkDateNotification.fromMap(latestNotification);

              // Sprint 7b: only show the sliding banner for walk invites.
              // Other notifications (messages, barks, matches) just update
              // the badge silently — the banner was spamming users in-app.
              final shouldShowBanner =
                  notification.type == NotificationType.playdateRequest;
              if (isRecent && shouldShowBanner) {
                InAppNotificationService.showNotification(
                  notification,
                  onTapAction: () {
                    final ctx = rootNavigatorKey.currentContext;
                    if (ctx == null) return;
                    final meta = notification.metadata ?? {};
                    final payload = <String, dynamic>{
                      ...meta,
                      'related_id': notification.relatedId,
                      'notification_id': notification.id,
                      'type': 'playdate_request',
                    };
                    openReceiveWalkSheetFromInvitePayload(ctx, payload);
                  },
                );
              }

              // Sprint 7b: auto-mark-read if user is currently in the chat
              // this notification belongs to.
              if (notification.type == NotificationType.message) {
                final convoId = notification.relatedId ??
                    (notification.metadata?['conversation_id'] as String?);
                if (convoId != null &&
                    ChatScreenState.isViewing(convoId)) {
                  await NotificationService.markAsRead(notification.id);
                  return;
                }
              }

              // Auto-open walk invite sheet for playdate_request regardless
              // of age — the dedupe guard inside
              // openReceiveWalkSheetFromInvitePayload prevents doubles.
              if (notification.type == NotificationType.playdateRequest) {
                final meta = notification.metadata ?? {};
                final payload = <String, dynamic>{
                  ...meta,
                  'related_id': notification.relatedId,
                  'notification_id':
                      notification.id, // Sprint 1: enable mark-as-read
                  'type': 'playdate_request',
                };
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final ctx = rootNavigatorKey.currentContext;
                  if (ctx != null) {
                    openReceiveWalkSheetFromInvitePayload(ctx, payload);
                  }
                });
              }
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
      // Create notification in database and fire push via delegate in
      // NotificationService.createNotification (wired up in Sprint 7a).
      // The sendPush flag is kept for API compatibility but push is now
      // always handled inside createNotification.
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
      body:
          '$senderName invited you to a playdate on ${NotificationManager._formatDate(playdateDate)} at $location',
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

  /// Send a chat message notification
  static Future<void> sendMessageNotification({
    required String receiverUserId,
    required String senderName,
    required String messageContent,
    required String matchId,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: '💬 New Message from $senderName',
      body: messageContent, // The actual message content
      type: NotificationType.message,
      actionType:
          'open_chat', // Navigation logic in FirebaseMessagingService handles this
      relatedId: matchId,
      metadata: {
        'sender_name': senderName,
        'message_content': messageContent,
      },
    );
  }

  /// Send a post tag notification (using social type)
  static Future<void> sendPostTagNotification({
    required String receiverUserId,
    required String taggerDogName,
    required String postId,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: '🏷️ You were tagged!',
      body: '$taggerDogName tagged you in a post.',
      type: NotificationType.social,
      actionType: 'open_post',
      relatedId: postId,
      metadata: {
        'action': 'tagged you in',
        'post_type': 'a post',
        'from_dog_name': taggerDogName,
      },
    );
  }

  /// Send an event invite notification (using social type)
  static Future<void> sendEventInviteNotification({
    required String receiverUserId,
    required String inviterName,
    required String eventId,
    required String eventTitle,
  }) async {
    await sendNotification(
      userId: receiverUserId,
      title: '📅 Event Invitation',
      body: '$inviterName invited you to $eventTitle',
      type: NotificationType.social,
      actionType: 'open_event',
      relatedId: eventId,
      metadata: {
        'action': 'invited you to',
        'post_type': 'event: $eventTitle',
        'inviter_name': inviterName,
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
    _authSubscription?.cancel();
    _authSubscription = null;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _initialized = false;
  }
}
