import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:barkdate/core/config/app_constants.dart';

class ParkActivityService {
  static final _supabase = Supabase.instance.client;
  static bool? _isAdminCache;
  static DateTime? _adminCacheAt;
  static const _adminCacheTtl = Duration(minutes: 10);
  static const _autoSeedStartHour = 6;
  static const _autoSeedEndHour = 19;
  static const _areaKeyPrecision = 2; // ~1.1km grid

  /// Returns true if current user is a superadmin.
  /// Checks known admin emails first, then falls back to DB flag.
  static Future<bool> isAdminUser({bool forceRefresh = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    if (AppConstants.adminEmails.contains(user.email)) {
      _isAdminCache = true;
      _adminCacheAt = DateTime.now();
      return true;
    }

    if (!forceRefresh &&
        _isAdminCache != null &&
        _adminCacheAt != null &&
        DateTime.now().difference(_adminCacheAt!) < _adminCacheTtl) {
      return _isAdminCache!;
    }

    try {
      final data = await _supabase
          .from('users')
          .select('is_superadmin')
          .eq('id', user.id)
          .maybeSingle();
      final isAdmin = data?['is_superadmin'] == true;
      _isAdminCache = isAdmin;
      _adminCacheAt = DateTime.now();
      return isAdmin;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Fetches all active park reports globally
  /// Returns a map of park_id to dog_count
  static Future<Map<String, int>> getActiveParks() async {
    try {
      final response = await _supabase.rpc('get_active_parks');

      final activeParks = <String, int>{};

      if (response != null && response is List) {
        for (final row in response) {
          if (row['park_id'] != null && row['dog_count'] != null) {
            final count = row['dog_count'];
            activeParks[row['park_id']] =
                count is int ? count : (count as num).toInt();
          }
        }
      }

      return activeParks;
    } catch (e) {
      debugPrint('Error fetching active parks: $e');
      return {};
    }
  }

  static bool isWithinAutoSeedWindow({DateTime? now}) {
    final current = now ?? DateTime.now();
    return current.hour >= _autoSeedStartHour &&
        current.hour < _autoSeedEndHour;
  }

  static String buildAreaKey({
    required double latitude,
    required double longitude,
  }) {
    final lat = latitude.toStringAsFixed(_areaKeyPrecision);
    final lng = longitude.toStringAsFixed(_areaKeyPrecision);
    return '$lat:$lng';
  }

  /// Reports a specific number of dogs at a park
  static Future<bool> reportDogCount({
    required String parkId,
    required int dogCount,
    String? parkName,
    bool isAdminOverride = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase.from('park_activity_reports').insert({
        'park_id': parkId,
        'reporter_id': user.id,
        'dog_count': dogCount,
        'is_admin_override': isAdminOverride,
        'source': isAdminOverride ? 'admin' : 'user',
        if (parkName != null) 'park_name': parkName,
      });

      return true;
    } catch (e) {
      debugPrint('Error reporting park activity: $e');
      return false;
    }
  }

  static Future<bool> autoSeedParks({
    required String areaKey,
    required List<String> parkIds,
    required List<int> dogCounts,
  }) async {
    if (parkIds.isEmpty || dogCounts.isEmpty) return false;
    if (parkIds.length != dogCounts.length) return false;

    try {
      final response = await _supabase.rpc(
        'auto_seed_park_activity',
        params: {
          'p_area_key': areaKey,
          'p_park_ids': parkIds,
          'p_dog_counts': dogCounts,
        },
      );

      if (response == null) return false;
      if (response is bool) return response;
      if (response is Map && response['success'] is bool) {
        return response['success'] as bool;
      }

      return false;
    } catch (e) {
      debugPrint('Error auto-seeding parks: $e');
      return false;
    }
  }
}
