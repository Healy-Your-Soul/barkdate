import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';

/// BarkDate-specific Supabase service classes
class BarkDateUserService {
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
      
      // Step 3: Delete the user from auth.users
      // This will automatically trigger CASCADE deletion of all related data
      await SupabaseConfig.client.auth.admin.deleteUser(userId);
      
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

  /// Get user's dogs
  static Future<List<Map<String, dynamic>>> getUserDogs(String userId) async {
    debugPrint('=== GET USER DOGS DEBUG ===');
    debugPrint('Getting dogs for user ID: $userId');
    debugPrint('Search filters: {user_id: $userId, is_active: true}');
    
    final dogs = await SupabaseService.select(
      'dogs',
      filters: {'user_id': userId, 'is_active': true},
      orderBy: 'created_at',
    );
    
    debugPrint('Found ${dogs.length} dogs for user');
    for (var dog in dogs) {
      debugPrint('Dog: ${dog.toString()}');
    }
    
    // Also try getting ALL dogs to see what's in the database
    debugPrint('--- Checking ALL dogs in database ---');
    final allDogs = await SupabaseService.select('dogs', filters: {}, limit: 10);
    debugPrint('Total dogs in database: ${allDogs.length}');
    for (var dog in allDogs) {
      debugPrint('All Dogs - User ID: ${dog['user_id']}, Dog Name: ${dog['name']}, Active: ${dog['is_active']}');
    }
    debugPrint('--- End ALL dogs check ---');
    
    debugPrint('=== END GET USER DOGS DEBUG ===');
    
    return dogs;
  }

  /// Add new dog
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

  /// Update dog profile
  static Future<void> updateDogProfile(String userId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await SupabaseService.update(
      'dogs',
      data,
      filters: {'user_id': userId},
    );
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