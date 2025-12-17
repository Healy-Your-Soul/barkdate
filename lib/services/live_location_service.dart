import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barkdate/services/location_service.dart';

/// Service for managing live location streaming
/// Uses Geolocator position stream with 30-second updates
class LiveLocationService {
  static LiveLocationService? _instance;
  static LiveLocationService get instance {
    _instance ??= LiveLocationService._();
    return _instance!;
  }

  LiveLocationService._();

  StreamSubscription<Position>? _positionSubscription;
  String? _currentUserId;
  bool _isTracking = false;

  /// Whether live tracking is currently active
  bool get isTracking => _isTracking;

  /// Start live location tracking for a user
  /// Updates location every 30 seconds
  Future<bool> startLiveTracking(String userId, {String privacy = 'friends'}) async {
    if (_isTracking) {
      debugPrint('⚠️ Live tracking already active');
      return true;
    }

    try {
      // Check permissions first
      final permissionInfo = await LocationService.checkPermissionStatus();
      if (permissionInfo.status != LocationStatus.enabled) {
        debugPrint('❌ Location permission not granted');
        return false;
      }

      _currentUserId = userId;

      // Set privacy setting
      await LocationService.setLiveLocationPrivacy(userId, privacy);

      // Get initial position and update immediately
      final initialPosition = await LocationService.getCurrentLocation();
      if (initialPosition != null) {
        await LocationService.updateLiveLocation(
          userId,
          initialPosition.latitude,
          initialPosition.longitude,
        );
      }

      // Start position stream with 30-second interval
      // Note: distanceFilter of 0 means we get updates based on time, not distance
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // minimum 10 meters before update
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          if (_currentUserId != null) {
            await LocationService.updateLiveLocation(
              _currentUserId!,
              position.latitude,
              position.longitude,
            );
          }
        },
        onError: (error) {
          debugPrint('❌ Position stream error: $error');
        },
      );

      _isTracking = true;
      debugPrint('✅ Started live location tracking for user: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting live tracking: $e');
      return false;
    }
  }

  /// Stop live location tracking
  Future<void> stopLiveTracking() async {
    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      if (_currentUserId != null) {
        await LocationService.stopLiveSharing(_currentUserId!);
        _currentUserId = null;
      }

      _isTracking = false;
      debugPrint('🛑 Stopped live location tracking');
    } catch (e) {
      debugPrint('❌ Error stopping live tracking: $e');
    }
  }

  /// Update privacy setting while tracking is active
  Future<void> updatePrivacy(String privacy) async {
    if (_currentUserId != null) {
      await LocationService.setLiveLocationPrivacy(_currentUserId!, privacy);
    }
  }

  /// Clean up resources
  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _currentUserId = null;
  }
}
