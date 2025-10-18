import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/services/event_service.dart';

/// PreloadService warms caches right after sign-in so the Feed can render instantly.
class PreloadService {
  static Future<void> warmFeedCaches(String userId) async {
    try {
      // Nearby dogs raw rows
      final nearby = await BarkDateMatchService.getNearbyDogs(userId);
      CacheService().cacheNearbyDogs(userId, List<Map<String, dynamic>>.from(nearby));

      // Playdates aggregated
      final pd = await PlaydateQueryService.getUserPlaydatesAggregated(userId);
      final upcoming = (pd['upcoming'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
      CacheService().cachePlaydateList(userId, 'upcoming', upcoming);

      // Events: my + suggested/upcoming
      final myEvents = await EventService.getUserParticipatingEvents(userId);
      final suggested = await EventService.getUpcomingEvents(limit: 8);
      CacheService().cacheEventList('suggested_$userId', suggested);

      // Friends list based on user's primary dog
      try {
        final dogs = await BarkDateUserService.getUserDogs(userId);
        if (dogs.isNotEmpty) {
          final myDogId = dogs.first['id'] as String?;
          if (myDogId != null) {
            final friends = await DogFriendshipService.getDogFriends(myDogId);
            CacheService().cacheFriendList('user_$userId', friends);
          }
        }
      } catch (_) {}
    } catch (_) {
      // Preload failures should not block app startup
    }
  }
}


