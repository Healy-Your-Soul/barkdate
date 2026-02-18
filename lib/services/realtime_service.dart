import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized real-time service for instant updates across the app
/// Handles achievements, likes, comments, and other live data
class RealtimeService {
  static final _client = SupabaseConfig.client;

  // Singleton pattern
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  // Active subscriptions
  final Map<String, RealtimeChannel> _channels = {};

  // Stream controllers for different event types
  final _achievementController = StreamController<AchievementEvent>.broadcast();
  final _likeController = StreamController<LikeEvent>.broadcast();
  final _commentController = StreamController<CommentEvent>.broadcast();
  final _notificationController =
      StreamController<NotificationEvent>.broadcast();
  final _friendRequestController =
      StreamController<FriendRequestEvent>.broadcast();

  // Public streams
  Stream<AchievementEvent> get achievementStream =>
      _achievementController.stream;
  Stream<LikeEvent> get likeStream => _likeController.stream;
  Stream<CommentEvent> get commentStream => _commentController.stream;
  Stream<NotificationEvent> get notificationStream =>
      _notificationController.stream;
  Stream<FriendRequestEvent> get friendRequestStream =>
      _friendRequestController.stream;

  /// Initialize real-time subscriptions for a user
  Future<void> initialize(String userId) async {
    debugPrint('🔌 Initializing real-time subscriptions for user: $userId');

    // Subscribe to achievements
    await _subscribeToAchievements(userId);

    // Subscribe to notifications
    await _subscribeToNotifications(userId);

    debugPrint('✅ Real-time service initialized');
  }

  /// Subscribe to new achievements for the user
  Future<void> _subscribeToAchievements(String userId) async {
    final channelName = 'achievements:$userId';

    if (_channels.containsKey(channelName)) return;

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_achievements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            debugPrint('🏆 New achievement earned!');
            try {
              final achievementId = payload.newRecord['achievement_id'];

              // Fetch achievement details
              final data = await _client
                  .from('achievements')
                  .select('*')
                  .eq('id', achievementId)
                  .maybeSingle();

              if (data != null) {
                _achievementController.add(AchievementEvent(
                  achievementId: achievementId,
                  name: data['name'] ?? 'Achievement',
                  description: data['description'] ?? '',
                  icon: data['icon'] ?? 'star',
                  earnedAt: DateTime.now(),
                ));
              }
            } catch (e) {
              debugPrint('❌ Error processing achievement: $e');
            }
          },
        )
        .subscribe();

    _channels[channelName] = channel;
  }

  /// Subscribe to notifications
  Future<void> _subscribeToNotifications(String userId) async {
    final channelName = 'notifications:$userId';

    if (_channels.containsKey(channelName)) return;

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('🔔 New notification!');
            _notificationController.add(NotificationEvent(
              id: payload.newRecord['id'] ?? '',
              title: payload.newRecord['title'] ?? '',
              body: payload.newRecord['body'] ?? '',
              type: payload.newRecord['type'] ?? 'system',
              createdAt: DateTime.now(),
            ));
          },
        )
        .subscribe();

    _channels[channelName] = channel;
  }

  /// Subscribe to likes on a specific post
  Future<void> subscribeToPostLikes(
      String postId, Function(int newCount) onUpdate) async {
    final channelName = 'likes:$postId';

    if (_channels.containsKey(channelName)) return;

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'post_likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) async {
            // Get updated count
            final count = await _client
                .from('post_likes')
                .select('id')
                .eq('post_id', postId)
                .count();

            onUpdate(count.count);

            _likeController.add(LikeEvent(
              postId: postId,
              newCount: count.count,
              isAdd: payload.eventType == PostgresChangeEvent.insert,
            ));
          },
        )
        .subscribe();

    _channels[channelName] = channel;
  }

  /// Unsubscribe from post likes
  Future<void> unsubscribeFromPostLikes(String postId) async {
    final channelName = 'likes:$postId';
    final channel = _channels.remove(channelName);
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  /// Subscribe to comments on a specific post
  Future<void> subscribeToPostComments(String postId,
      Function(Map<String, dynamic> comment) onNewComment) async {
    final channelName = 'comments:$postId';

    if (_channels.containsKey(channelName)) return;

    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) async {
            debugPrint('💬 New comment on post: $postId');

            // Fetch full comment with user info
            final data = await _client
                .from('post_comments')
                .select('*, user:users(*), dog:dogs(*)')
                .eq('id', payload.newRecord['id'])
                .maybeSingle();

            if (data != null) {
              onNewComment(data);
              _commentController.add(CommentEvent(
                postId: postId,
                commentId: data['id'],
                content: data['content'] ?? '',
                userId: data['user_id'],
              ));
            }
          },
        )
        .subscribe();

    _channels[channelName] = channel;
  }

  /// Unsubscribe from post comments
  Future<void> unsubscribeFromPostComments(String postId) async {
    final channelName = 'comments:$postId';
    final channel = _channels.remove(channelName);
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  /// Cleanup all subscriptions
  Future<void> dispose() async {
    for (final channel in _channels.values) {
      await _client.removeChannel(channel);
    }
    _channels.clear();

    _achievementController.close();
    _likeController.close();
    _commentController.close();
    _notificationController.close();
    _friendRequestController.close();

    debugPrint('🔌 Real-time service disposed');
  }
}

// Event classes
class AchievementEvent {
  final String achievementId;
  final String name;
  final String description;
  final String icon;
  final DateTime earnedAt;

  AchievementEvent({
    required this.achievementId,
    required this.name,
    required this.description,
    required this.icon,
    required this.earnedAt,
  });
}

class LikeEvent {
  final String postId;
  final int newCount;
  final bool isAdd;

  LikeEvent({
    required this.postId,
    required this.newCount,
    required this.isAdd,
  });
}

class CommentEvent {
  final String postId;
  final String commentId;
  final String content;
  final String userId;

  CommentEvent({
    required this.postId,
    required this.commentId,
    required this.content,
    required this.userId,
  });
}

class NotificationEvent {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;

  NotificationEvent({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
  });
}

class FriendRequestEvent {
  final String requestId;
  final String requesterDogId;
  final String requesterDogName;
  final String? requesterDogPhoto;
  final bool isNew; // true = new request, false = request accepted/declined

  FriendRequestEvent({
    required this.requestId,
    required this.requesterDogId,
    required this.requesterDogName,
    this.requesterDogPhoto,
    required this.isNew,
  });
}
