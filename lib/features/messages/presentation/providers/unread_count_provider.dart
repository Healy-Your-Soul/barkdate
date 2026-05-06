import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Sprint 7f: server-computed unread-conversation count.
///
/// Replaces the previous derivation via `streamConversations` which was
/// lossy on group messages because Supabase realtime can't apply complex
/// `.or` filters server-side. Now backed by the `unread_conversations_count`
/// RPC + a dedicated `messages` channel that fires a refetch on any change.
final unreadConversationCountProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) {
    yield 0;
    return;
  }

  Future<int> fetch() async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'unread_conversations_count',
        params: {'p_user_id': userId},
      );
      if (result is int) return result;
      if (result is num) return result.toInt();
      return 0;
    } catch (e) {
      debugPrint('unread_conversations_count rpc failed: $e');
      return 0;
    }
  }

  final controller = StreamController<int>();

  Future<void> emit() async {
    if (controller.isClosed) return;
    final n = await fetch();
    if (!controller.isClosed) controller.add(n);
  }

  // Initial value
  await emit();

  // Realtime: any messages change triggers a refetch. The RPC is cheap and
  // does the filtering server-side, so we don't need to pre-filter here.
  final channel = SupabaseConfig.client
      .channel('unread_count_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) {
          emit();
        },
      )
      .subscribe();

  // Safety-net periodic refetch in case realtime drops.
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    emit();
  });

  ref.onDispose(() {
    timer.cancel();
    SupabaseConfig.client.removeChannel(channel);
    controller.close();
  });

  yield* controller.stream;
});
