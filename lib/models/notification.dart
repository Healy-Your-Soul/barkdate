import 'package:flutter/material.dart';

/// Comprehensive notification model for BarkDate
/// Supports all notification types: barks, playdates, social interactions, messages
class BarkDateNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final String? actionType;
  final String? relatedId;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  const BarkDateNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.actionType,
    this.relatedId,
    this.metadata,
    this.isRead = false,
    required this.createdAt,
  });

  /// Create from database data
  factory BarkDateNotification.fromMap(Map<String, dynamic> data) {
    return BarkDateNotification(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      actionType: data['action_type'],
      relatedId: data['related_id'],
      metadata: data['metadata'] != null 
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
      isRead: data['is_read'] ?? false,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Get appropriate icon for notification type
  IconData get icon {
    switch (type) {
      case NotificationType.bark:
        return Icons.pets;
      case NotificationType.playdate:
        return Icons.calendar_today;
      case NotificationType.playdateRequest:
        return Icons.event_note;
      case NotificationType.message:
        return Icons.chat_bubble;
      case NotificationType.match:
        return Icons.favorite;
      case NotificationType.social:
        return Icons.thumb_up;
      case NotificationType.achievement:
        return Icons.emoji_events;
      case NotificationType.system:
        return Icons.info;
    }
  }

  /// Get appropriate color for notification type
  Color get iconColor {
    switch (type) {
      case NotificationType.bark:
        return Colors.orange;
      case NotificationType.playdate:
        return Colors.blue;
      case NotificationType.playdateRequest:
        return Colors.green;
      case NotificationType.message:
        return Colors.purple;
      case NotificationType.match:
        return Colors.pink;
      case NotificationType.social:
        return Colors.indigo;
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  /// Get notification subtitle based on type and metadata
  String get subtitle {
    switch (type) {
      case NotificationType.bark:
        final fromDogName = metadata?['from_dog_name'] ?? 'Someone';
        return '$fromDogName barked at your pup!';
      case NotificationType.playdateRequest:
        final organizerName = metadata?['organizer_name'] ?? 'Someone';
        final dogName = metadata?['organizer_dog_name'] ?? 'their dog';
        return '$organizerName invited $dogName for a playdate';
      case NotificationType.playdate:
        final location = metadata?['location'] ?? 'a location';
        return 'Playdate at $location';
      case NotificationType.message:
        final senderName = metadata?['sender_name'] ?? 'Someone';
        return '$senderName sent you a message';
      case NotificationType.match:
        final dogName = metadata?['other_dog_name'] ?? 'a dog';
        return 'You and $dogName are a perfect match!';
      case NotificationType.social:
        final action = metadata?['action'] ?? 'interacted';
        final postType = metadata?['post_type'] ?? 'your post';
        return 'Someone $action with $postType';
      case NotificationType.achievement:
        return 'You earned a new badge!';
      case NotificationType.system:
        return 'System notification';
    }
  }

  /// Check if notification has actionable content
  bool get isActionable {
    return type == NotificationType.playdateRequest || 
           type == NotificationType.message ||
           type == NotificationType.match;
  }

  /// Create a copy of this notification with updated fields
  BarkDateNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    String? actionType,
    String? relatedId,
    Map<String, dynamic>? metadata,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return BarkDateNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      actionType: actionType ?? this.actionType,
      relatedId: relatedId ?? this.relatedId,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get action buttons for actionable notifications
  List<NotificationAction> get actions {
    switch (type) {
      case NotificationType.playdateRequest:
        return [
          NotificationAction(
            label: 'Accept',
            icon: Icons.check,
            color: Colors.green,
            action: 'accept_playdate',
          ),
          NotificationAction(
            label: 'Decline',
            icon: Icons.close,
            color: Colors.red,
            action: 'decline_playdate',
          ),
          NotificationAction(
            label: 'Counter',
            icon: Icons.edit,
            color: Colors.orange,
            action: 'counter_propose',
          ),
        ];
      case NotificationType.message:
        return [
          NotificationAction(
            label: 'Reply',
            icon: Icons.reply,
            color: Colors.blue,
            action: 'reply_message',
          ),
        ];
      case NotificationType.match:
        return [
          NotificationAction(
            label: 'Message',
            icon: Icons.chat,
            color: Colors.pink,
            action: 'start_chat',
          ),
          NotificationAction(
            label: 'Playdate',
            icon: Icons.calendar_today,
            color: Colors.green,
            action: 'schedule_playdate',
          ),
        ];
      default:
        return [];
    }
  }
}

/// Notification types supported by BarkDate
enum NotificationType {
  bark,           // Someone barked at your dog
  playdate,       // Playdate updates/reminders
  playdateRequest, // New playdate invitation
  message,        // New message received
  match,          // Mutual bark match
  social,         // Social interactions (likes, comments)
  achievement,    // Badge unlocked
  system,         // System notifications
}

/// Action button for actionable notifications
class NotificationAction {
  final String label;
  final IconData icon;
  final Color color;
  final String action;

  const NotificationAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.action,
  });
}

/// Notification grouping for better organization
class NotificationGroup {
  final String title;
  final List<BarkDateNotification> notifications;
  final bool isExpanded;

  const NotificationGroup({
    required this.title,
    required this.notifications,
    this.isExpanded = true,
  });

  /// Get unread count for this group
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// Get total count for this group
  int get totalCount => notifications.length;

  /// Check if group has any unread notifications
  bool get hasUnread => unreadCount > 0;
}
