import 'package:barkdate/models/dog.dart';

abstract class ProfileRepository {
  Future<Map<String, dynamic>> getUserProfile(String userId);
  Future<List<Dog>> getUserDogs(String userId);
  Future<Map<String, int>> getUserStats(String userId);
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data);
  Future<void> signOut();
}
