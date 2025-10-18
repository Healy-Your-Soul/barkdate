import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';

/// BarkDate-specific Supabase service classes
class BarkDateUserService {
  // Cache for getUserDogs to prevent duplicate API calls
  static final Map<String, List<Map<String, dynamic>>> _userDogsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheExpiryMinutes = 5;

  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return await SupabaseService.selectSingle(
      'users',
      filters: {'id': userId},
    );
  }

  /// Update user profile
  static Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await SupabaseService.update(
      'users',
      data,
      filters: {'id': userId},
    );
  }

  /// Delete user account and all related data
  /// This method handles the complete cleanup process
  static Future<void> deleteUserAccount(String userId) async {
    debugPrint('=== DELETE USER ACCOUNT DEBUG ===');
    debugPrint('Starting deletion process for user: $userId');
    
    try {
      // Step 1: Clean up Supabase storage files
      await _cleanupUserStorage(userId);
      
      // Step 2: Call the database cleanup function
      await SupabaseConfig.client.rpc('cleanup_user_storage', params: {'user_id': userId});
      
      // Step 3: Delete the user using server-side RPC function
      // This will handle both auth deletion and CASCADE cleanup
      await SupabaseConfig.client.rpc('delete_user_account', params: {'user_id': userId});
      
      debugPrint('User account and all related data deleted successfully');
      debugPrint('=== END DELETE USER ACCOUNT DEBUG ===');
      
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      rethrow;
    }
  }

  /// Clean up user's storage files from all buckets
  static Future<void> _cleanupUserStorage(String userId) async {
    debugPrint('Cleaning up storage files for user: $userId');
    
    try {
      // List of storage buckets to clean
      final buckets = [
        'user-avatars',
        'dog-photos', 
        'post-images',
        'chat-media',
        'playdate-albums'
      ];
      
      for (final bucket in buckets) {
        try {
          // List all files in the user's folder
          final files = await SupabaseConfig.client.storage
              .from(bucket)
              .list(path: userId);
          
          if (files.isNotEmpty) {
            debugPrint('Found ${files.length} files in bucket $bucket for user $userId');
            
            // Delete all files in the user's folder
            for (final file in files) {
              if (file.name != null) {
                await SupabaseConfig.client.storage
                    .from(bucket)
                    .remove(['$userId/${file.name}']);
                debugPrint('Deleted file: $bucket/$userId/${file.name}');
              }
            }
          }
        } catch (e) {
          debugPrint('Error cleaning bucket $bucket: $e');
          // Continue with other buckets even if one fails
        }
      }
      
      debugPrint('Storage cleanup completed for user: $userId');
      
    } catch (e) {
      debugPrint('Error during storage cleanup: $e');
      // Don't rethrow - storage cleanup failure shouldn't prevent account deletion
    }
  }

  /// Get user's dogs (including shared access) with enhanced ownership info
  static Future<List<Map<String, dynamic>>> getUserDogsEnhanced(String userId) async {
    debugPrint('=== GET USER DOGS (RPC) ===');
    debugPrint('Getting dogs for user ID: $userId');
    try {
      final result = await SupabaseConfig.client.rpc('get_user_accessible_dogs', params: {
        'p_user_id': userId,
      });
      
      debugPrint('Raw RPC result: $result');
      debugPrint('RPC result type: ${result.runtimeType}');
      debugPrint('RPC result length: ${result?.length}');
      
      if (result == null || result.isEmpty) {
        debugPrint('RPC returned empty, falling back to legacy method');
        return await getUserDogs(userId);
      }
      
      // Try to handle both tuple format and map format
      final rawData = List<dynamic>.from(result);
      final dogsData = <Map<String, dynamic>>[];
      
      for (final item in rawData) {
        Map<String, dynamic> dogMap;
        
        if (item is List) {
          // Tuple format - map positional values to named fields
          debugPrint('Processing tuple format: $item');
          if (item.length >= 8) {
            dogMap = {
              'id': item[0], // Critical: the dog ID
              'name': item[1],
              'breed': item[2],
              'age': item[3],
              'size': item[4],
              'gender': item[5],
              'bio': item[6],
              'main_photo_url': item[7],
              'extra_photo_urls': item.length > 8 ? (item[8] ?? []) : [],
              'updated_at': item.length > 9 ? item[9] : null,
              'user_id': item.length > 10 ? item[10] : userId,
              'ownership_type': item.length > 11 ? item[11] : 'owner',
              'permissions': item.length > 12 ? item[12] : ['view', 'edit'],
              'is_primary': item.length > 13 ? item[13] : true,
              'owner_name': item.length > 14 ? item[14] : null,
              'created_at': item.length > 15 ? item[15] : null,
              'is_active': true,
            };
          } else {
            debugPrint('Tuple too short: ${item.length}, skipping');
            continue;
          }
        } else if (item is Map<String, dynamic>) {
          // Already a map, use as-is
          debugPrint('Processing map format: $item');
          dogMap = Map<String, dynamic>.from(item);
        } else {
          debugPrint('Unknown item format: ${item.runtimeType}, skipping');
          continue;
        }
        
        debugPrint('Mapped dog: ${dogMap['name']} (ID: ${dogMap['id']}) size=${dogMap['size']} gender=${dogMap['gender']}');
        dogsData.add(dogMap);
      }
      
      debugPrint('Accessible dogs count: ${dogsData.length}');
      debugPrint('=== END GET USER DOGS (RPC) ===');
      return dogsData;
    } catch (e) {
      debugPrint('Error getting dogs via RPC: $e (fallback to legacy)');
      return await getUserDogs(userId);
    }
  }

  /// Get user's dogs (including shared access)
  static Future<List<Map<String, dynamic>>> getUserDogs(String userId) async {
    // Check cache first
    final cacheKey = 'user_dogs_$userId';
    final now = DateTime.now();
    
    if (_userDogsCache.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey]!;
      final ageSeconds = now.difference(cacheTime).inSeconds;
      
      if (now.difference(cacheTime).inMinutes < _cacheExpiryMinutes) {
        debugPrint('✓ Returning CACHED user dogs for $userId (age: ${ageSeconds}s)');
        return _userDogsCache[cacheKey]!;
      } else {
        debugPrint('⚠ Cache expired for $userId (age: ${ageSeconds}s)');
      }
    }
    
    debugPrint('=== GET USER DOGS DEBUG (FRESH FETCH) ===');
    debugPrint('Getting dogs for user ID: $userId');
    debugPrint('Search filters: {user_id: $userId, is_active: true}');
    
    // Get directly owned dogs
    final ownedDogs = await SupabaseService.select(
      'dogs',
      filters: {'user_id': userId, 'is_active': true},
      orderBy: 'created_at',
    );
    
    // TODO: Add shared dogs when dog_shared_access table is created
    // final sharedDogs = await SupabaseService.select(
    //   'dogs',
    //   joins: 'INNER JOIN dog_shared_access dsa ON dogs.id = dsa.dog_id',
    //   filters: {'dsa.shared_with_user_id': userId, 'is_active': true},
    // );
    
    final allDogs = [...ownedDogs]; // + sharedDogs when implemented
    
    // Cache the result
    _userDogsCache[cacheKey] = allDogs;
    _cacheTimestamps[cacheKey] = now;
    
    debugPrint('Found ${allDogs.length} dogs for user (${ownedDogs.length} owned)');
    for (var dog in allDogs) {
      debugPrint('Dog raw data: ${dog.toString()}');
      debugPrint('Dog ID specifically: ${dog['id']}');
      debugPrint('Dog keys: ${dog.keys.toList()}');
    }
    
    // Also try getting ALL dogs to see what's in the database
    debugPrint('--- Checking ALL dogs in database ---');
    final allDogsInDb = await SupabaseService.select('dogs', filters: {}, limit: 10);
    debugPrint('Total dogs in database: ${allDogsInDb.length}');
    for (var dog in allDogsInDb) {
      debugPrint('All Dogs - User ID: ${dog['user_id']}, Dog Name: ${dog['name']}, Active: ${dog['is_active']}');
    }
    debugPrint('--- End ALL dogs check ---');
    
    debugPrint('=== END GET USER DOGS DEBUG ===');
    
    return allDogs;
  }

  /// Clear the getUserDogs cache for a specific user
  /// Call this after updating dog profiles to ensure fresh data
  static void clearUserDogsCache(String userId) {
    final cacheKey = 'user_dogs_$userId';
    _userDogsCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
    debugPrint('🗑️ Cleared getUserDogs cache for user: $userId');
  }

  /// Clear all getUserDogs cache
  static void clearAllUserDogsCache() {
    _userDogsCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Cleared all getUserDogs cache');
  }

  /// Add new dog with enhanced ownership support
  static Future<String> addDogWithOwnership(String userId, Map<String, dynamic> dogData) async {
    debugPrint('=== ADD DOG WITH OWNERSHIP ===');
    debugPrint('Adding dog for user ID: $userId');
    debugPrint('Dog data: $dogData');
    
    try {
      // Use the new database function for enhanced ownership
      final result = await SupabaseConfig.client.rpc('add_dog_with_primary_owner', params: {
        'p_user_id': userId,
        'p_dog_data': dogData,
      });
      
      final dogId = result as String;
      debugPrint('✅ Dog created with enhanced ownership, ID: $dogId');
      return dogId;
    } catch (e) {
      debugPrint('❌ Error creating dog with ownership: $e');
      // Fallback to original method
      debugPrint('🔄 Falling back to original dog creation method');
      final legacyResult = await addDog(userId, dogData);
      return legacyResult['id'] as String;
    }
  }

  /// Add new dog (legacy method for backward compatibility)
  static Future<Map<String, dynamic>> addDog(String userId, Map<String, dynamic> dogData) async {
    debugPrint('=== ADD DOG DEBUG ===');
    debugPrint('Adding dog for user ID: $userId');
    debugPrint('Dog data being saved: $dogData');
    
    dogData['user_id'] = userId;
    dogData['created_at'] = DateTime.now().toIso8601String();
    dogData['updated_at'] = DateTime.now().toIso8601String();
    
    // Ensure is_active is set to true
    if (!dogData.containsKey('is_active')) {
      dogData['is_active'] = true;
      debugPrint('Set is_active to true (was missing)');
    } else {
      debugPrint('is_active value: ${dogData['is_active']}');
    }
    
    debugPrint('Final dog data with user_id and is_active: $dogData');
    
    final result = await SupabaseService.insert('dogs', dogData);
    
    debugPrint('Dog saved successfully: ${result.first}');
    debugPrint('=== END ADD DOG DEBUG ===');
    
    return result.first;
  }

  /// Get dog owners/co-owners
  static Future<List<Map<String, dynamic>>> getDogOwners(String dogId) async {
    debugPrint('=== GET DOG OWNERS ===');
    debugPrint('Getting owners for dog ID: $dogId');
    
    try {
      final result = await SupabaseConfig.client
          .from('dog_owners')
          .select('''
            user_id, ownership_type, permissions, is_primary, added_at,
            users:user_id(name, avatar_url)
          ''')
          .eq('dog_id', dogId)
          .order('is_primary', ascending: false);

      debugPrint('Found ${result.length} owners for dog');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error getting dog owners: $e');
      return [];
    }
  }

  /// Update dog profile
  static Future<void> updateDogProfile(String userId, Map<String, dynamic> data) async {
    debugPrint('=== UPDATE DOG PROFILE SERVICE DEBUG ===');
    debugPrint('User ID: $userId');
    debugPrint('Data received: $data');
    
    data['updated_at'] = DateTime.now().toIso8601String();
    
  // Extract dog ID from data and use it as the filter (may be inferred later)
  var dogId = data['id'];
    if (dogId == null) {
      debugPrint('❌ Dog ID is missing from data - attempting fallback resolution');
      try {
        final accessibleDogs = await getUserDogsEnhanced(userId);
        debugPrint('Fallback lookup found ${accessibleDogs.length} accessible dogs');
        if (accessibleDogs.length == 1 && accessibleDogs.first['id'] != null) {
          final inferredId = accessibleDogs.first['id'];
          debugPrint('✅ Inferred dog ID from single accessible dog: $inferredId');
          data['id'] = inferredId; // mutate original data map so subsequent logic works
        } else if (accessibleDogs.isEmpty) {
          debugPrint('❌ No dogs found for user during fallback inference');
        } else {
          debugPrint('⚠️ Multiple dogs found (${accessibleDogs.length}); cannot safely infer ID');
        }
      } catch (e) {
        debugPrint('❌ Fallback dog ID inference failed: $e');
      }
  if (data['id'] == null) {
        debugPrint('⚠️ Dog ID still unresolved after accessibleDogs fallback – trying direct dogs table query');
        try {
          final owned = await SupabaseService.select('dogs', filters: {'user_id': userId, 'is_active': true}, limit: 2);
          debugPrint('Direct dogs table query returned ${owned.length} rows');
          if (owned.length == 1 && owned.first['id'] != null) {
            data['id'] = owned.first['id'];
            debugPrint('✅ Inferred dog ID from direct table query: ${data['id']}');
          } else if (owned.isEmpty) {
            debugPrint('❌ No owned dogs found in direct table query');
          } else {
            debugPrint('⚠️ Multiple owned dogs found (${owned.length}); cannot safely infer ID');
          }
        } catch (e) {
          debugPrint('❌ Direct table query inference failed: $e');
        }
        if (data['id'] == null) {
          debugPrint('❌ Dog ID still unresolved after all fallbacks');
          throw Exception('Dog ID is required for updating dog profile');
        }
      }
  // Refresh dogId variable after inference
  dogId = data['id'];
    }
    
  debugPrint('Dog ID for update: ${data['id']} (local var: $dogId)');
    
    // Remove ID from data since it shouldn't be updated
    final updateData = Map<String, dynamic>.from(data);
    updateData.remove('id');
    
    debugPrint('Final update data (without ID): $updateData');
    debugPrint('Updating dog with ID: $dogId');
    
    try {
      await SupabaseService.update(
        'dogs',
        updateData,
        filters: {'id': dogId}, // Update by dog ID, not user ID
      );
      debugPrint('✅ Database update completed successfully');
    } catch (e) {
      debugPrint('❌ Database update failed: $e');
      rethrow;
    }
    
    debugPrint('=== END UPDATE DOG PROFILE SERVICE DEBUG ===');
  }

  /// Get current dog counts for all parks
  static Future<Map<String, int>> getCurrentDogCounts() async {
    try {
      final response = await SupabaseConfig.client
          .from('park_checkins')
          .select('park_id')
          .eq('is_active', true);

      Map<String, int> counts = {};
      for (var checkin in response) {
        String parkId = checkin['park_id'];
        counts[parkId] = (counts[parkId] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      debugPrint('Error getting dog counts: $e');
      return {};
    }
  }

  /// Listen to real-time dog count updates
  static Stream<Map<String, int>> getDogCountUpdates() {
    return SupabaseConfig.client
        .from('park_checkins')
        .stream(primaryKey: ['id'])
        .map((data) {
          Map<String, int> counts = {};
          for (var checkin in data) {
            if (checkin['is_active'] == true) {
              String parkId = checkin['park_id'];
              counts[parkId] = (counts[parkId] ?? 0) + 1;
            }
          }
          return counts;
        });
  }

  /// Check in to a park
  static Future<void> checkInToPark(String parkId) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user's active dog
      final dogs = await getUserDogs(user.id);
      if (dogs.isEmpty) throw Exception('No active dogs found');
      
      final dogId = dogs.first['id'];

      // Check out from any current park first
      await SupabaseConfig.client
          .from('park_checkins')
          .update({'is_active': false, 'checked_out_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .eq('is_active', true);

      // Check in to new park
      await SupabaseConfig.client
          .from('park_checkins')
          .insert({
            'user_id': user.id,
            'dog_id': dogId,
            'park_id': parkId,
            'checked_in_at': DateTime.now().toIso8601String(),
            'is_active': true,
          });
    } catch (e) {
      debugPrint('Error checking in to park: $e');
      rethrow;
    }
  }
}

class BarkDateMatchService {
  /// Get nearby dogs for matching
  static Future<List<Map<String, dynamic>>> getNearbyDogs(String userId) async {
    return await SupabaseConfig.client
        .from('dogs')
        .select('''
          *,
          users(name, avatar_url, location)
        ''')
        .neq('user_id', userId)
        .eq('is_active', true)
        .limit(50);
  }

  /// Record a bark/pass action
  static Future<bool> recordMatch({
    required String userId,
    required String targetUserId,
    required String dogId,
    required String targetDogId,
    required String action, // 'bark' or 'pass'
  }) async {
    // Check if target user already barked at current user
    final existingMatch = await SupabaseService.selectSingle(
      'matches',
      filters: {
        'user_id': targetUserId,
        'target_user_id': userId,
        'dog_id': targetDogId,
        'target_dog_id': dogId,
        'action': 'bark',
      },
    );

    final isMutual = existingMatch != null && action == 'bark';

    // Insert current user's action
    await SupabaseService.insert('matches', {
      'user_id': userId,
      'target_user_id': targetUserId,
      'dog_id': dogId,
      'target_dog_id': targetDogId,
      'action': action,
      'is_mutual': isMutual,
    });

    // If mutual match, update the existing match record
    if (isMutual) {
      await SupabaseService.update(
        'matches',
        {'is_mutual': true},
        filters: {'id': existingMatch['id']},
      );
    }

    return isMutual;
  }

  /// Get mutual matches
  static Future<List<Map<String, dynamic>>> getMutualMatches(String userId) async {
    final data = await SupabaseConfig.client
        .from('matches')
        .select('''
          *,
          target_user:users(id, name, avatar_url),
          target_dog:dogs(*)
        ''')
        .eq('user_id', userId)
        .eq('is_mutual', true)
        .order('created_at', ascending: false);
    
    return data;
  }
}

class BarkDateMessageService {
  /// Send message
  static Future<Map<String, dynamic>> sendMessage({
    required String matchId,
    required String senderId,
    required String receiverId,
    required String content,
    String messageType = 'text',
  }) async {
    final data = {
      'match_id': matchId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
    };

    final result = await SupabaseService.insert('messages', data);
    return result.first;
  }

  /// Get messages for a match
  static Future<List<Map<String, dynamic>>> getMessages(String matchId) async {
    return await SupabaseConfig.client
        .from('messages')
        .select('''
          *,
          sender:users(name, avatar_url)
        ''')
        .eq('match_id', matchId)
        .order('created_at', ascending: true);
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead(String matchId, String userId) async {
    await SupabaseConfig.client
        .from('messages')
        .update({'is_read': true})
        .eq('match_id', matchId)
        .eq('receiver_id', userId);
  }

  /// Get recent conversations
  static Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final data = await SupabaseConfig.client
        .from('messages')
        .select('''
          *,
          sender:users(name, avatar_url),
          receiver:users(name, avatar_url)
        ''')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);
    
    // Group by match_id and return latest message for each conversation
    final conversations = <String, Map<String, dynamic>>{};
    for (final message in data) {
      final matchId = message['match_id'];
      if (!conversations.containsKey(matchId)) {
        conversations[matchId] = message;
      }
    }
    
    return conversations.values.toList();
  }
}

