import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Get current device location
  static Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services are disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission permanently denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint('📍 Got location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  /// Update user location in database and propagate to owned dogs
  static Future<void> updateUserLocation(
    String userId,
    double latitude,
    double longitude,
  ) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      await SupabaseConfig.client
          .from('users')
          .update({
        'latitude': latitude,
        'longitude': longitude,
        'location_updated_at': timestamp,
      }).eq('id', userId);

      // Update owned dogs to inherit the new location
      await SupabaseConfig.client
          .from('dogs')
          .update({
        'latitude': latitude,
        'longitude': longitude,
      }).eq('user_id', userId);

      debugPrint('✅ Updated user and dog locations in database');
    } catch (e) {
      debugPrint('❌ Error updating user location: $e');
    }
  }

  /// Get user's stored location from database
  static Future<Map<String, double>?> getUserLocation(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('latitude, longitude, search_radius_km')
          .eq('id', userId)
          .single();

      final latitude = response['latitude'];
      final longitude = response['longitude'];
      if (latitude == null || longitude == null) {
        return null;
      }

      return {
        'latitude': (latitude as num).toDouble(),
        'longitude': (longitude as num).toDouble(),
      };
    } catch (e) {
      debugPrint('❌ Error getting user location: $e');
      return null;
    }
  }
}
