import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:barkdate/features/auth/domain/repositories/auth_repository.dart';
import 'package:barkdate/supabase/supabase_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(SupabaseConfig.auth);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user ?? ref.watch(authRepositoryProvider).currentUser;
});
