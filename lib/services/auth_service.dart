import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  static bool get isLoggedIn => _supabase.auth.currentUser != null;

  static String getCurrentUserName() {
    final user = _supabase.auth.currentUser;
    return user?.userMetadata?['name'] ??
        user?.userMetadata?['full_name'] ??
        user?.email?.split('@').first ??
        'User';
  }

  static String? getCurrentUserAvatarUrl() {
    final user = _supabase.auth.currentUser;
    return user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['picture'];
  }

  static String? getCurrentUserEmail() {
    return _supabase.auth.currentUser?.email;
  }
}
