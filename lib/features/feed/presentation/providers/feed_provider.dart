import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:barkdate/features/feed/domain/repositories/dog_repository.dart';
import 'package:barkdate/features/feed/data/repositories/dog_repository_impl.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/features/auth/presentation/providers/auth_provider.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart'
    hide DogFriendshipService;

final dogRepositoryProvider = Provider<DogRepository>((ref) {
  return DogRepositoryImpl();
});

/// Real-time unread notification count
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return Stream.value(0);

  return NotificationService.streamUserNotifications(user.id).map(
      (notifications) =>
          notifications.where((n) => n['is_read'] == false).length);
});

/// Real-time pending friend requests (for the primary dog)
final pendingFriendRequestsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
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
  final bool
      showPackOnly; // Filter to show only pack members (accepted friends)

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

  List<Dog> dogs;

  // If showing pack only, fetch friends directly (bypassing nearby pagination limits)
  if (filter.showPackOnly) {
    if (myDogId == null) return [];

    final friends = await DogFriendshipService.getFriends(myDogId);

    dogs = friends.map((f) {
      // Determine which dog object is the friend
      final friendDogMap = f['friend_dog']['id'] == myDogId
          ? f['dog'] as Map<String, dynamic>
          : f['friend_dog'] as Map<String, dynamic>;

      // Ensure photos is list
      final photosRaw =
          friendDogMap['photo_urls'] ?? friendDogMap['photos'] ?? [];
      final photos = (photosRaw as List).map((e) => e.toString()).toList();
      if (photos.isEmpty && friendDogMap['main_photo_url'] != null) {
        photos.add(friendDogMap['main_photo_url']);
      }

      // Map to Dog object
      return Dog(
        id: friendDogMap['id'] ?? '',
        name: friendDogMap['name'] ?? 'Unknown',
        breed: friendDogMap['breed'] ?? 'Unknown',
        age: (friendDogMap['age'] as num?)?.toInt() ?? 0,
        size: friendDogMap['size'] ?? 'medium',
        gender: friendDogMap['gender'] ?? 'unknown',
        bio: friendDogMap['bio'] ?? '',
        photos: photos,
        ownerId: friendDogMap['user_id'] ?? '', // RPC returns user_id
        ownerName: friendDogMap['user']?['name'] ?? 'Unknown Owner',
        distanceKm: 0.0, // Friends don't need distance in this view
        isFriend: true,
        friendshipStatus: 'accepted',
        friendshipId: f['id'] as String?,
      );
    }).toList();
  } else {
    // Normal mode: Fetch nearby dogs
    dogs = await repository.getNearbyDogs(
      userId: user.id,
      limit: 20,
      offset: 0,
    );
  }

  // Sprint 8: Build a map of dogId → {status, friendshipId, direction} from
  // all friendship rows (accepted + pending) so each card can render the
  // correct state (In Pack / Request Sent / Accept+Ignore / Add to Pack).
  Map<String, Map<String, String>> friendshipMap = {};
  if (myDogId != null) {
    // Fetch all friendships (accepted + pending) in one query
    final allFriendships = await SupabaseConfig.client
        .from('dog_friendships')
        .select('id, dog_id, friend_dog_id, status')
        .or('dog_id.eq.$myDogId,friend_dog_id.eq.$myDogId');

    for (final f in allFriendships) {
      final fDogId = f['dog_id'] as String;
      final fFriendDogId = f['friend_dog_id'] as String;
      final status = f['status'] as String;
      final fId = f['id'] as String;

      // The "other" dog is whichever isn't mine
      final otherDogId = fDogId == myDogId ? fFriendDogId : fDogId;

      String resolvedStatus;
      if (status == 'accepted') {
        resolvedStatus = 'accepted';
      } else if (status == 'pending') {
        // Direction: did I send (dog_id == myDogId) or receive?
        resolvedStatus =
            fDogId == myDogId ? 'pending_sent' : 'pending_received';
      } else {
        continue; // skip 'declined' or unknown
      }

      friendshipMap[otherDogId] = {
        'status': resolvedStatus,
        'friendshipId': fId,
      };
    }
  }

  // Apply memory filters and map friendship status
  final filteredDogs = dogs.where((dog) {
    if (dog.distanceKm > filter.maxDistance) return false;
    if (dog.age < filter.minAge || dog.age > filter.maxAge) return false;
    if (filter.sizes.isNotEmpty && !filter.sizes.contains(dog.size)) {
      return false;
    }
    if (filter.genders.isNotEmpty && !filter.genders.contains(dog.gender)) {
      return false;
    }
    if (filter.breeds.isNotEmpty && !filter.breeds.contains(dog.breed)) {
      return false;
    }
    return true;
  }).map((dog) {
    final fs = friendshipMap[dog.id];
    return dog.copyWith(
      isFriend: fs?['status'] == 'accepted',
      friendshipStatus: fs?['status'],
      friendshipId: fs?['friendshipId'],
    );
  }).toList();

  // Optimization: Batch fetch playdate statuses to prevent N+1 queries in DogCard
  if (filteredDogs.isNotEmpty) {
    final ownerIds = filteredDogs
        .map((d) => d.ownerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final statuses = await PlaydateQueryService.getPlaydateStatusesForOwners(
        user.id, ownerIds);

    return filteredDogs.map((dog) {
      final status = statuses[dog.ownerId];
      if (status != null) {
        return dog.copyWith(
          playdateStatus: status['playdate_status'] as String?,
          currentPlaydateId:
              (status['current_playdate'] as Map?)?['id'] as String?,
        );
      }
      return dog.copyWith(playdateStatus: 'none');
    }).toList();
  }

  return filteredDogs;
});

/// Recent public posts from ALL dogs (for the Sniff Around section).
/// Returns raw maps — lightweight so the feed preview stays fast.
final recentPublicPostsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await BarkDateSocialService.getFeedPosts(limit: 6, offset: 0);
  } catch (e) {
    debugPrint('Error fetching recent public posts: $e');
    return [];
  }
});
