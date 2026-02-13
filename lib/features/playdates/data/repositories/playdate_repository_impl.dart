import 'package:barkdate/features/playdates/domain/repositories/playdate_repository.dart';
import 'package:barkdate/supabase/barkdate_services.dart';

class PlaydateRepositoryImpl implements PlaydateRepository {
  @override
  Future<List<Map<String, dynamic>>> getUserPlaydates(String userId) async {
    return await BarkDatePlaydateService.getUserPlaydates(userId);
  }

  @override
  Future<Map<String, dynamic>> createPlaydate(Map<String, dynamic> playdateData) async {
    return await BarkDatePlaydateService.createPlaydate(playdateData);
  }

  @override
  Future<void> joinPlaydate(String playdateId, String userId, String dogId) async {
    await BarkDatePlaydateService.joinPlaydate(playdateId, userId, dogId);
  }

  @override
  Future<void> updatePlaydateStatus(String playdateId, String status) async {
    await BarkDatePlaydateService.updatePlaydateStatus(playdateId, status);
  }
}
