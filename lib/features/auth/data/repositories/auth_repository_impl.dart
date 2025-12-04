import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final GoTrueClient _auth;

  AuthRepositoryImpl(this._auth);

  @override
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<AuthResponse> signIn({required String email, required String password}) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<AuthResponse> signUp({required String email, required String password, Map<String, dynamic>? data}) {
    return _auth.signUp(email: email, password: password, data: data);
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}
