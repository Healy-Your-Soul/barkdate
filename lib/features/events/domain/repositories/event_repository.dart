import 'package:barkdate/models/event.dart';

abstract class EventRepository {
  Future<List<Event>> getEventsInViewport({
    required double south,
    required double west,
    required double north,
    required double east,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? categories,
    int limit = 200,
  });

  Future<List<Event>> getEventsForPlace({
    required String placeId,
    DateTime? fromTime,
    DateTime? toTime,
    int limit = 10,
  });

  Future<bool> joinEvent({
    required String eventId,
    required String userId,
    required String dogId,
  });

  Future<bool> leaveEvent({
    required String eventId,
    required String userId,
  });

  Future<bool> isUserParticipating({
    required String eventId,
    required String userId,
  });
}
