import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';

class ParkService {
  // Get nearby parks sorted by distance
  static Future<List<Map<String, dynamic>>> getNearbyParks({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    try {
      final response = await SupabaseConfig.client
          .from('parks')
          .select('*')
          .gte('latitude', latitude - (radiusKm / 111.0)) // Rough conversion
          .lte('latitude', latitude + (radiusKm / 111.0))
          .gte('longitude', longitude - (radiusKm / 111.0))
          .lte('longitude', longitude + (radiusKm / 111.0))
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching nearby parks: $e');
      return [];
    }
  }

  // Get admin-curated featured parks
  static Future<List<Map<String, dynamic>>> getFeaturedParks() async {
    try {
      final response = await SupabaseConfig.client
          .from('featured_parks')
          .select('*')
          .eq('is_active', true)
          .order('rating', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching featured parks: $e');
      return [];
    }
  }

  // Add a new featured park (admin only)
  static Future<void> addFeaturedPark(Map<String, dynamic> parkData) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      parkData['created_by'] = user.id;
      parkData['created_at'] = DateTime.now().toIso8601String();
      
      await SupabaseConfig.client
          .from('featured_parks')
          .insert(parkData);
    } catch (e) {
      debugPrint('Error adding featured park: $e');
      rethrow;
    }
  }

  // Delete a featured park
  static Future<void> deleteFeaturedPark(String parkId) async {
    try {
      await SupabaseConfig.client
          .from('featured_parks')
          .delete()
          .eq('id', parkId);
    } catch (e) {
      debugPrint('Error deleting featured park: $e');
      rethrow;
    }
  }

  // Update a featured park
  static Future<void> updateFeaturedPark(String parkId, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await SupabaseConfig.client
          .from('featured_parks')
          .update(updates)
          .eq('id', parkId);
    } catch (e) {
      debugPrint('Error updating featured park: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getParksNearby({
    double? latitude,
    double? longitude,
    double radiusKm = 50,
  }) async {
    // For MVP: return all parks (client can filter by distance)
    final data = await SupabaseConfig.client
        .from('parks')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}

class CheckinService {
  static Future<Map<String, dynamic>?> getActiveCheckin(String userId) async {
    final result = await SupabaseConfig.client
        .from('park_checkins')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('checked_in_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return result;
  }

  static Future<Map<String, dynamic>> checkIn({
    required String userId,
    required String dogId,
    required String parkId,
    double? latitude,
    double? longitude,
  }) async {
    final data = {
      'user_id': userId,
      'dog_id': dogId,
      'park_id': parkId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    final res = await SupabaseConfig.client
        .from('park_checkins')
        .insert(data)
        .select()
        .single();
    return Map<String, dynamic>.from(res);
  }

  static Future<void> checkOut(String checkinId) async {
    await SupabaseConfig.client
        .from('park_checkins')
        .update({'is_active': false, 'checked_out_at': DateTime.now().toIso8601String()})
        .eq('id', checkinId);
  }

  static Stream<List<Map<String, dynamic>>> streamActiveCheckinsForPark(String parkId) {
  return SupabaseConfig.client
    .from('park_checkins')
    .stream(primaryKey: ['id'])
    .map((rows) => rows
      .where((r) => r['park_id'] == parkId && (r['is_active'] as bool? ?? false))
      .toList());
  }
}
