import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:barkdate/models/notification.dart';

/// Service for handling notification sounds and haptic feedback
/// Provides different sound patterns for different notification types
class NotificationSoundService {
  static const MethodChannel _channel = MethodChannel('notification_sounds');
  static bool _isSupported = true;
  
  // Sound file paths (to be added to assets)
  static final Map<NotificationType, String> _soundPaths = {
    NotificationType.bark: 'sounds/bark_notification.mp3',
    NotificationType.playdateRequest: 'sounds/playdate_invite.mp3',
    NotificationType.playdate: 'sounds/playdate_response.mp3',
    NotificationType.match: 'sounds/match_found.mp3',
    NotificationType.message: 'sounds/message_received.mp3',
    NotificationType.social: 'sounds/social_notification.mp3',
    NotificationType.system: 'sounds/general_notification.mp3',
  };
  
  // Haptic feedback patterns
  static final Map<NotificationType, List<int>> _hapticPatterns = {
    NotificationType.bark: [100, 50, 100], // Playful pattern
    NotificationType.playdateRequest: [200, 100, 200, 100, 200], // Exciting pattern
    NotificationType.playdate: [150], // Simple single vibration
    NotificationType.match: [300, 100, 300], // Strong match pattern
    NotificationType.message: [100], // Simple message vibration
    NotificationType.social: [150, 50, 150], // Social interaction pattern
    NotificationType.system: [100], // Default vibration
  };
  
  /// Initialize the sound service
  static Future<void> initialize() async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod('initialize');
    } on MissingPluginException {
      _isSupported = false;
      if (kDebugMode) {
        print('NotificationSoundService: Native plugin not found. Falling back to simple sounds.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize notification sound service: $e');
      }
    }
  }
  
  /// Play notification sound for the given notification type
  static Future<void> playNotificationSound(NotificationType type) async {
    // If native plugin is not supported or failed previously, fallback immediately
    if (!_isSupported) {
       await SimpleSoundService.playSystemSound();
       return;
    }

    try {
      final soundPath = _soundPaths[type] ?? _soundPaths[NotificationType.system]!;
      await _channel.invokeMethod('playSound', {'path': soundPath});
    } on MissingPluginException {
      _isSupported = false;
      await SimpleSoundService.playSystemSound();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to play notification sound: $e');
      }
      // Fallback to system sound
      await HapticFeedback.mediumImpact();
    }
  }
  
  /// Trigger haptic feedback for the given notification type
  static Future<void> triggerHapticFeedback(NotificationType type) async {
    if (!_isSupported) {
      await SimpleSoundService.playHapticForType(type);
      return;
    }

    try {
      final pattern = _hapticPatterns[type] ?? _hapticPatterns[NotificationType.system]!;
      
      if (pattern.length == 1) {
        // Simple vibration
        await HapticFeedback.mediumImpact();
      } else {
        // Custom pattern (requires platform-specific implementation)
        await _channel.invokeMethod('vibratePattern', {'pattern': pattern});
      }
    } on MissingPluginException {
      _isSupported = false;
      await SimpleSoundService.playHapticForType(type);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to trigger haptic feedback: $e');
      }
      // Fallback to simple haptic
      await HapticFeedback.lightImpact();
    }
  }
  
  /// Play both sound and haptic feedback for a notification
  static Future<void> playNotificationFeedback(NotificationType type) async {
    await Future.wait([
      playNotificationSound(type),
      triggerHapticFeedback(type),
    ]);
  }
  
  /// Play sound and haptic for a BarkDate notification
  static Future<void> playForNotification(BarkDateNotification notification) async {
    await playNotificationFeedback(notification.type);
  }
  
  /// Check if sound is enabled in system settings
  static Future<bool> isSoundEnabled() async {
    if (!_isSupported) return true;
    try {
      return await _channel.invokeMethod('isSoundEnabled') ?? true;
    } catch (e) {
      return true;
    }
  }
  
  /// Check if vibration is enabled in system settings
  static Future<bool> isVibrationEnabled() async {
    if (!_isSupported) return true;
    try {
      return await _channel.invokeMethod('isVibrationEnabled') ?? true;
    } catch (e) {
      return true;
    }
  }
  
  /// Set notification volume (0.0 to 1.0)
  static Future<void> setNotificationVolume(double volume) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume.clamp(0.0, 1.0)});
    } catch (e) {
      // ignore
    }
  }
  
  /// Get current notification volume
  static Future<double> getNotificationVolume() async {
    if (!_isSupported) return 0.7;
    try {
      return await _channel.invokeMethod('getVolume') ?? 0.7;
    } catch (e) {
      return 0.7;
    }
  }
}

/// Simple fallback sound service using Flutter's built-in capabilities
class SimpleSoundService {
  /// Play a simple system sound for notifications
  static Future<void> playSystemSound() async {
    await HapticFeedback.mediumImpact();
  }
  
  /// Play different haptic patterns based on notification type
  static Future<void> playHapticForType(NotificationType type) async {
    switch (type) {
      case NotificationType.bark:
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 50));
        await HapticFeedback.lightImpact();
        break;
      case NotificationType.playdateRequest:
        await HapticFeedback.heavyImpact();
        break;
      case NotificationType.match:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        break;
      case NotificationType.playdate:
        await HapticFeedback.mediumImpact();
        break;
      default:
        await HapticFeedback.lightImpact();
        break;
    }
  }
  
  /// Simple notification feedback
  static Future<void> playNotificationFeedback(NotificationType type) async {
    await playHapticForType(type);
  }
}
