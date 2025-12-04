import 'package:barkdate/features/feed/domain/repositories/dog_repository.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/barkdate_services.dart';

class DogRepositoryImpl implements DogRepository {
  @override
  Future<List<Dog>> getNearbyDogs({
    required String userId,
    required int limit,
    required int offset,
    double? maxDistance,
    int? minAge,
    int? maxAge,
    List<String>? sizes,
    List<String>? genders,
    List<String>? breeds,
  }) async {
    // Note: The existing BarkDateMatchService.getNearbyDogs doesn't seem to support all filters directly in the query yet,
    // but for now we'll use what's available and filter in memory if needed, or update the service later.
    // Based on the old FeedScreen, it fetched then filtered.
    // Ideally, we should push filters to the DB.
    
    final dogData = await BarkDateMatchService.getNearbyDogs(
      userId,
      limit: limit,
      offset: offset,
    );

    return dogData.map((data) => _mapDogFromRaw(data)).toList();
  }

  Dog _mapDogFromRaw(Map<String, dynamic> data) {
    final userData = data['users'] as Map<String, dynamic>?;
    final photosRaw = data['photo_urls'] ?? data['photos'] ?? data['photoUrls'] ?? [];
    final ownerNameValue = data['owner_name'] ?? userData?['name'] ?? 'Unknown Owner';
    final ownerIdValue = data['user_id'] ?? userData?['id'] ?? '';
    final distance = (data['distance_km'] ?? data['distanceKm']) as num?;

    return Dog(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Doggo',
      breed: data['breed'] as String? ?? 'Mixed',
      age: (data['age'] as num?)?.toInt() ?? 0,
      size: data['size'] as String? ?? 'medium',
      gender: data['gender'] as String? ?? 'unknown',
      bio: data['bio'] as String? ?? '',
      photos: ((photosRaw as List?) ?? [])
          .whereType<dynamic>()
          .map((e) => e.toString())
          .toList(),
      ownerId: ownerIdValue.toString(),
      ownerName: ownerNameValue.toString(),
      distanceKm: distance?.toDouble() ?? 0.0,
    );
  }
}
