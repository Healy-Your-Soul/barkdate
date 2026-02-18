abstract class PlaydateRepository {
  Future<List<Map<String, dynamic>>> getUserPlaydates(String userId);
  Future<Map<String, dynamic>> createPlaydate(
      Map<String, dynamic> playdateData);
  Future<void> joinPlaydate(String playdateId, String userId, String dogId);
  Future<void> updatePlaydateStatus(String playdateId, String status);
}
