import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles app icon badge updates on iOS.
class AppBadgeService {
  static const MethodChannel _channel = MethodChannel('bark/app_badge');

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> setBadgeCount(int count) async {
    if (!_isSupported) return;

    final safeCount = (count < 0 ? 0 : count);
    debugPrint('🔴 [AppBadge] setBadgeCount → $safeCount');
    try {
      await _channel.invokeMethod<void>('setBadgeCount', {
        'count': safeCount,
      });
      debugPrint('🔴 [AppBadge] badge successfully set to $safeCount');
    } catch (e) {
      debugPrint('🔴 [AppBadge] Failed to set badge count: $e');
    }
  }

  static Future<void> clearBadge() async {
    debugPrint('🔴 [AppBadge] clearBadge → setting to 0');
    await setBadgeCount(0);
  }
}
