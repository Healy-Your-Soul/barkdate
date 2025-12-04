import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/events/domain/repositories/event_repository.dart';
import 'package:barkdate/features/events/data/repositories/event_repository_impl.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/features/map/presentation/providers/map_provider.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepositoryImpl();
});

// Filter state for Events screen
class EventFilters {
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<String> categories;

  EventFilters({
    this.fromDate,
    this.toDate,
    this.categories = const [],
  });

  EventFilters copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? categories,
  }) {
    return EventFilters(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      categories: categories ?? this.categories,
    );
  }
}

final eventFiltersProvider = StateProvider<EventFilters>((ref) => EventFilters());

// Provider for fetching events based on map viewport (reusing map viewport for now, or could use user location)
// For the list view, we might want events near the user, not just in the map viewport.
// But let's assume we want events near the user.
final nearbyEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  final viewport = ref.watch(mapViewportProvider); // Use map viewport as a proxy for "nearby" if map is centered on user
  final filters = ref.watch(eventFiltersProvider);

  if (viewport.bounds == null) {
    // Fallback to a default search if no viewport (e.g. initial load)
    // Or wait for location.
    return [];
  }

  return await repository.getEventsInViewport(
    south: viewport.bounds!.southwest.latitude,
    west: viewport.bounds!.southwest.longitude,
    north: viewport.bounds!.northeast.latitude,
    east: viewport.bounds!.northeast.longitude,
    fromTime: filters.fromDate,
    toTime: filters.toDate,
    categories: filters.categories.isNotEmpty ? filters.categories : null,
  );
});
