import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/profile/domain/repositories/profile_repository.dart';
import 'package:barkdate/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/dog_sharing_service.dart';
// Repository Provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

// User Profile State
final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return {};
  return await repository.getUserProfile(user.id);
});

// User Dogs State
final userDogsProvider = FutureProvider<List<Dog>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return [];
  return await repository.getUserDogs(user.id);
});

// User Stats State
final userStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return {'friends': 0, 'playdates': 0, 'barks': 0};
  return await repository.getUserStats(user.id);
});
// Shared Dogs State
final sharedDogsProvider = FutureProvider<List<SharedDog>>((ref) async {
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return [];
  return await DogSharingService.getSharedDogs(user.id);
});
