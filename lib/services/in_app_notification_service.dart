import 'package:flutter/material.dart';
import 'package:barkdate/models/notification.dart';
import 'package:barkdate/widgets/notification_banner.dart';
import 'package:barkdate/core/router/app_router.dart';

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
    final overlayState = _overlayState ?? rootNavigatorKey.currentState?.overlay;
    if (overlayState == null) {
      debugPrint('⚠️ Cannot show notification: OverlayState is null');
      return;
    }

    // Remove existing overlay if any
    _currentOverlay?.remove();
    _currentOverlay = null;

    // Create new overlay entry
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => NotificationBanner(
        notification: notification,
        onTap: () {
          // TODO: Handle navigation based on notification.actionType
          // For now just dismiss
          _dismissOverlay();
        },
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
          overlayNotifier.value = null;
        },
      ),
    );

    // Insert and track
    overlayState.insert(overlayEntry);
    _currentOverlay = overlayEntry;
    overlayNotifier.value = overlayEntry;

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (_currentOverlay == overlayEntry) {
        // We probably want to trigger exit animation first
        // But accessing state from here is hard. 
        // The banner should handle its own lifecycle or we rely on user to dismiss?
        // Usually auto-dismiss is good. 
        // Ideally we call a method on the widget key, but we don't have it.
        // For simple implementation, we can just let it persist or hard remove.
        // Or better: pass a duration to NotificationBanner?
        // But NotificationBanner constructor doesn't take duration.
        // Let's just remove it for now.
        if (overlayEntry.mounted) {
           _currentOverlay?.remove();
           _currentOverlay = null;
           overlayNotifier.value = null;
        }
      }
    });
    
    print('Showing notification: ${notification.title}');
  }

  static void _dismissOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    overlayNotifier.value = null;
  }
  
  /// Show a notification banner (alternative signature)
  static Future<void> showBanner(BarkDateNotification notification) async {
    await showNotification(notification);
  }
}
