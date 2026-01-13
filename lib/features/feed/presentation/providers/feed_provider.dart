import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/feed/domain/repositories/dog_repository.dart';
import 'package:barkdate/features/feed/data/repositories/dog_repository_impl.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/features/auth/presentation/providers/auth_provider.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';

final dogRepositoryProvider = Provider<DogRepository>((ref) {
  return DogRepositoryImpl();
});

/// Real-time unread notification count
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return Stream.value(0);
  
  return NotificationService.streamUserNotifications(user.id)
      .map((notifications) => notifications.where((n) => n['is_read'] == false).length);
});

/// Real-time pending friend requests (for the primary dog)
final pendingFriendRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) {
    yield [];
    return;
  }
  
  // Get user's dogs to know which dog ID to listen for
  // We'll use the first dog as primary for now
  final dogs = await BarkDateUserService.getUserDogs(user.id);
  if (dogs.isEmpty) {
    yield [];
    return;
  }
  
  final primaryDogId = dogs.first['id'];
  
  yield* DogFriendshipService.streamPendingBarksReceived(primaryDogId);
});

final feedFilterProvider = StateProvider<FeedFilter>((ref) => FeedFilter());

class FeedFilter {
  final double maxDistance;
  final int minAge;
  final int maxAge;
  final List<String> sizes;
  final List<String> genders;
  final List<String> breeds;
  final bool showPackOnly; // Filter to show only pack members (accepted friends)

  FeedFilter({
    this.maxDistance = 50.0,
    this.minAge = 0,
    this.maxAge = 20,
    this.sizes = const [],
    this.genders = const [],
    this.breeds = const [],
    this.showPackOnly = false, // Default to showing all dogs
  });
  
  FeedFilter copyWith({
    double? maxDistance,
    int? minAge,
    int? maxAge,
    List<String>? sizes,
    List<String>? genders,
    List<String>? breeds,
    bool? showPackOnly,
  }) {
    return FeedFilter(
      maxDistance: maxDistance ?? this.maxDistance,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      sizes: sizes ?? this.sizes,
      genders: genders ?? this.genders,
      breeds: breeds ?? this.breeds,
      showPackOnly: showPackOnly ?? this.showPackOnly,
    );
  }
}

final nearbyDogsProvider = FutureProvider.autoDispose<List<Dog>>((ref) async {
  final repository = ref.watch(dogRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final filter = ref.watch(feedFilterProvider);

  if (user == null) return [];

  // Get current user's dog for friendship checks
  final myDogs = await BarkDateUserService.getUserDogs(user.id);
  final myDogId = myDogs.isNotEmpty ? myDogs.first['id'] as String? : null;
  
  // Get friend dog IDs if filtering by pack
  Set<String> friendDogIds = {};
  if (filter.showPackOnly && myDogId != null) {
    final friends = await DogFriendshipService.getFriends(myDogId);
    for (final f in friends) {
      // Friend could be either dog_id or friend_dog_id depending on who initiated
      final dogData = f['dog'] as Map<String, dynamic>?;
      final friendDogData = f['friend_dog'] as Map<String, dynamic>?;
      if (dogData != null && dogData['id'] != myDogId) {
        friendDogIds.add(dogData['id'] as String);
      }
      if (friendDogData != null && friendDogData['id'] != myDogId) {
        friendDogIds.add(friendDogData['id'] as String);
      }
    }
  }

  // Fetch dogs
  final dogs = await repository.getNearbyDogs(
    userId: user.id,
    limit: 20,
    offset: 0,
  );

  // Apply memory filters (until DB supports them fully)
  return dogs.where((dog) {
    // Pack filter
    if (filter.showPackOnly && !friendDogIds.contains(dog.id)) return false;
    
    if (dog.distanceKm > filter.maxDistance) return false;
    if (dog.age < filter.minAge || dog.age > filter.maxAge) return false;
    if (filter.sizes.isNotEmpty && !filter.sizes.contains(dog.size)) return false;
    if (filter.genders.isNotEmpty && !filter.genders.contains(dog.gender)) return false;
    if (filter.breeds.isNotEmpty && !filter.breeds.contains(dog.breed)) return false;
    return true;
  }).toList();
});


