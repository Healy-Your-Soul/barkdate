import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';

class FeedService {
  FeedService._();

  static final CacheService _cache = CacheService();

  /// Returns a cached feed snapshot when available.
  /// When [forceRefresh] is true, data is always fetched from Supabase.
  static Future<Map<String, dynamic>> getFeedSnapshot(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getCachedFeedSnapshot(userId);
      if (cached != null) {
        return Map<String, dynamic>.from(cached);
      }
    }

    try {
      final result = await SupabaseConfig.client.rpc(
        'get_feed_snapshot',
        params: {
          'p_user_id': userId,
        },
      );

      if (result == null) {
        return <String, dynamic>{};
      }

      final snapshot = Map<String, dynamic>.from(result as Map);
      _cache.cacheFeedSnapshot(userId, snapshot);
      return snapshot;
    } catch (e, stack) {
      debugPrint('Error loading feed snapshot: $e\n$stack');
      return <String, dynamic>{};
    }
  }

  /// Force refresh, bypassing cache.
  static Future<Map<String, dynamic>> refreshFeedSnapshot(String userId) {
    return getFeedSnapshot(userId, forceRefresh: true);
  }
}
