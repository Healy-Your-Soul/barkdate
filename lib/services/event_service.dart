import 'package:barkdate/models/event.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:flutter/material.dart';
import 'package:barkdate/services/notification_manager.dart';

class EventService {
  /// Get all upcoming events with optional filtering
  static Future<List<Event>> getUpcomingEvents({
    String? category,
    List<String>? targetAgeGroups,
    List<String>? targetSizes,
    double? maxPrice,
    int limit = 50,
    int offset = 0,
    bool publicOnly = true,
  }) async {
    try {
      // Build base query
      var query = SupabaseConfig.client
          .from('events')
          .select('''
            *,
            users!organizer_id (
              name,
              avatar_url
            )
          ''')
          .eq('status', 'upcoming')
          .gte('start_time', DateTime.now().toIso8601String());

      if (publicOnly) {
        query = query.eq('is_public', true);
      }

      // Add category filter if provided
      if (category != null) {
        query = query.eq('category', category);
      }

      // Apply ordering and limit, then execute
    final data = await query
      .order('start_time', ascending: true)
      .range(offset, offset + limit - 1);

      return data.map((json) {
        // Add organizer info from joined users table
        final userData = json['users'] as Map<String, dynamic>?;
        return Event.fromJson({
          ...json,
          'organizer_name': userData?['name'] ?? 'Unknown',
          'organizer_avatar_url': userData?['avatar_url'] ?? '',
        });
      }).toList();
    } catch (e) {
      debugPrint('Error fetching upcoming events: $e');
      return [];
    }
  }

  /// Get events by category
  static Future<List<Event>> getEventsByCategory(String category) async {
    return await getUpcomingEvents(category: category);
  }

  /// Get events recommended for a specific dog
  static Future<List<Event>> getRecommendedEvents({
    required String dogId,
    required String dogAge,
    required String dogSize,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Map dog age to age groups
      final age = int.tryParse(dogAge) ?? 1;
      final ageGroups = <String>[];
      
      if (age <= 1) {
        ageGroups.add('puppy');
      }
      if (age >= 1 && age <= 7) {
        ageGroups.add('adult');
      }
      if (age > 7) {
        ageGroups.add('senior');
      }

      return await getUpcomingEvents(
        targetAgeGroups: ageGroups,
        targetSizes: [dogSize.toLowerCase()],
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('Error fetching recommended events: $e');
      return [];
    }
  }

  /// Get events organized by a specific user
  static Future<List<Event>> getUserOrganizedEvents(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('events')
          .select('''
            *,
            users!organizer_id (
              name,
              avatar_url
            )
          ''')
          .eq('organizer_id', userId)
          .order('start_time', ascending: true);

      return data.map((json) {
        final userData = json['users'] as Map<String, dynamic>?;
        return Event.fromJson({
          ...json,
          'organizer_name': userData?['name'] ?? 'Unknown',
          'organizer_avatar_url': userData?['avatar_url'] ?? '',
        });
      }).toList();
    } catch (e) {
      debugPrint('Error fetching user organized events: $e');
      return [];
    }
  }

