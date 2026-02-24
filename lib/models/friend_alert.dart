import 'package:flutter/material.dart';

/// Types of real-time friend activity alerts
enum FriendAlertType {
  friendCheckIn,    // A friend checked in at a park
  nearbySpot,       // Multiple dogs at a nearby location
  walkTogether,     // A friend scheduled a future walk
  newFriend,        // A friend request was accepted
  playdateStarting, // A friend's playdate is about to start
  friendPost,       // A friend shared a new post
}

/// A real-time alert about friend/pack activity
class FriendAlert {
  final String id;
  final FriendAlertType type;
  final String headline;
  final String body;
  final String? ctaLabel;
  final String? ctaRoute;
  final String? iconEmoji;
  final Color backgroundColor;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const FriendAlert({
    required this.id,
    required this.type,
    required this.headline,
    required this.body,
    this.ctaLabel,
    this.ctaRoute,
    this.iconEmoji,
    required this.backgroundColor,
    required this.createdAt,
    this.metadata,
  });

  /// Get the default background color for each alert type
  static Color colorForType(FriendAlertType type) {
    switch (type) {
      case FriendAlertType.friendCheckIn:
        return const Color(0xFF1B5E20); // Deep green
      case FriendAlertType.nearbySpot:
        return const Color(0xFF2E7D32); // Forest green
      case FriendAlertType.walkTogether:
        return const Color(0xFF0D47A1); // Deep blue
      case FriendAlertType.newFriend:
        return const Color(0xFFE65100); // Deep orange
      case FriendAlertType.playdateStarting:
        return const Color(0xFF4A148C); // Deep purple
      case FriendAlertType.friendPost:
        return const Color(0xFF880E4F); // Deep pink
    }
  }

  /// Get the default emoji for each alert type
  static String emojiForType(FriendAlertType type) {
    switch (type) {
      case FriendAlertType.friendCheckIn:
        return '📍';
      case FriendAlertType.nearbySpot:
        return '🐕';
      case FriendAlertType.walkTogether:
        return '🕐';
      case FriendAlertType.newFriend:
        return '🐶';
      case FriendAlertType.playdateStarting:
        return '🎉';
      case FriendAlertType.friendPost:
        return '📸';
    }
  }

  /// Get the default CTA label for each alert type
  static String? ctaForType(FriendAlertType type) {
    switch (type) {
      case FriendAlertType.friendCheckIn:
        return 'Say Hi';
      case FriendAlertType.nearbySpot:
        return 'Join the Pack';
      case FriendAlertType.walkTogether:
        return 'Join the Walk';
      case FriendAlertType.newFriend:
        return 'View Profile';
      case FriendAlertType.playdateStarting:
        return 'View Details';
      case FriendAlertType.friendPost:
        return 'View Post';
    }
  }

