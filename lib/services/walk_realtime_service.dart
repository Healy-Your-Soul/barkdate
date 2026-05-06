import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Sprint 7f: app-wide realtime channels for walk-related tables. Replaces
/// the per-widget `_subscribeToWalkChanges` pattern (dog_card, chat_walk_card)
/// which cycled `subscribed → closed → subscribed` on every widget rebuild,
/// dropping postgres-change events in the gaps. Channels here live for the
/// session and broadcast updates to a stream that widgets can listen to
/// without owning the websocket lifecycle.
class WalkChange {
  final String? playdateId;
  final String source; // 'requests' | 'playdates'

  const WalkChange({required this.playdateId, required this.source});
}

class WalkRealtimeService {
  WalkRealtimeService._();
  static final WalkRealtimeService instance = WalkRealtimeService._();

  RealtimeChannel? _requestsChannel;
  RealtimeChannel? _playdatesChannel;
  StreamController<WalkChange>? _controller;
  String? _userId;

  Stream<WalkChange> get changes {
    _controller ??= StreamController<WalkChange>.broadcast();
    return _controller!.stream;
  }

  Stream<WalkChange> changesForPlaydate(String playdateId) =>
      changes.where((c) => c.playdateId == playdateId);

  /// Stream of ALL walk-related changes — useful for dog cards that don't
  /// know a specific playdate id ahead of time but need to refetch when any
  /// playdate-related row touching this user changes.
  Stream<WalkChange> get anyChange => changes;

  void start(String userId) {
    if (_userId == userId &&
        (_requestsChannel != null || _playdatesChannel != null)) {
      return; // already started for this user
    }

    stop();
    _userId = userId;
    _controller ??= StreamController<WalkChange>.broadcast();

    _requestsChannel = SupabaseConfig.client
        .channel('walk_rt_requests_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'playdate_requests',
          callback: (payload) {
            final pid = (payload.newRecord['playdate_id'] ??
                payload.oldRecord['playdate_id']) as String?;
            _controller?.add(WalkChange(playdateId: pid, source: 'requests'));
          },
        )
        .subscribe((status, [error]) {
          debugPrint('🔔 walk_rt requests: $status');
        });

    _playdatesChannel = SupabaseConfig.client
        .channel('walk_rt_playdates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'playdates',
          callback: (payload) {
            final pid = (payload.newRecord['id'] ??
                payload.oldRecord['id']) as String?;
            _controller?.add(WalkChange(playdateId: pid, source: 'playdates'));
          },
        )
        .subscribe((status, [error]) {
          debugPrint('🔔 walk_rt playdates: $status');
        });
  }

  void stop() {
    if (_requestsChannel != null) {
      SupabaseConfig.client.removeChannel(_requestsChannel!);
      _requestsChannel = null;
    }
    if (_playdatesChannel != null) {
      SupabaseConfig.client.removeChannel(_playdatesChannel!);
      _playdatesChannel = null;
    }
    _userId = null;
  }

  /// Called on app resume — channels may need to be torn down and re-created
  /// after a long backgrounding (websocket may have died silently).
  void restart() {
    final uid = _userId;
    if (uid == null) return;
    stop();
    start(uid);
  }
}
