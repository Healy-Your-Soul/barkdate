import 'dart:async';

/// Simple in-memory cache service for BarkDate
/// Reduces database queries and improves performance
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache storage with expiry tracking
  final Map<String, CacheEntry> _cache = {};
  
  // Cache configuration
  static const Duration userProfileTTL = Duration(minutes: 5);
  static const Duration dogProfileTTL = Duration(minutes: 5);
  static const Duration playdateListTTL = Duration(minutes: 2);
  static const Duration eventListTTL = Duration(minutes: 2);
  static const Duration friendListTTL = Duration(minutes: 3);

  /// Get cached value
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    // Check if expired
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value as T?;
  }

  /// Set cached value with TTL
  void set<T>(String key, T value, Duration ttl) {
    _cache[key] = CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Invalidate specific cache key
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all cache entries matching a pattern
  void invalidatePattern(String pattern) {
    _cache.removeWhere((key, _) => key.contains(pattern));
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
  }

  /// Cache user profile
  void cacheUserProfile(String userId, Map<String, dynamic> profile) {
    set('user_$userId', profile, userProfileTTL);
  }

  /// Get cached user profile
  Map<String, dynamic>? getCachedUserProfile(String userId) {
    return get<Map<String, dynamic>>('user_$userId');
  }

  /// Cache dog profile
  void cacheDogProfile(String dogId, Map<String, dynamic> profile) {
    set('dog_$dogId', profile, dogProfileTTL);
  }

  /// Get cached dog profile
  Map<String, dynamic>? getCachedDogProfile(String dogId) {
    return get<Map<String, dynamic>>('dog_$dogId');
  }

  /// Cache playdate list
  void cachePlaydateList(String userId, String type, List<Map<String, dynamic>> playdates) {
    set('playdates_${userId}_$type', playdates, playdateListTTL);
  }

  /// Get cached playdate list
  List<Map<String, dynamic>>? getCachedPlaydateList(String userId, String type) {
    return get<List<Map<String, dynamic>>>('playdates_${userId}_$type');
  }

  /// Cache event list
  void cacheEventList(String key, List<dynamic> events) {
    set('events_$key', events, eventListTTL);
  }

  /// Get cached event list
  List<dynamic>? getCachedEventList(String key) {
    return get<List<dynamic>>('events_$key');
  }

  /// Cache friend list
  void cacheFriendList(String dogId, List<Map<String, dynamic>> friends) {
    set('friends_$dogId', friends, friendListTTL);
  }

  /// Get cached friend list
  List<Map<String, dynamic>>? getCachedFriendList(String dogId) {
    return get<List<Map<String, dynamic>>>('friends_$dogId');
  }

  /// Invalidate user-related caches
  void invalidateUserCaches(String userId) {
    invalidatePattern('user_$userId');
    invalidatePattern('playdates_$userId');
  }

  /// Invalidate dog-related caches
  void invalidateDogCaches(String dogId) {
    invalidatePattern('dog_$dogId');
    invalidatePattern('friends_$dogId');
  }

  /// Clean up expired entries periodically
  void cleanupExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => entry.expiresAt.isBefore(now));
  }

  /// Start periodic cleanup
  Timer? _cleanupTimer;
  
  void startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      cleanupExpired();
    });
  }

  void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}

/// Cache entry with expiration
class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  CacheEntry({
    required this.value,
    required this.expiresAt,
  });
}
