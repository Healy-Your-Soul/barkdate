import 'package:barkdate/features/events/domain/repositories/event_repository.dart';
import 'package:barkdate/services/events_service.dart';
import 'package:barkdate/services/event_service.dart';
import 'package:barkdate/models/event.dart';

class EventRepositoryImpl implements EventRepository {
  final EventsService _eventsService = EventsService();

  @override
  Future<List<Event>> getEventsInViewport({
    required double south,
    required double west,
    required double north,
    required double east,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? categories,
    int limit = 200,
  }) async {
    return await _eventsService.fetchEventsInViewport(
      south: south,
      west: west,
      north: north,
      east: east,
      fromTime: fromTime,
      toTime: toTime,
      categories: categories,
      limit: limit,
    );
  }

  @override
  Future<List<Event>> getEventsForPlace({
    required String placeId,
    DateTime? fromTime,
    DateTime? toTime,
    int limit = 10,
  }) async {
    return await _eventsService.fetchEventsForPlace(
      placeId: placeId,
      fromTime: fromTime,
      toTime: toTime,
      limit: limit,
    );
  }

  @override
  Future<bool> joinEvent({
    required String eventId,
    required String userId,
    required String dogId,
  }) async {
    return await EventService.joinEvent(eventId, userId, dogId);
  }

  @override
  Future<bool> leaveEvent({
    required String eventId,
    required String userId,
  }) async {
    return await EventService.leaveEvent(eventId, userId);
  }

  @override
  Future<bool> isUserParticipating({
    required String eventId,
    required String userId,
  }) async {
    return await EventService.isUserParticipating(eventId, userId);
  }
}
