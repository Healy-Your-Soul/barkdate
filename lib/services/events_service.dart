import 'package:barkdate/models/event.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to fetch dog events from Supabase with geospatial filtering
class EventsService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Fetch events within a bounding box and time range
  Future<List<Event>> fetchEventsInViewport({
    required double south,
    required double west,
    required double north,
    required double east,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? categories,
    int limit = 200,
  }) async {
    try {
      final from = fromTime ?? DateTime.now();
      final to = toTime ?? DateTime.now().add(const Duration(days: 14));

      debugPrint(
        '🔍 Fetching events: bbox=($south,$west,$north,$east), time=$from..$to',
      );

      // Build query with status filter
      final response = await _supabase
          .from('events')
          .select()
          .gte('latitude', south)
          .lte('latitude', north)
          .gte('longitude', west)
          .lte('longitude', east)
          .gte('start_time', from.toIso8601String())
          .lte('start_time', to.toIso8601String())
          .neq('visibility', 'invite_only')
          .or('status.eq.upcoming,status.eq.ongoing')
          .order('start_time', ascending: true)
          .limit(limit);

      final events = (response as List)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Found ${events.length} events');
      return events;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching events: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }

  /// Fetch events for a specific place
  Future<List<Event>> fetchEventsForPlace({
    required String placeId,
    DateTime? fromTime,
    DateTime? toTime,
    int limit = 10,
  }) async {
    try {
      final from = fromTime ?? DateTime.now();
      final to = toTime ?? DateTime.now().add(const Duration(days: 30));

      final response = await _supabase
          .from('events')
          .select()
          // Note: Assumes events table has a place_id column linking to places
          .eq('place_id', placeId)
          .gte('start_time', from.toIso8601String())
          .lte('start_time', to.toIso8601String())
          .neq('visibility', 'invite_only')
          .or('status.eq.upcoming,status.eq.ongoing')
          .order('start_time', ascending: true)
          .limit(limit);

      final events = (response as List)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();

      return events;
    } catch (e) {
      debugPrint('❌ Error fetching events for place $placeId: $e');
      return [];
    }
  }

  /// Get event categories for filtering
  static List<String> get eventCategories => [
    'birthday',
    'training',
    'social',
    'professional',
  ];

  /// Get event category display names
  static String getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'birthday':
        return 'Birthday Party';
      case 'training':
        return 'Training Class';
      case 'social':
        return 'Social Meetup';
      case 'professional':
        return 'Professional Service';
      default:
        return 'Event';
    }
  }
}