  /// Get events a user is participating in
  static Future<List<Event>> getUserParticipatingEvents(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final data = await SupabaseConfig.client
          .from('event_participants')
          .select('''
            *,
            events (
              *,
              users!organizer_id (
                name,
                avatar_url
              )
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return data.map((json) {
        final eventData = json['events'] as Map<String, dynamic>?;
        final userData = eventData?['users'] as Map<String, dynamic>?;
        return Event.fromJson({
          ...eventData!,
          'organizer_name': userData?['name'] ?? 'Unknown',
          'organizer_avatar_url': userData?['avatar_url'] ?? '',
        });
      }).toList();
    } catch (e) {
      debugPrint('Error fetching user participating events: $e');
      return [];
    }
  }

  /// Create a new event
  static Future<Event?> createEvent({
    required String title,
    required String description,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
    required String category,
    required int maxParticipants,
    List<String> targetAgeGroups = const [],
    List<String> targetSizes = const [],
    double? price,
    bool requiresRegistration = true,
    double? latitude,
    double? longitude,
    List<String> photoUrls = const [],
    // bool isPublic = true, // Remove or keep deprecated
    String visibility = 'public',
    List<String> invitedDogIds = const [],
    String? invitationMessage,
  }) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final eventData = {
        'title': title,
        'description': description,
        'location': location,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'category': category,
        'max_participants': maxParticipants,
        'current_participants': 0,
        'target_age_groups': targetAgeGroups,
        'target_sizes': targetSizes,
        'price': price,
        'requires_registration': requiresRegistration,
        'status': 'upcoming',
        'organizer_id': user.id,
        'organizer_type': 'user',
        'latitude': latitude,
        'longitude': longitude,
        'photo_urls': photoUrls,
        // 'is_public': isPublic,
        'visibility': visibility,
        'is_public': visibility == 'public', // Set deprecated field for backward compatibility
      };

      final data = await SupabaseConfig.client
          .from('events')
          .insert(eventData)
          .select('''
            *,
            users!organizer_id (
              name,
              avatar_url
            )
          ''')
          .single();

      final userData = data['users'] as Map<String, dynamic>?;
      final event = Event.fromJson({
        ...data,
        'organizer_name': userData?['name'] ?? 'Unknown',
        'organizer_avatar_url': userData?['avatar_url'] ?? '',
      });

      // Send invitations if provided
      if (invitedDogIds.isNotEmpty) {
        await inviteDogs(
          eventId: event.id,
          dogIds: invitedDogIds,
          message: invitationMessage,
        );
      }

      return event;
    } catch (e) {
      debugPrint('Error creating event: $e');
      return null;
    }
  }

  /// Invite multiple dogs to an event
  static Future<bool> inviteDogs({
    required String eventId,
    required List<String> dogIds,
    String? message,
  }) async {
    if (dogIds.isEmpty) return true;

    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create invitations
      final invitations = dogIds.map((dogId) {
        return {
          'event_id': eventId,
          'dog_id': dogId,
          'invited_by': user.id,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        };
      }).toList();

      await SupabaseConfig.client
          .from('event_invitations')
          .upsert(invitations, onConflict: 'event_id,dog_id');

      // Send notifications
      // 1. Get event details for title
      final eventData = await SupabaseConfig.client
          .from('events')
          .select('title')
          .eq('id', eventId)
          .single();
      final eventTitle = eventData['title'] as String;

      // 2. Get inviter name (user's name)
      final userData = await SupabaseConfig.client
          .from('users')
          .select('name')
          .eq('id', user.id)
          .single();
      final inviterName = userData['name'] as String;

      // 3. Get dogs' owners to notify
      final dogsData = await SupabaseConfig.client
          .from('dogs')
          .select('id, user_id')
          .filter('id', 'in', dogIds);
      
      for (final dog in dogsData) {
        final ownerId = dog['user_id'] as String;
        if (ownerId != user.id) {
          await NotificationManager.sendEventInviteNotification(
            receiverUserId: ownerId,
            inviterName: inviterName,
            eventId: eventId,
            eventTitle: eventTitle,
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error inviting dogs to event: $e');
      return false;
    }
  }

  /// Join an event
  static Future<bool> joinEvent(String eventId, String userId, String dogId) async {
    try {
      await SupabaseConfig.client.from('event_participants').insert({
        'event_id': eventId,
        'user_id': userId,
        'dog_id': dogId,
      });

      // Update participant count
      await SupabaseConfig.client.rpc('increment_event_participants', 
        params: {'event_id': eventId},
      );

      return true;
    } catch (e) {
      debugPrint('Error joining event: $e');
      return false;
    }
  }

  /// Leave an event
  static Future<bool> leaveEvent(String eventId, String userId) async {
    try {
      await SupabaseConfig.client
          .from('event_participants')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);

      // Update participant count
      await SupabaseConfig.client.rpc('decrement_event_participants', 
        params: {'event_id': eventId},
      );

      return true;
    } catch (e) {
      debugPrint('Error leaving event: $e');
      return false;
    }
  }

  /// Check if user is participating in an event
  static Future<bool> isUserParticipating(String eventId, String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('event_participants')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking event participation: $e');
      return false;
    }
  }

  /// Get event categories
  static List<Map<String, dynamic>> getEventCategories() {
    return [
      {
        'id': 'birthday',
        'name': 'Birthday Party',
        'icon': '🎂',
        'description': 'Celebrate your dog\'s special day',
      },
      {
        'id': 'training',
        'name': 'Training Class',
        'icon': '🎓',
        'description': 'Learn new skills and behaviors',
      },
      {
        'id': 'social',
        'name': 'Social Meetup',
        'icon': '🐕',
        'description': 'Meet new friends and play',
      },
      {
        'id': 'professional',
        'name': 'Professional Service',
        'icon': '🏥',
        'description': 'Grooming, vet visits, and care',
      },
    ];
  }

  /// Get target age groups
  static List<String> getTargetAgeGroups() {
    return ['puppy', 'adult', 'senior'];
  }

  /// Get target sizes
  static List<String> getTargetSizes() {
    return ['small', 'medium', 'large', 'extra large'];
  }
}