  /// Factory to create a friend check-in alert
  factory FriendAlert.friendCheckIn({
    required String id,
    required String dogName,
    required String parkName,
    String? parkId,
    double? latitude,
    double? longitude,
  }) {
    return FriendAlert(
      id: id,
      type: FriendAlertType.friendCheckIn,
      headline: 'Friend Checked In',
      body: '$dogName just checked in at $parkName!',
      ctaLabel: 'Say Hi',
      ctaRoute: parkId != null ? '/map?placeId=$parkId' : '/map',
      iconEmoji: '📍',
      backgroundColor: colorForType(FriendAlertType.friendCheckIn),
      createdAt: DateTime.now(),
      metadata: {
        'dog_name': dogName,
        'park_name': parkName,
        'park_id': parkId,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  /// Factory to create a nearby spot alert
  factory FriendAlert.nearbySpot({
    required String id,
    required String parkName,
    required int dogCount,
    String? parkId,
  }) {
    return FriendAlert(
      id: id,
      type: FriendAlertType.nearbySpot,
      headline: 'Nearby Spot',
      body: '$dogCount dogs are currently at $parkName!',
      ctaLabel: 'Join the Pack',
      ctaRoute: parkId != null ? '/map?placeId=$parkId' : '/map',
      iconEmoji: '🐕',
      backgroundColor: colorForType(FriendAlertType.nearbySpot),
      createdAt: DateTime.now(),
      metadata: {
        'park_name': parkName,
        'park_id': parkId,
        'dog_count': dogCount,
      },
    );
  }

  /// Factory to create a walk together alert
  factory FriendAlert.walkTogether({
    required String id,
    required String dogName,
    required String parkName,
    required DateTime scheduledFor,
    int joinCount = 0,
    String? parkId,
    String? checkInId,
  }) {
    final hour = scheduledFor.hour;
    final minute = scheduledFor.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '$displayHour:$minute $amPm';

    final joinStr = joinCount > 0 ? ' • $joinCount joining' : '';

    return FriendAlert(
      id: id,
      type: FriendAlertType.walkTogether,
      headline: 'Walk Together',
      body: '$dogName plans a walk at $parkName at $timeStr$joinStr',
      ctaLabel: 'Join the Walk',
      ctaRoute: '/walk-details?checkInId=$checkInId',
      iconEmoji: '🕐',
      backgroundColor: colorForType(FriendAlertType.walkTogether),
      createdAt: DateTime.now(),
      metadata: {
        'dog_name': dogName,
        'park_name': parkName,
        'park_id': parkId,
        'scheduled_for': scheduledFor.toIso8601String(),
        'check_in_id': checkInId,
        'join_count': joinCount,
      },
    );
  }

  /// Factory to create a new friend alert
  factory FriendAlert.newFriend({
    required String id,
    required String dogName,
    String? dogId,
    String? photoUrl,
  }) {
    return FriendAlert(
      id: id,
      type: FriendAlertType.newFriend,
      headline: 'New Friend',
      body: '$dogName joined your pack!',
      ctaLabel: 'View Profile',
      ctaRoute: dogId != null ? '/dog-details?dogId=$dogId' : null,
      iconEmoji: '🐶',
      backgroundColor: colorForType(FriendAlertType.newFriend),
      createdAt: DateTime.now(),
      metadata: {
        'dog_name': dogName,
        'dog_id': dogId,
        'photo_url': photoUrl,
      },
    );
  }

  /// Factory to create a playdate starting alert
  factory FriendAlert.playdateStarting({
    required String id,
    required String location,
    required DateTime startsAt,
    String? playdateId,
  }) {
    final diff = startsAt.difference(DateTime.now());
    final minutesLeft = diff.inMinutes;
    final timeStr = minutesLeft <= 0
        ? 'starting now'
        : minutesLeft < 60
            ? 'starts in ${minutesLeft}min'
            : 'starts in ${diff.inHours}h';

    return FriendAlert(
      id: id,
      type: FriendAlertType.playdateStarting,
      headline: 'Playdate Soon',
      body: 'Playdate at $location $timeStr',
      ctaLabel: 'View Details',
      ctaRoute:
          playdateId != null ? '/playdate-details?id=$playdateId' : null,
      iconEmoji: '🎉',
      backgroundColor: colorForType(FriendAlertType.playdateStarting),
      createdAt: DateTime.now(),
      metadata: {
        'location': location,
        'starts_at': startsAt.toIso8601String(),
        'playdate_id': playdateId,
      },
    );
  }

  /// Factory to create a friend post alert
  factory FriendAlert.friendPost({
    required String id,
    required String dogName,
    String? postId,
  }) {
    return FriendAlert(
      id: id,
      type: FriendAlertType.friendPost,
      headline: 'New Post',
      body: '$dogName shared a new photo',
      ctaLabel: 'View Post',
      ctaRoute: '/social-feed',
      iconEmoji: '📸',
      backgroundColor: colorForType(FriendAlertType.friendPost),
      createdAt: DateTime.now(),
      metadata: {
        'dog_name': dogName,
        'post_id': postId,
      },
    );
  }
}
