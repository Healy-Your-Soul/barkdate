import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Service for content moderation - blocking users and reporting content
/// Used to comply with App Store Guideline 1.2 (User-Generated Content)
class ModerationService {
  // ========================================
  // USER BLOCKING
  // ========================================

  /// Block a user - their content will be hidden from your feed
  static Future<bool> blockUser(String blockedUserId, {String? reason}) async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return false;

      await SupabaseConfig.client.from('user_blocks').insert({
        'blocker_id': currentUserId,
        'blocked_id': blockedUserId,
        'reason': reason,
      });

      debugPrint('✅ Blocked user: $blockedUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  static Future<bool> unblockUser(String blockedUserId) async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return false;

      await SupabaseConfig.client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', blockedUserId);

      debugPrint('✅ Unblocked user: $blockedUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Error unblocking user: $e');
      return false;
    }
  }

  /// Get list of blocked users with their profile info
  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final response = await SupabaseConfig.client
          .from('user_blocks')
          .select(
              '*, blocked_user:users!user_blocks_blocked_id_fkey(id, name, avatar_url)')
          .eq('blocker_id', currentUserId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting blocked users: $e');
      return [];
    }
  }

  /// Check if a specific user is blocked
  static Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final response = await SupabaseConfig.client
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking block status: $e');
      return false;
    }
  }

  /// Get list of blocked user IDs (for filtering queries)
  static Future<List<String>> getBlockedUserIds() async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final response = await SupabaseConfig.client
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);

      return List<String>.from(response.map((r) => r['blocked_id'] as String));
    } catch (e) {
      debugPrint('❌ Error getting blocked IDs: $e');
      return [];
    }
  }

  // ========================================
  // CONTENT REPORTING
  // ========================================

  /// Report content for review
  ///
  /// [contentType]: 'post', 'dog_profile', 'message', 'user', 'playdate', 'event'
  /// [reason]: 'spam', 'harassment', 'inappropriate', 'fake', 'scam', 'other'
  static Future<bool> reportContent({
    required String contentType,
    required String contentId,
    String? reportedUserId,
    required String reason,
    String? details,
  }) async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return false;

      await SupabaseConfig.client.from('content_reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': reportedUserId,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        'details': details,
        'status': 'pending',
      });

      debugPrint('✅ Reported $contentType: $contentId (reason: $reason)');

      // TODO: Send notification to admin (email, Slack webhook, etc.)
      // await _notifyAdmin(contentType, contentId, reason);

      return true;
    } catch (e) {
      debugPrint('❌ Error reporting content: $e');
      return false;
    }
  }

  /// Report a user directly (not specific content)
  static Future<bool> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    return reportContent(
      contentType: 'user',
      contentId: userId,
      reportedUserId: userId,
      reason: reason,
      details: details,
    );
  }

  // ========================================
  // REPORT REASONS (for UI)
  // ========================================

  static const List<Map<String, String>> reportReasons = [
    {'value': 'spam', 'label': 'Spam or Advertising'},
    {'value': 'harassment', 'label': 'Harassment or Bullying'},
    {'value': 'inappropriate', 'label': 'Inappropriate Content'},
    {'value': 'fake', 'label': 'Fake Profile or Scam'},
    {'value': 'scam', 'label': 'Suspicious Activity'},
    {'value': 'other', 'label': 'Other'},
  ];
}
