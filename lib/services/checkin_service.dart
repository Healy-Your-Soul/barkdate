import 'package:barkdate/models/checkin.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:flutter/material.dart';

class CheckInService {
  /// Check in at a park (current location or manual)
  static Future<CheckIn?> checkInAtPark({
    required String parkId,
    required String parkName,
    double? latitude,
    double? longitude,
    bool isFutureCheckin = false,
    DateTime? scheduledFor,
  }) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user's first dog for check-in
      final dogs = await BarkDateUserService.getUserDogs(user.id);
      if (dogs.isEmpty) {
        throw Exception('Please create a dog profile first');
      }

      final dogId = dogs.first['id'] as String;

      // Check if user already has an active check-in
      final activeCheckIn = await getActiveCheckIn(user.id);
      if (activeCheckIn != null && !isFutureCheckin) {
        throw Exception(
            'You already have an active check-in at ${activeCheckIn.parkName}');
      }

      final now = DateTime.now();
      final checkInData = {
        'user_id': user.id,
        'dog_id': dogId,
        'park_id': parkId,
        'park_name': parkName,
        'checked_in_at': now.toIso8601String(),
        'status': isFutureCheckin ? 'scheduled' : 'active',
        'is_future_checkin': isFutureCheckin,
        'scheduled_for': scheduledFor?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      };

      final data = await SupabaseConfig.client
          .from('checkins')
          .insert(checkInData)
          .select()
          .single();

