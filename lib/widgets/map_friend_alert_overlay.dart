import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/friend_alert.dart';
import 'package:barkdate/features/feed/presentation/providers/friend_activity_provider.dart';
import 'package:barkdate/design_system/app_typography.dart';

/// Compact floating alert overlay for the Map screen.
/// Shows one location-relevant alert at a time, auto-rotates every 5s.
/// Only shows friendCheckIn, nearbySpot, and walkTogether alerts.
class MapFriendAlertOverlay extends ConsumerStatefulWidget {
  const MapFriendAlertOverlay({super.key});

  @override
  ConsumerState<MapFriendAlertOverlay> createState() =>
      _MapFriendAlertOverlayState();
}

class _MapFriendAlertOverlayState extends ConsumerState<MapFriendAlertOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _rotateTimer;
  int _currentIndex = 0;
  bool _isDismissed = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _startRotation(int total) {
    _rotateTimer?.cancel();
    if (total <= 1) return;

    _rotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _slideController.reverse().then((_) {
          _currentIndex = (_currentIndex + 1) % total;
          _slideController.forward();
        });
      });
    });
  }

  List<FriendAlert> _filterLocationAlerts(List<FriendAlert> all) {
    return all
        .where((a) =>
            a.type == FriendAlertType.friendCheckIn ||
            a.type == FriendAlertType.nearbySpot ||
            a.type == FriendAlertType.walkTogether)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final alertsAsync = ref.watch(friendAlertsProvider);

    return alertsAsync.when(
      data: (allAlerts) {
        final alerts = _filterLocationAlerts(allAlerts);
        if (alerts.isEmpty) return const SizedBox.shrink();

        // Start rotation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startRotation(alerts.length);
        });

        final alert = alerts[_currentIndex % alerts.length];

        return Dismissible(
          key: const ValueKey('map_alert_overlay'),
          direction: DismissDirection.up,
          onDismissed: (_) {
            setState(() => _isDismissed = true);
          },
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onTap: () {
                // Could navigate or focus map
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: alert.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: alert.backgroundColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Emoji
                    Text(
                      alert.iconEmoji ?? FriendAlert.emojiForType(alert.type),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 10),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            alert.headline,
                            style: AppTypography.labelSmall(
                              color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            alert.body,
                            style: AppTypography.caption(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dismiss X
                    GestureDetector(
                      onTap: () => setState(() => _isDismissed = true),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
