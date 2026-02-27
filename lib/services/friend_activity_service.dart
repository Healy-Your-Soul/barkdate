import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barkdate/models/friend_alert.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';

/// Service that aggregates real-time friend activity into FriendAlerts.
/// Queries existing tables: checkins, dog_friendships, posts, playdates.
class FriendActivityService {
  /// Get all current alerts for a user (combined from all sources)
  static Future<List<FriendAlert>> getAlerts(String userId) async {
    try {
      // Get user's primary dog
      final dogs = await BarkDateUserService.getUserDogs(userId);
      if (dogs.isEmpty) return [];

      final myDogId = dogs.first['id'] as String;

      // Get friend dog IDs
      final friends = await DogFriendshipService.getFriends(myDogId);
      if (friends.isEmpty) return [];

      final friendDogIds = <String>[];
      final friendUserIds = <String>[];

      for (final f in friends) {
        final dogData = f['dog'] as Map<String, dynamic>?;
        final friendDogData = f['friend_dog'] as Map<String, dynamic>?;

        if (dogData != null && dogData['id'] != myDogId) {
          friendDogIds.add(dogData['id'] as String);
          if (dogData['user_id'] != null) {
            friendUserIds.add(dogData['user_id'] as String);
          }
        }
        if (friendDogData != null && friendDogData['id'] != myDogId) {
          friendDogIds.add(friendDogData['id'] as String);
          if (friendDogData['user_id'] != null) {
            friendUserIds.add(friendDogData['user_id'] as String);
          }
        }
      }

      if (friendDogIds.isEmpty) return [];

      // Fetch all alert sources concurrently
      final results = await Future.wait([
        _getFriendCheckInAlerts(friendUserIds, friendDogIds),
        _getNearbySpotAlerts(),
        _getScheduledWalkAlerts(friendUserIds, friendDogIds),
        _getNewFriendAlerts(myDogId),
        _getUpcomingPlaydateAlerts(userId),
        _getFriendPostAlerts(friendDogIds),
      ]);

      final allAlerts = <FriendAlert>[];
      for (final list in results) {
        allAlerts.addAll(list);
      }

      // Sort by most recent first
      allAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Limit to 10 most recent
      final result = allAlerts.take(10).toList();

      // If no real alerts, show demo cards so users can see the UI
      if (result.isEmpty) {
        return _getDemoAlerts();
      }

      return result;
    } catch (e) {
      debugPrint('Error getting friend alerts: $e');
      return [];
    }
  }