      return CheckIn.fromJson(data);
    } catch (e) {
      debugPrint('Error checking in: $e');
      return null;
    }
  }

  /// Check out from current park
  static Future<bool> checkOut() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      debugPrint('🚪 CheckInService.checkOut() called');
      debugPrint('🚪 User: ${user?.id}');
      if (user == null) {
        debugPrint('🚪 No user logged in!');
        return false;
      }

      final now = DateTime.now();
      debugPrint('🚪 Updating checkins with status=active for user ${user.id}');

      final data = await SupabaseConfig.client
          .from('checkins')
          .update({
            'checked_out_at': now.toIso8601String(),
            'status': 'completed',
          })
          .eq('user_id', user.id)
          .eq('status', 'active')
          .select();

      debugPrint('🚪 Checkout result: ${data.length} rows updated');
      debugPrint('🚪 Data: $data');

      return data.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking out: $e');
      return false;
    }
  }

  /// Get user's active check-in (auto-expires after 4 hours)
  static Future<CheckIn?> getActiveCheckIn(String userId) async {
    try {
      // Check-ins older than 4 hours are considered expired
      final cutoffTime =
          DateTime.now().subtract(const Duration(hours: 4)).toIso8601String();

      final data = await SupabaseConfig.client
          .from('checkins')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('checked_in_at', cutoffTime) // Only within last 3 hours
          .order('checked_in_at', ascending: false)
          .limit(1);

      if (data.isEmpty) return null;
      return CheckIn.fromJson(data.first);
    } catch (e) {
      debugPrint('Error getting active check-in: $e');
      return null;
    }
  }

  /// Get user's check-in history
  static Future<List<CheckIn>> getCheckInHistory(String userId,
      {int limit = 20}) async {
    try {
      final data = await SupabaseConfig.client
          .from('checkins')
          .select()
          .eq('user_id', userId)
          .order('checked_in_at', ascending: false)
          .limit(limit);

      return data.map((json) => CheckIn.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting check-in history: $e');
      return [];
    }
  }

  /// Get current dog count at a specific park
  static Future<int> getParkDogCount(String parkId) async {
    try {
      final data = await SupabaseConfig.client
          .from('checkins')
          .select('id')
          .eq('park_id', parkId)
          .eq('status', 'active');

      return data.length;
    } catch (e) {
      debugPrint('Error getting park dog count: $e');
      return 0;
    }
  }

  /// Get real-time dog counts for all parks
  static Future<Map<String, int>> getAllParkDogCounts() async {
    try {
      final data = await SupabaseConfig.client
          .from('checkins')
          .select('park_id')
          .eq('status', 'active');

      final Map<String, int> counts = {};
      for (final item in data) {
        final parkId = item['park_id'] as String;
        counts[parkId] = (counts[parkId] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('Error getting all park dog counts: $e');
      return {};
    }
  }

  /// Get dog counts for multiple specific places (optimized for map viewport)
  static Future<Map<String, int>> getPlaceDogCounts(
      List<String> placeIds) async {
    try {
      if (placeIds.isEmpty) return {};

      // Build OR filter for multiple place IDs
      final orFilter = placeIds.map((id) => 'park_id.eq.$id').join(',');

      final data = await SupabaseConfig.client
          .from('checkins')
          .select('park_id')
          .or(orFilter)
          .eq('status', 'active');

      final Map<String, int> counts = {};
      for (final item in data) {
        final parkId = item['park_id'] as String;
        counts[parkId] = (counts[parkId] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('Error getting place dog counts: $e');
      return {};
    }
  }

  /// Get active check-ins with user details for a specific place
  /// Auto-expires check-ins older than 3 hours
  static Future<List<Map<String, dynamic>>> getActiveCheckInsAtPlace(
      String placeId) async {
    try {
      // Calculate cutoff time (3 hours ago)
      final cutoffTime =
          DateTime.now().subtract(const Duration(hours: 3)).toIso8601String();

      final data = await SupabaseConfig.client
          .from('checkins')
          .select('''
            *,
            user:user_id (
              id,
              name,
              avatar_url
            ),
            dog:dog_id (
              id,
              name,
              breed,
              main_photo_url
            )
          ''')
          .eq('park_id', placeId)
          .eq('status', 'active')
          .gte('checked_in_at', cutoffTime) // Only check-ins from last 3 hours
          .order('checked_in_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting all active check-ins: $e');
      return [];
    }
  }

  /// Get ALL active check-ins globally with user/dog details (for map markers)
  /// Excludes current user's check-in, auto-expires after 4 hours
  static Future<List<Map<String, dynamic>>> getAllActiveCheckIns(
      {String? excludeUserId}) async {
    try {
      // Calculate cutoff time (4 hours ago)
      final cutoffTime =
          DateTime.now().subtract(const Duration(hours: 4)).toIso8601String();

      var query = SupabaseConfig.client.from('checkins').select('''
            *,
            user:user_id (
              id,
              name,
              avatar_url
            ),
            dog:dog_id (
              id,
              name,
              breed,
              main_photo_url
            )
          ''').eq('status', 'active').gte('checked_in_at', cutoffTime);

      // Exclude current user if specified
      if (excludeUserId != null) {
        query = query.neq('user_id', excludeUserId);
      }

      final data = await query.order('checked_in_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting all active check-ins: $e');
      return [];
    }
  }

  /// Get nearby parks with dog counts
  static Future<List<Map<String, dynamic>>> getNearbyParksWithCounts({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // Get nearby parks (this would need to be implemented in your park service)
      // For now, we'll get all parks and calculate dog counts
      final parkCounts = await getAllParkDogCounts();

      // This is a simplified version - you'd want to integrate with your actual park service
      final List<Map<String, dynamic>> parksWithCounts = [];

      for (final entry in parkCounts.entries) {
        parksWithCounts.add({
          'park_id': entry.key,
          'dog_count': entry.value,
        });
      }

      return parksWithCounts;
    } catch (e) {
      debugPrint('Error getting nearby parks with counts: $e');
      return [];
    }
  }

  /// Schedule a future check-in
  static Future<CheckIn?> scheduleFutureCheckIn({
    required String parkId,
    required String parkName,
    required DateTime scheduledFor,
    double? latitude,
    double? longitude,
  }) async {
    return await checkInAtPark(
      parkId: parkId,
      parkName: parkName,
      latitude: latitude,
      longitude: longitude,
      isFutureCheckin: true,
      scheduledFor: scheduledFor,
    );
  }

  /// Cancel a scheduled check-in
  static Future<bool> cancelScheduledCheckIn(String checkInId) async {
    try {
      final data = await SupabaseConfig.client
          .from('checkins')
          .update({'status': 'cancelled'})
          .eq('id', checkInId)
          .eq('status', 'scheduled')
          .select();

      return data.isNotEmpty;
    } catch (e) {
      debugPrint('Error cancelling scheduled check-in: $e');
      return false;
    }
  }

  /// Get scheduled check-ins for user
  static Future<List<CheckIn>> getScheduledCheckIns(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('checkins')
          .select()
          .eq('user_id', userId)
          .eq('status', 'scheduled')
          .gte('scheduled_for', DateTime.now().toIso8601String())
          .order('scheduled_for', ascending: true);

      return data.map((json) => CheckIn.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting scheduled check-ins: $e');
      return [];
    }
  }

  /// Auto-checkout inactive users (called by background job)
  static Future<void> autoCheckoutInactiveUsers(
      {Duration maxDuration = const Duration(hours: 4)}) async {
    try {
      final cutoffTime = DateTime.now().subtract(maxDuration);

      await SupabaseConfig.client
          .from('checkins')
          .update({
            'checked_out_at': DateTime.now().toIso8601String(),
            'status': 'completed',
          })
          .eq('status', 'active')
          .lt('checked_in_at', cutoffTime.toIso8601String());
    } catch (e) {
      debugPrint('Error auto-checking out users: $e');
    }
  }

  /// Get check-in statistics for user
  static Future<Map<String, dynamic>> getCheckInStats(String userId) async {
    try {
      final history = await getCheckInHistory(userId, limit: 100);

      int totalCheckIns = history.length;
      int totalHours = 0;
      String favoritePark = '';
      Map<String, int> parkVisits = {};

      for (final checkIn in history) {
        if (checkIn.isCompleted && checkIn.duration != null) {
          totalHours += checkIn.duration!.inHours;
        }

        parkVisits[checkIn.parkName] = (parkVisits[checkIn.parkName] ?? 0) + 1;
      }

      if (parkVisits.isNotEmpty) {
        favoritePark =
            parkVisits.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      return {
        'total_checkins': totalCheckIns,
        'total_hours': totalHours,
        'favorite_park': favoritePark,
        'park_visits': parkVisits,
      };
    } catch (e) {
      debugPrint('Error getting check-in stats: $e');
      return {};
    }
  }
}
