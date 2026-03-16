import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/friend_alert.dart';
import 'package:barkdate/features/feed/presentation/providers/friend_activity_provider.dart';
import 'package:barkdate/widgets/pack_alert_card.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/widgets/walk_details_sheet.dart';

/// A horizontally scrollable carousel of PackAlertCards.
/// Auto-advances every 5 seconds with page indicator dots.
/// Hides completely when there are no alerts.
class PackAlertsCarousel extends ConsumerStatefulWidget {
  const PackAlertsCarousel({super.key});

  @override
  ConsumerState<PackAlertsCarousel> createState() => _PackAlertsCarouselState();
}

class _PackAlertsCarouselState extends ConsumerState<PackAlertsCarousel> {
  late final PageController _pageController;
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvance(int totalPages) {
    _autoAdvanceTimer?.cancel();
    if (totalPages <= 1) return;

    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_userInteracting || !mounted) return;

      final nextPage = (_currentPage + 1) % totalPages;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _handleCtaTap(BuildContext context, FriendAlert alert) {
    if (alert.type == FriendAlertType.walkTogether) {
      final metadata = alert.metadata ?? const <String, dynamic>{};
      final parkId = metadata['park_id'] as String?;
      final parkName = metadata['park_name'] as String?;
      final scheduledForRaw = metadata['scheduled_for'] as String?;
      final organizerDogName = metadata['dog_name'] as String? ?? 'A friend';
      final checkInId = metadata['check_in_id'] as String?;

      final scheduledFor = scheduledForRaw != null
          ? DateTime.tryParse(scheduledForRaw)
          : null;

      if (parkId != null &&
          parkId.isNotEmpty &&
          parkName != null &&
          parkName.isNotEmpty &&
          scheduledFor != null) {
        showWalkDetailsSheet(
          context,
          parkId: parkId,
          parkName: parkName,
          scheduledFor: scheduledFor,
          organizerDogName: organizerDogName,
          checkInId: checkInId,
        );
        return;
      }

      // Fallback for own playdate-based walk cards without check-in metadata.
      const PlaydatesRoute().go(context);
      return;
    }

    final route = alert.ctaRoute;
    if (route != null && route.isNotEmpty) {
      // Parse route — may contain query params
      final uri = Uri.parse(route);
      debugPrint('Navigating to ${uri.path} with metadata ${alert.metadata}');

      if (uri.path == '/social-feed') {
        const SocialFeedRoute().push(context);
      } else if (uri.path == '/map') {
        const MapRoute().go(context);
      } else if (uri.path == '/dog-details') {
        if (alert.metadata != null) {
          DogDetailsRoute($extra: Dog.fromJson(alert.metadata!)).push(context);
        }
      } else if (uri.path == '/playdate-details') {
        if (alert.metadata != null) {
          PlaydateDetailsRoute($extra: alert.metadata!).push(context);
        }
      } else if (uri.path == '/event-details') {
        EventDetailsRoute($extra: alert.metadata).push(context);
      } else {
        debugPrint(
            'WARNING: Unhandled route in PackAlertsCarousel: $route. Falling back to untyped context.push.');
        context.push(route, extra: alert.metadata);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(friendAlertsProvider);

    return alertsAsync.when(
      data: (alerts) {
        if (alerts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Start/restart auto-advance when data loads
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startAutoAdvance(alerts.length);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pack Activity',
                    style: AppTypography.labelMedium(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Card carousel
            SizedBox(
              height: 190,
              child: GestureDetector(
                onPanDown: (_) {
                  _userInteracting = true;
                },
                onPanEnd: (_) {
                  _userInteracting = false;
                },
                onPanCancel: () {
                  _userInteracting = false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: alerts.length,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: PackAlertCard(
                        alert: alert,
                        onCtaTapped: () => _handleCtaTap(context, alert),
                        onCardTapped: () => _handleCtaTap(context, alert),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Page indicator dots
            if (alerts.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  alerts.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentPage ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? alerts[_currentPage].backgroundColor
                          : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => _buildShimmer(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading pack activity...',
                style: AppTypography.bodySmall(
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
