import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/feed/domain/repositories/dog_repository.dart';
import 'package:barkdate/features/feed/data/repositories/dog_repository_impl.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/features/auth/presentation/providers/auth_provider.dart';

final dogRepositoryProvider = Provider<DogRepository>((ref) {
  return DogRepositoryImpl();
});

final feedFilterProvider = StateProvider<FeedFilter>((ref) => FeedFilter());

class FeedFilter {
  final double maxDistance;
  final int minAge;
  final int maxAge;
  final List<String> sizes;
  final List<String> genders;
  final List<String> breeds;

  FeedFilter({
    this.maxDistance = 50.0,
    this.minAge = 0,
    this.maxAge = 20,
    this.sizes = const [],
    this.genders = const [],
    this.breeds = const [],
  });
}

final nearbyDogsProvider = FutureProvider.autoDispose<List<Dog>>((ref) async {
  final repository = ref.watch(dogRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final filter = ref.watch(feedFilterProvider);

  if (user == null) return [];

  // Fetch dogs
  final dogs = await repository.getNearbyDogs(
    userId: user.id,
    limit: 20,
    offset: 0,
  );

  // Apply memory filters (until DB supports them fully)
  return dogs.where((dog) {
    if (dog.distanceKm > filter.maxDistance) return false;
    if (dog.age < filter.minAge || dog.age > filter.maxAge) return false;
    if (filter.sizes.isNotEmpty && !filter.sizes.contains(dog.size)) return false;
    if (filter.genders.isNotEmpty && !filter.genders.contains(dog.gender)) return false;
    if (filter.breeds.isNotEmpty && !filter.breeds.contains(dog.breed)) return false;
    return true;
  }).toList();
});
