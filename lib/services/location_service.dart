import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationStatus {
  enabled,
  disabled,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unknown,
}

class LocationPermissionInfo {
  final LocationStatus status;
  final String message;
  final bool canRequestPermission;
  final bool needsSystemSettings;

  const LocationPermissionInfo({
    required this.status,
    required this.message,
    required this.canRequestPermission,
    required this.needsSystemSettings,
  });
}

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
      CacheService()
        ..invalidate('nearby_$userId')
        ..invalidateFeedSnapshot(userId);
    } catch (e) {
      debugPrint('❌ Error updating user location: $e');
    }
  }

  /// Disable location for a user and their dogs
  static Future<void> disableLocation(String userId) async {
    try {
      await SupabaseConfig.client
          .from('users')
          .update({
            'latitude': null,
            'longitude': null,
            'location_updated_at': null,
          })
          .eq('id', userId);

      await SupabaseConfig.client
          .from('dogs')
          .update({
            'latitude': null,
            'longitude': null,
          })
          .eq('user_id', userId);

      CacheService()
        ..invalidate('nearby_$userId')
        ..invalidateFeedSnapshot(userId);
      debugPrint('✅ Disabled location sharing for user and dogs');
    } catch (e) {
      debugPrint('❌ Error disabling location: $e');
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

  /// Check detailed location permission status (Phase 4)
  static Future<LocationPermissionInfo> checkPermissionStatus() async {
    try {
      // Check if location services are enabled on the device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationPermissionInfo(
          status: LocationStatus.serviceDisabled,
          message: 'Location services are disabled on your device. Please enable them in system settings.',
          canRequestPermission: false,
          needsSystemSettings: true,
        );
      }

      // Check app permission
      final permission = await Geolocator.checkPermission();
      
      switch (permission) {
        case LocationPermission.denied:
          return const LocationPermissionInfo(
            status: LocationStatus.permissionDenied,
            message: 'Location permission is required to find nearby dogs and events.',
            canRequestPermission: true,
            needsSystemSettings: false,
          );
        
        case LocationPermission.deniedForever:
          return const LocationPermissionInfo(
            status: LocationStatus.permissionDeniedForever,
            message: 'Location permission was permanently denied. Please enable it in app settings.',
            canRequestPermission: false,
            needsSystemSettings: true,
          );
        
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return const LocationPermissionInfo(
            status: LocationStatus.enabled,
            message: 'Location services are working properly.',
            canRequestPermission: false,
            needsSystemSettings: false,
          );
        
        default:
          return const LocationPermissionInfo(
            status: LocationStatus.unknown,
            message: 'Unable to determine location status.',
            canRequestPermission: true,
            needsSystemSettings: false,
          );
      }
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return const LocationPermissionInfo(
        status: LocationStatus.unknown,
        message: 'Error checking location permissions.',
        canRequestPermission: false,
        needsSystemSettings: false,
      );
    }
  }

  /// Request location permission
  static Future<bool> requestPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse ||
             permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  /// Open app settings (for when permission is denied forever)
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Open location settings (for when service is disabled)
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
      return false;
    }
  }

  /// Check if user has location enabled in database
  static Future<bool> isLocationEnabled(String userId) async {
    try {
      final location = await getUserLocation(userId);
      return location != null;
    } catch (e) {
      debugPrint('Error checking if location enabled: $e');
      return false;
    }
  }

  /// Sync location - get current position and update database
  static Future<bool> syncLocation(String userId) async {
    try {
      final position = await getCurrentLocation();
      if (position == null) {
        return false;
      }

      await updateUserLocation(
        userId,
        position.latitude,
        position.longitude,
      );
      
      return true;
    } catch (e) {
      debugPrint('Error syncing location: $e');
      return false;
    }
  }
}
