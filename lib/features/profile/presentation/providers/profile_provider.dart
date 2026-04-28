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

/// Snapshot of what (if anything) the user still has to fill in to finish
/// their BarkDate profile. Derived from [userProfileProvider] + [userDogsProvider],
/// so it rebuilds automatically whenever either of those is invalidated on
/// save.
class ProfileCompletion {
  final bool ownerComplete;
  final bool dogComplete;

  const ProfileCompletion({
    required this.ownerComplete,
    required this.dogComplete,
  });

  bool get allComplete => ownerComplete && dogComplete;
}

final profileCompletionProvider =
    FutureProvider<ProfileCompletion>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final dogs = await ref.watch(userDogsProvider.future);

  bool nonEmpty(dynamic v) => v != null && v.toString().trim().isNotEmpty;

  // Owner completeness is intentionally lenient: only the DB-required `name`
  // gates the red card. Avatar + bio are still nice-to-have but they no
  // longer trigger a blocking nudge on the feed.
  final ownerComplete = nonEmpty(profile['name']);

  // Dog: at least one dog with all onboarding-required fields + >=1 photo.
  // Matches both the full and fast-track onboarding flows.
  final dogComplete = dogs.any((d) =>
      nonEmpty(d.name) &&
      nonEmpty(d.breed) &&
      d.age > 0 &&
      nonEmpty(d.size) &&
      nonEmpty(d.gender) &&
      d.photos.isNotEmpty);

  return ProfileCompletion(
    ownerComplete: ownerComplete,
    dogComplete: dogComplete,
  );
});
