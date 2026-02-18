import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/services/event_service.dart';
import 'package:flutter/foundation.dart';

/// PreloadService warms caches right after sign-in so the Feed can render instantly.
class PreloadService {
  static Future<void> warmFeedCaches(String userId) async {
    try {
      debugPrint('🚀 Warming feed caches for user: $userId');

      // Fetch first page of nearby dogs (20 dogs)
      final nearby = await BarkDateMatchService.getNearbyDogs(
        userId,
        limit: 20,
        offset: 0,
      );
      CacheService()
          .cacheNearbyDogs(userId, List<Map<String, dynamic>>.from(nearby));
      debugPrint('  - Cached ${nearby.length} nearby dogs');

      // Fetch first page of playdates (20 playdates)
      final pd = await PlaydateQueryService.getUserPlaydatesAggregated(
        userId,
        upcomingLimit: 20,
        upcomingOffset: 0,
      );
      final upcoming =
          (pd['upcoming'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      CacheService().cachePlaydateList(userId, 'upcoming', upcoming);
      debugPrint('  - Cached ${upcoming.length} upcoming playdates');

      // Fetch first page of suggested events (20 events)
      final suggested =
          await EventService.getUpcomingEvents(limit: 20, offset: 0);
      CacheService().cacheEventList('suggested_$userId', suggested);
      debugPrint('  - Cached ${suggested.length} suggested events');

      // Fetch first page of friends (20 friends) based on user's primary dog
      try {
        final dogs = await BarkDateUserService.getUserDogs(userId);
        if (dogs.isNotEmpty) {
          final myDogId = dogs.first['id'] as String?;
          if (myDogId != null) {
            final friends = await DogFriendshipService.getDogFriends(
              myDogId,
              limit: 20,
              offset: 0,
            );
            CacheService().cacheFriendList('user_$userId', friends);
            debugPrint('  - Cached ${friends.length} friends');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Friend cache preload failed: $e');
      }

      debugPrint('✅ Feed caches warmed successfully');
    } catch (_) {
      // Preload failures should not block app startup
    }
  }
}