class BarkDatePlaydateService {
  /// Create playdate
  static Future<Map<String, dynamic>> createPlaydate(Map<String, dynamic> playdateData) async {
    playdateData['created_at'] = DateTime.now().toIso8601String();
    playdateData['updated_at'] = DateTime.now().toIso8601String();
    
    final result = await SupabaseService.insert('playdates', playdateData);
    return result.first;
  }

  /// Get user's playdates
  static Future<List<Map<String, dynamic>>> getUserPlaydates(String userId) async {
    return await SupabaseConfig.client
        .from('playdates')
        .select('''
          *,
          organizer:users(name, avatar_url),
          participant:users(name, avatar_url)
        ''')
        .or('organizer_id.eq.$userId,participant_id.eq.$userId')
        .order('scheduled_at', ascending: false);
  }

  /// Join playdate
  static Future<void> joinPlaydate(String playdateId, String userId, String dogId) async {
    await SupabaseService.insert('playdate_participants', {
      'playdate_id': playdateId,
      'user_id': userId,
      'dog_id': dogId,
    });
  }

  /// Update playdate status
  static Future<void> updatePlaydateStatus(String playdateId, String status) async {
    await SupabaseService.update(
      'playdates',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      filters: {'id': playdateId},
    );
  }
}

class BarkDateSocialService {
  /// Create post
  static Future<Map<String, dynamic>> createPost({
    required String userId,
    required String content,
    String? dogId,
    List<String>? imageUrls,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    final data = {
      'user_id': userId,
      'content': content,
      'dog_id': dogId,
      'image_urls': imageUrls ?? [],
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Debug logging
    debugPrint('=== CREATE POST DEBUG ===');
    debugPrint('Creating post with data: $data');
    debugPrint('User ID: $userId');
    debugPrint('Dog ID: $dogId');
    debugPrint('Content: $content');
    debugPrint('Image URLs: $imageUrls');

    final result = await SupabaseService.insert('posts', data);
    debugPrint('Post created successfully: ${result.first}');
    debugPrint('=== END CREATE POST DEBUG ===');
    
    return result.first;
  }

  /// Get social feed posts
  static Future<List<Map<String, dynamic>>> getFeedPosts({int limit = 20, int offset = 0}) async {
    return await SupabaseConfig.client
        .from('posts')
        .select('''
          *,
          user:users(name, avatar_url),
          dog:dogs(name, breed, main_photo_url)
        ''')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
  }

  /// Like/unlike post
  static Future<void> togglePostLike(String postId, String userId) async {
    final existingLike = await SupabaseService.selectSingle(
      'post_likes',
      filters: {'post_id': postId, 'user_id': userId},
    );

    if (existingLike != null) {
      // Unlike
      await SupabaseService.delete(
        'post_likes',
        filters: {'id': existingLike['id']},
      );
      
      // Decrement likes count - simple update for now
      final currentPost = await SupabaseService.selectSingle('posts', filters: {'id': postId});
      if (currentPost != null) {
        await SupabaseService.update('posts', {
          'likes_count': (currentPost['likes_count'] ?? 1) - 1,
        }, filters: {'id': postId});
      }
    } else {
      // Like
      await SupabaseService.insert('post_likes', {
        'post_id': postId,
        'user_id': userId,
      });
      
      // Increment likes count - simple update for now
      final currentPost = await SupabaseService.selectSingle('posts', filters: {'id': postId});
      if (currentPost != null) {
        await SupabaseService.update('posts', {
          'likes_count': (currentPost['likes_count'] ?? 0) + 1,
        }, filters: {'id': postId});
      }
    }
  }

  /// Get comments for a post with user and dog data
  static Future<List<Map<String, dynamic>>> getPostComments(String postId) async {
    // First get comments with user data
    final comments = await SupabaseConfig.client
        .from('post_comments')
        .select('''
          *,
          user:users(name, avatar_url)
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    
    // Then get dog data for each user
    for (var comment in comments) {
      final userId = comment['user_id'];
      if (userId != null) {
        final dogs = await SupabaseConfig.client
            .from('dogs')
            .select('name, main_photo_url')
            .eq('user_id', userId)
            .limit(1);
        
        if (dogs.isNotEmpty) {
          comment['dog'] = dogs.first;
        }
      }
    }
    
    return comments;
  }

  /// Add comment to post
  static Future<Map<String, dynamic>> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    final data = {
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final result = await SupabaseService.insert('post_comments', data);
    
    // Update comments count on post
    final currentPost = await SupabaseService.selectSingle('posts', filters: {'id': postId});
    if (currentPost != null) {
      await SupabaseService.update('posts', {
        'comments_count': (currentPost['comments_count'] ?? 0) + 1,
      }, filters: {'id': postId});
    }
    
    return result.first;
  }

  /// Delete comment
  static Future<void> deleteComment(String commentId, String postId) async {
    await SupabaseService.delete(
      'post_comments',
      filters: {'id': commentId},
    );

    // Update comments count on post
    final currentPost = await SupabaseService.selectSingle('posts', filters: {'id': postId});
    if (currentPost != null) {
      await SupabaseService.update('posts', {
        'comments_count': (currentPost['comments_count'] ?? 1) - 1,
      }, filters: {'id': postId});
    }
  }
}

class BarkDateNotificationService {
  /// Create notification
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    await SupabaseService.insert('notifications', {
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
    });
  }

  /// Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    return await SupabaseService.select(
      'notifications',
      filters: {'user_id': userId},
      orderBy: 'created_at',
      ascending: false,
      limit: 50,
    );
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    await SupabaseService.update(
      'notifications',
      {'is_read': true},
      filters: {'id': notificationId},
    );
  }
}