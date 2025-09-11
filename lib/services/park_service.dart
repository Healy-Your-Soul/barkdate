import 'package:barkdate/supabase/supabase_config.dart';

class ParkService {
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