  /// Get active check-ins from friends
  static Future<List<FriendAlert>> _getFriendCheckInAlerts(
      List<String> friendUserIds, List<String> friendDogIds) async {
    try {
      if (friendUserIds.isEmpty) return [];

      final cutoffTime =
          DateTime.now().subtract(const Duration(hours: 4)).toIso8601String();

      final data = await SupabaseConfig.client
          .from('checkins')
          .select('''
            *,
            dog:dog_id (
              id, name, breed, main_photo_url
            )
          ''')
          .inFilter('user_id', friendUserIds)
          .eq('status', 'active')
          .gte('checked_in_at', cutoffTime)
          .order('checked_in_at', ascending: false)
          .limit(5);

      return (data as List).map((checkIn) {
        final dog = checkIn['dog'] as Map<String, dynamic>?;
        final dogName = dog?['name'] ?? 'A friend';
        final parkName = checkIn['park_name'] ?? 'a park';

        return FriendAlert.friendCheckIn(
          id: 'checkin_${checkIn['id']}',
          dogName: dogName,
          parkName: parkName,
          parkId: checkIn['park_id'],
          latitude: checkIn['latitude'] as double?,
          longitude: checkIn['longitude'] as double?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching friend check-in alerts: $e');
      return [];
    }
  }

  /// Get nearby spots with 2+ dogs
  static Future<List<FriendAlert>> _getNearbySpotAlerts() async {
    try {
      final cutoffTime =
          DateTime.now().subtract(const Duration(hours: 4)).toIso8601String();

      // Get all active check-ins grouped by park
      final data = await SupabaseConfig.client
          .from('checkins')
          .select('park_id, park_name')
          .eq('status', 'active')
          .gte('checked_in_at', cutoffTime);

      // Group by park and count
      final parkCounts = <String, Map<String, dynamic>>{};
      for (final row in data) {
        final parkId = row['park_id'] as String;
        if (!parkCounts.containsKey(parkId)) {
          parkCounts[parkId] = {
            'park_id': parkId,
            'park_name': row['park_name'] ?? 'Unknown Park',
            'count': 0,
          };
        }
        parkCounts[parkId]!['count'] =
            (parkCounts[parkId]!['count'] as int) + 1;
      }

      // Only include parks with 2+ dogs
      return parkCounts.values
          .where((p) => (p['count'] as int) >= 2)
          .take(3)
          .map((p) => FriendAlert.nearbySpot(
                id: 'spot_${p['park_id']}',
                parkName: p['park_name'] as String,
                dogCount: p['count'] as int,
                parkId: p['park_id'] as String?,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching nearby spot alerts: $e');
      return [];
    }
  }

  /// Get scheduled walks from friends
  static Future<List<FriendAlert>> _getScheduledWalkAlerts(
      List<String> friendUserIds, List<String> friendDogIds) async {
    try {
      if (friendUserIds.isEmpty) return [];

      final now = DateTime.now().toIso8601String();

      final data = await SupabaseConfig.client
          .from('checkins')
          .select('''
            *,
            dog:dog_id (
              id, name, breed, main_photo_url
            )
          ''')
          .inFilter('user_id', friendUserIds)
          .eq('status', 'scheduled')
          .eq('is_future_checkin', true)
          .gte('scheduled_for', now)
          .order('scheduled_for', ascending: true)
          .limit(5);

      final alerts = <FriendAlert>[];

      for (final walk in data) {
        final dog = walk['dog'] as Map<String, dynamic>?;
        final dogName = dog?['name'] ?? 'A friend';
        final parkName = walk['park_name'] ?? 'a park';
        final scheduledFor =
            DateTime.tryParse(walk['scheduled_for'] ?? '') ?? DateTime.now();
        final checkInId = walk['id'] as String;
        final parkId = walk['park_id'] as String?;

        // Get join count for this walk
        int joinCount = 0;
        try {
          joinCount = await _getWalkJoinCount(parkId ?? '', scheduledFor);
        } catch (_) {}

        alerts.add(FriendAlert.walkTogether(
          id: 'walk_$checkInId',
          dogName: dogName,
          parkName: parkName,
          scheduledFor: scheduledFor,
          joinCount: joinCount,
          parkId: parkId,
          checkInId: checkInId,
        ));
      }

      return alerts;
    } catch (e) {
      debugPrint('Error fetching scheduled walk alerts: $e');
      return [];
    }
  }

  /// Count how many people are joining a scheduled walk (same park, within 30min)
  static Future<int> _getWalkJoinCount(
      String parkId, DateTime scheduledFor) async {
    try {
      final windowStart =
          scheduledFor.subtract(const Duration(minutes: 30)).toIso8601String();
      final windowEnd =
          scheduledFor.add(const Duration(minutes: 30)).toIso8601String();

      final data = await SupabaseConfig.client
          .from('checkins')
          .select('id')
          .eq('park_id', parkId)
          .eq('status', 'scheduled')
          .gte('scheduled_for', windowStart)
          .lte('scheduled_for', windowEnd);

      // Subtract 1 because the original planner is included
      return (data as List).length > 1 ? (data.length - 1) : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get recently accepted friend requests (last 24h)
  static Future<List<FriendAlert>> _getNewFriendAlerts(String myDogId) async {
    try {
      final cutoffTime =
          DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();

      final data = await SupabaseConfig.client
          .from('dog_friendships')
          .select('''
            *,
            dog:dog_id (id, name, main_photo_url, user_id),
            friend_dog:friend_dog_id (id, name, main_photo_url, user_id)
          ''')
          .or('dog_id.eq.$myDogId,friend_dog_id.eq.$myDogId')
          .eq('status', 'accepted')
          .gte('updated_at', cutoffTime)
          .order('updated_at', ascending: false)
          .limit(3);

      return (data as List).map((friendship) {
        // Determine which dog is the friend (not me)
        final dogData = friendship['dog'] as Map<String, dynamic>?;
        final friendDogData = friendship['friend_dog'] as Map<String, dynamic>?;

        Map<String, dynamic>? friendDog;
        if (dogData != null && dogData['id'] != myDogId) {
          friendDog = dogData;
        } else if (friendDogData != null && friendDogData['id'] != myDogId) {
          friendDog = friendDogData;
        }

        return FriendAlert.newFriend(
          id: 'friend_${friendship['id']}',
          dogName: friendDog?['name'] ?? 'A new friend',
          dogId: friendDog?['id'] as String?,
          photoUrl: friendDog?['main_photo_url'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching new friend alerts: $e');
      return [];
    }
  }

  /// Get upcoming playdates starting within 2 hours
  static Future<List<FriendAlert>> _getUpcomingPlaydateAlerts(
      String userId) async {
    try {
      final now = DateTime.now();
      final twoHoursFromNow = now.add(const Duration(hours: 2));

      final data = await SupabaseConfig.client
          .from('playdates')
          .select('id, location, scheduled_at, status')
          .or('organizer_id.eq.$userId')
          .inFilter('status', ['confirmed', 'pending'])
          .gte('scheduled_at', now.toIso8601String())
          .lte('scheduled_at', twoHoursFromNow.toIso8601String())
          .order('scheduled_at', ascending: true)
          .limit(3);

      return (data as List).map((playdate) {
        final dateStr = playdate['scheduled_at'] ?? '';
        final startsAt = DateTime.tryParse(dateStr) ?? DateTime.now();

        return FriendAlert.playdateStarting(
          id: 'playdate_${playdate['id']}',
          location: playdate['location'] ?? 'Unknown location',
          startsAt: startsAt,
          playdateId: playdate['id'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching upcoming playdate alerts: $e');
      return [];
    }
  }

  /// Get recent friend posts (last 24h)
  static Future<List<FriendAlert>> _getFriendPostAlerts(
      List<String> friendDogIds) async {
    try {
      if (friendDogIds.isEmpty) return [];

      final cutoffTime =
          DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();

      final data = await SupabaseConfig.client
          .from('posts')
          .select('''
            id, created_at,
            dog:dog_id (id, name, main_photo_url)
          ''')
          .inFilter('dog_id', friendDogIds)
          .gte('created_at', cutoffTime)
          .order('created_at', ascending: false)
          .limit(3);

      return (data as List).map((post) {
        final dog = post['dog'] as Map<String, dynamic>?;
        return FriendAlert.friendPost(
          id: 'post_${post['id']}',
          dogName: dog?['name'] ?? 'A friend',
          postId: post['id'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching friend post alerts: $e');
      return [];
    }
  }

  /// Get scheduled walks for the map (includes ALL upcoming scheduled walks)
  static Future<List<Map<String, dynamic>>> getScheduledWalksForMap() async {
    try {
      final now = DateTime.now().toIso8601String();

      final data = await SupabaseConfig.client
          .from('checkins')
          .select('''
            *,
            user:user_id (id, name, avatar_url),
            dog:dog_id (id, name, breed, main_photo_url)
          ''')
          .eq('status', 'scheduled')
          .eq('is_future_checkin', true)
          .gte('scheduled_for', now)
          .order('scheduled_for', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting scheduled walks for map: $e');
      return [];
    }
  }

  /// Join a friend's scheduled walk
  static Future<bool> joinScheduledWalk({
    required String parkId,
    required String parkName,
    required DateTime scheduledFor,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final result = await CheckInService.scheduleFutureCheckIn(
        parkId: parkId,
        parkName: parkName,
        scheduledFor: scheduledFor,
        latitude: latitude,
        longitude: longitude,
      );
      return result != null;
    } catch (e) {
      debugPrint('Error joining scheduled walk: $e');
      return false;
    }
  }

  /// Get participants for a specific scheduled walk
  static Future<List<Map<String, dynamic>>> getWalkParticipants(
      String parkId, DateTime scheduledFor) async {
    try {
      final windowStart =
          scheduledFor.subtract(const Duration(minutes: 30)).toIso8601String();
      final windowEnd =
          scheduledFor.add(const Duration(minutes: 30)).toIso8601String();

      final data = await SupabaseConfig.client
          .from('checkins')
          .select('''
            *,
            user:user_id (id, name, avatar_url),
            dog:dog_id (id, name, breed, main_photo_url)
          ''')
          .eq('park_id', parkId)
          .eq('status', 'scheduled')
          .gte('scheduled_for', windowStart)
          .lte('scheduled_for', windowEnd)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting walk participants: $e');
      return [];
    }
  }

  /// Demo alerts shown when no real friend activity exists.
  /// Lets users see the carousel UI immediately.
  static List<FriendAlert> _getDemoAlerts() {
    final now = DateTime.now();
    return [
      FriendAlert.nearbySpot(
        id: 'demo_spot',
        parkName: 'Central Park',
        dogCount: 3,
      ),
      FriendAlert.walkTogether(
        id: 'demo_walk',
        dogName: 'Luna',
        parkName: 'Riverside Dog Park',
        scheduledFor: now.add(const Duration(hours: 2)),
        joinCount: 2,
      ),
      FriendAlert.friendCheckIn(
        id: 'demo_checkin',
        dogName: 'Max',
        parkName: 'Hyde Park',
      ),
      FriendAlert.newFriend(
        id: 'demo_friend',
        dogName: 'Buddy',
      ),
      FriendAlert.friendPost(
        id: 'demo_post',
        dogName: 'Rocky',
      ),
    ];
  }
}
