import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';
import '../models/dog.dart';

class DogSharingService {
  static final _supabase = SupabaseConfig.client;

  /// Generate a share link for a dog
  static Future<String> generateShareLink(String dogId, String dogName, {String accessLevel = 'co_owner'}) async {
    try {
      // Create a sharing token
      final response = await _supabase
          .from('dog_share_links')
          .insert({
            'dog_id': dogId,
            'dog_name_for_verification': dogName,
            'created_by': _supabase.auth.currentUser?.id,
            'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'access_level': accessLevel,
            'max_uses': 1,
            'used_count': 0,
            'is_active': true,
          })
          .select()
          .single();

      final token = response['share_token'];
      
      // Return the share URL
      return 'https://barkdate.app/share/dog/$token?name=${Uri.encodeComponent(dogName)}';
    } catch (e) {
      throw Exception('Failed to generate share link: $e');
    }
  }

  /// Share a dog with another user by user ID
  static Future<void> shareDogWithUser(String dogId, String targetUserId, String accessLevel) async {
    try {
      await _supabase
          .from('dog_owners')
          .insert({
            'dog_id': dogId,
            'user_id': targetUserId,
            'ownership_type': accessLevel, // 'co_owner', 'caregiver', 'dogwalker'
            'permissions': _getPermissionsForAccessLevel(accessLevel),
            'is_primary': false,
            'added_by': _supabase.auth.currentUser?.id,
          });
    } catch (e) {
      throw Exception('Failed to share dog: $e');
    }
  }

  /// Get permissions array for access level
  static List<String> _getPermissionsForAccessLevel(String accessLevel) {
    switch (accessLevel) {
      case 'co_owner':
        return ['view', 'edit', 'playdates', 'share'];
      case 'caregiver':
        return ['view', 'edit', 'playdates'];
      case 'dogwalker':
        return ['view', 'playdates'];
      default:
        return ['view'];
    }
  }

  /// Redeem a share link
  static Future<Dog?> redeemShareLink(String token, String dogName) async {
    try {
      // Validate token and get dog
      final tokenResponse = await _supabase
          .from('dog_share_links')
          .select('dog_id, dog_name_for_verification, expires_at, access_level')
          .eq('share_token', token)
          .eq('dog_name_for_verification', dogName)
          .eq('is_active', true)
          .single();

      // Check if token is expired
      final expiresAt = DateTime.parse(tokenResponse['expires_at']);
      if (expiresAt.isBefore(DateTime.now())) {
        throw Exception('Share link has expired');
      }

      final dogId = tokenResponse['dog_id'];
      final accessLevel = tokenResponse['access_level'];
      
      // Add user to dog_owners
      await _supabase
          .from('dog_owners')
          .insert({
            'dog_id': dogId,
            'user_id': _supabase.auth.currentUser?.id,
            'ownership_type': accessLevel,
            'permissions': _getPermissionsForAccessLevel(accessLevel),
            'is_primary': false,
            'added_by': _supabase.auth.currentUser?.id,
          });

      // Update the share link usage
      await _supabase
          .from('dog_share_links')
          .update({
            'used_count': tokenResponse['used_count'] + 1,
          })
          .eq('share_token', token);

      // Get the dog data
      final dogResponse = await _supabase
          .from('dogs')
          .select()
          .eq('id', dogId)
          .single();

      return Dog.fromJson(dogResponse);
    } catch (e) {
      throw Exception('Failed to redeem share link: $e');
    }
  }

  /// Get all users who have access to a dog
  static Future<List<Map<String, dynamic>>> getDogSharedUsers(String dogId) async {
    try {
      final response = await _supabase
          .from('dog_owners')
          .select('''
            user_id,
            ownership_type,
            permissions,
            is_primary,
            added_at,
            users:user_id(email, name, avatar_url)
          ''')
          .eq('dog_id', dogId)
          .neq('user_id', _supabase.auth.currentUser?.id ?? ''); // Exclude current user

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get shared users: $e');
    }
  }

  /// Remove access for a user
  static Future<void> removeUserAccess(String dogId, String userId) async {
    try {
      await _supabase
          .from('dog_owners')
          .delete()
          .eq('dog_id', dogId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to remove access: $e');
    }
  }

  /// Extract share token from URL (used by DogShareDialog)
  String extractShareTokenFromUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 3 && pathSegments[1] == 'dog') {
      return pathSegments[2];
    }
    return '';
  }
}