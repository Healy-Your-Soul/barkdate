import 'package:barkdate/models/dog.dart';

class FeedFilterService {
  FeedFilterService._();

  /// Remove duplicate dogs and filter out those already engaged elsewhere.
  static List<Dog> applyFeedFilters({
    required List<Dog> nearbyDogs,
    Iterable<dynamic>? dogsWithEvents,
    Iterable<dynamic>? dogsWithPlaydates,
  }) {
    final blockedIds = <String>{}
      ..addAll(_normalizeIds(dogsWithEvents))
      ..addAll(_normalizeIds(dogsWithPlaydates));

    final seen = <String>{};
    final filtered = <Dog>[];

    for (final dog in nearbyDogs) {
      if (dog.id.isEmpty) continue;
      if (blockedIds.contains(dog.id)) continue;
      if (seen.add(dog.id)) {
        filtered.add(dog);
      }
    }

    return filtered;
  }

  static Iterable<String> _normalizeIds(Iterable<dynamic>? ids) {
    if (ids == null) return const Iterable.empty();
    return ids
        .where((id) => id != null)
        .map((id) => id.toString())
        .where((id) => id.isNotEmpty);
  }
}
