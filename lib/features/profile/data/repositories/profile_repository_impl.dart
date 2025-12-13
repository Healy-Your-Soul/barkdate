import 'package:barkdate/features/profile/domain/repositories/profile_repository.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';

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
    // TODO: Implement actual stats fetching from services
    // For now, returning mock/placeholder stats or basic counts if available
    // We could add a method to BarkDateUserService to fetch these aggregated stats
    
    // Example:
    // final friendsCount = await BarkDateSocialService.getFriendsCount(userId);
    // final playdatesCount = await BarkDatePlaydateService.getPlaydatesCount(userId);
    
    return {
      'friends': 0,
      'playdates': 0,
      'barks': 0,
    };
  }

  @override
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await BarkDateUserService.updateUserProfile(userId, data);
  }

  @override
  Future<void> signOut() async {
    await SupabaseAuth.signOut();
  }
}
