import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/playdates/domain/repositories/playdate_repository.dart';
import 'package:barkdate/features/playdates/data/repositories/playdate_repository_impl.dart';
import 'package:barkdate/features/messages/domain/repositories/message_repository.dart';
import 'package:barkdate/features/messages/data/repositories/message_repository_impl.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';

// Repositories
final playdateRepositoryProvider = Provider<PlaydateRepository>((ref) {
  return PlaydateRepositoryImpl();
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl();
});

// Playdates
final userPlaydatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(playdateRepositoryProvider);
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return [];
  return await repository.getUserPlaydates(user.id);
});

// Messages
final conversationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return Stream.value([]);
  return BarkDateMessageService.streamConversations(user.id);
});

final mutualMatchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(messageRepositoryProvider);
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return [];
  return await repository.getMutualMatches(user.id);
});

// Messages for a specific match (one-time fetch)
final messagesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) async {
  final repository = ref.watch(messageRepositoryProvider);
  return await repository.getMessages(matchId);
});

// Real-time messages stream for a specific match
final messagesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, matchId) {
  return BarkDateMessageService.streamMessages(matchId);
});

