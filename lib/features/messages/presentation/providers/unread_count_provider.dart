import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';

/// Streams the number of unique conversations with unread messages.
/// Used by the Messages tab badge in the bottom nav bar.
final unreadConversationCountProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) {
    yield 0;
    return;
  }

  // Re-emit every time the conversations stream updates.
  await for (final conversations
      in BarkDateMessageService.streamConversations(userId)) {
    final count = conversations.where((c) => c['has_unread'] == true).length;
    yield count;
  }
});
