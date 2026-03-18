import 'package:supabase/supabase.dart';
import 'dart:io';

void main(List<String> args) async {
  const String supabaseUrl = 'https://caottaawpnocywayjmyl.supabase.co';

  // Read keys securely from context variables on invocation
  const String serviceRoleKey =
      String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
  const String testPassword = String.fromEnvironment('TEST_PASSWORD');

  if (serviceRoleKey.isEmpty || testPassword.isEmpty) {
    print(
        '❌ Error: SUPABASE_SERVICE_ROLE_KEY and TEST_PASSWORD must be provided!');
    return;
  }

  print('🌱 Starting User Seeding using Admin API...');

  // Initialize standard SupabaseClient
  final client = SupabaseClient(supabaseUrl, serviceRoleKey);

  final testEmails = ['test_user1@example.com', 'test_user2@example.com'];

  for (final email in testEmails) {
    try {
      final userResponse = await client.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: testPassword,
          emailConfirm: true, // 👈 Auto-confirmed solely for these guys!
        ),
      );
      final userId = userResponse.user?.id;
      print('✅ Seeding user created: $email (ID: $userId)');

      if (userId != null) {
        // 2. Insert into users table to make profile complete
        await client.from('users').upsert({
          'id': userId,
          'name': 'Test User ${email.split('@').first}',
          'email': email,
        });

        // 3. Insert into dogs table to make profileStatus complete
        await client.from('dogs').upsert({
          'user_id': userId,
          'name': 'Buddy',
          'breed': 'Golden Retriever',
          'age': 3,
          'size': 'Medium',
          'gender': 'Male',
          'is_active': true,
        });
        print('🌱 Seeding complete: Profile & Dog row created for $email');
      }
    } catch (e) {
      print('ℹ️ User skip/exists ($email): ${e.toString().split('\n').first}');

      // Even if createUser fails with email_exists, verify rows exist for this user IF we can fetch their ID.
      // Since admin.createUser catches duplicate, we can fetch the ID from existing auth user index to safely backfill:
      try {
        final existing = await client.auth.admin.listUsers();
        final user = existing.firstWhere((u) => u.email == email);

        await client
            .from('users')
            .upsert({'id': user.id, 'name': 'Test User', 'email': email});
        await client.from('dogs').upsert({
          'user_id': user.id,
          'name': 'Buddy',
          'breed': 'Golden Retriever',
          'age': 3,
          'size': 'Medium',
          'gender': 'Male',
          'is_active': true,
        });
        print('🌱 Fixed existing user $email - Profile/Dog rows backfilled.');
      } catch (e2) {
        print('ℹ️ Could not backfill existing user: $e2');
      }
    }
  }

  print('✅ Seeding complete.');
  exit(0);
}
