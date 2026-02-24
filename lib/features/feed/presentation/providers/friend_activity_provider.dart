import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/friend_alert.dart';
import 'package:barkdate/services/friend_activity_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Provides a periodically-refreshing list of friend alerts.
/// Refreshes every 30 seconds and on manual refresh.
final friendAlertsProvider =
    AutoDisposeAsyncNotifierProvider<FriendAlertsNotifier, List<FriendAlert>>(
  FriendAlertsNotifier.new,
);

class FriendAlertsNotifier
    extends AutoDisposeAsyncNotifier<List<FriendAlert>> {
  Timer? _refreshTimer;

  @override
  Future<List<FriendAlert>> build() async {
    // Clean up timer when provider is disposed
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    // Set up periodic refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidateSelf();
    });

    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return [];

    return FriendActivityService.getAlerts(user.id);
  }
}

/// Provider for scheduled walks visible on the map
final scheduledWalksForMapProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return FriendActivityService.getScheduledWalksForMap();
});
