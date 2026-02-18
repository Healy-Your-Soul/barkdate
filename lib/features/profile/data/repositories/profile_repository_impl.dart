import 'package:barkdate/features/profile/domain/repositories/profile_repository.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/material.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  @override
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final profile = await BarkDateUserService.getUserProfile(userId);
    return profile ?? {};
  }

  @override
  Future<List<Dog>> getUserDogs(String userId) async {
    // Use direct query instead of RPC (RPC has bug that only returns 1 dog)
    final dogsData = await BarkDateUserService.getUserDogs(userId);
    return dogsData.map((data) => Dog.fromJson(data)).toList();
  }

  @override
  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      final response =
          await SupabaseConfig.client.rpc('get_dashboard_stats', params: {
        'p_user_id': userId,
      });

      if (response != null) {
        return {
          'friends': response['barks'] as int? ?? 0,
          'playdates': response['playdates'] as int? ?? 0,
          'barks': response['barks'] as int? ??
              0, // Barks usually means friends/connections
          'alerts': response['alerts'] as int? ?? 0,
        };
      }
    } catch (e) {
      debugPrint('Error fetching user stats: $e');
    }

    return {
      'friends': 0,
      'playdates': 0,
      'barks': 0,
      'alerts': 0,
    };
  }

  @override
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    await BarkDateUserService.updateUserProfile(userId, data);
  }

  @override
  Future<void> signOut() async {
    await SupabaseAuth.signOut();
  }
}
