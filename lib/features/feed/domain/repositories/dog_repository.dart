import 'package:barkdate/models/dog.dart';

abstract class DogRepository {
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
  });
}
