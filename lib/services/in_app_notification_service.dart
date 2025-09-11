import 'package:flutter/material.dart';
import 'package:barkdate/models/notification.dart';
import 'package:barkdate/widgets/notification_banner.dart';

/// Service for displaying in-app notification banners when the app is in foreground
/// Shows beautiful sliding banners at the top of the screen
class InAppNotificationService {
  static OverlayState? _overlayState;
  static OverlayEntry? _currentOverlay;
  static final ValueNotifier<OverlayEntry?> overlayNotifier = ValueNotifier(null);
  
  /// Initialize the service
  static Future<void> initialize() async {
    // Service initialized, overlay will be set when app starts
  }
  
  /// Set the overlay state from the app's main overlay
  static void setOverlay(OverlayState? overlay) {
    _overlayState = overlay;
  }
  
  /// Show a notification banner
  static Future<void> showNotification(BarkDateNotification notification) async {
    // TODO: Implement notification banner display
    print('Showing notification: ${notification.title}');
  }
  
  /// Show a notification banner (alternative signature)
  static Future<void> showBanner(BarkDateNotification notification) async {
    await showNotification(notification);
  }
}
