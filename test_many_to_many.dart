import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/models/dog.dart';
import 'lib/services/dog_sharing_service.dart';
import 'lib/supabase/barkdate_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (you'll need to add your keys)
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  print('🚀 Testing Many-to-Many Dog Ownership System...\n');
  
  await testDatabaseFunctions();
}

Future<void> testDatabaseFunctions() async {
  final supabase = Supabase.instance.client;
  
  try {
    print('1️⃣ Testing database tables exist...');
    
    // Test 1: Check if tables exist
    final tablesResult = await supabase
        .from('dog_owners')
        .select('id')
        .limit(1);
    print('✅ dog_owners table exists');
    
    final shareLinksResult = await supabase
        .from('dog_share_links')
        .select('id')
        .limit(1);
    print('✅ dog_share_links table exists');
    
    print('\n2️⃣ Testing helper functions exist...');
    
    // Test 2: Check if functions exist
    final functionsTest = await supabase.rpc('get_user_accessible_dogs', params: {
      'p_user_id': '00000000-0000-0000-0000-000000000000'
    });
    print('✅ get_user_accessible_dogs function exists');
    
    print('\n3️⃣ Testing Dog model...');
    
    // Test 3: Test Dog model
    final testDogData = {
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'name': 'Test Dog',
      'breed': 'Golden Retriever',
      'age': 3,
      'size': 'Large',
      'gender': 'Male',
      'bio': 'Friendly test dog',
      'photo_urls': ['http://example.com/photo1.jpg'],
      'vaccinated': true,
      'neutered': false,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'user_id': '00000000-0000-0000-0000-000000000000',
      'owners': [
        {
          'user_id': '00000000-0000-0000-0000-000000000000',
          'user_name': 'Test Owner',
          'avatar_url': null,
          'ownership_type': 'owner',
          'permissions': ['view', 'edit', 'playdates', 'share'],
          'is_primary': true,
          'added_at': DateTime.now().toIso8601String(),
        }
      ]
    };
    
    final dog = Dog.fromDatabase(testDogData);
    print('✅ Dog.fromDatabase() works');
    print('   - Dog: ${dog.name} (${dog.breed})');
    print('   - Owners: ${dog.owners.length}');
    print('   - Can edit: ${dog.canPerform('edit')}');
    print('   - Ownership display: ${dog.ownershipDisplay}');
    
    print('\n4️⃣ Testing DogSharingService...');
    
    // Test 4: Test sharing service (mock)
    final sharingService = DogSharingService();
    print('✅ DogSharingService instantiated');
    
    // Test URL parsing
    final testUrl = 'https://barkdate.app/share/abc123';
    final token = sharingService.extractShareTokenFromUrl(testUrl);
    print('✅ Share token extraction: $token');
    
    print('\n🎉 All tests passed! Many-to-many system is ready.');
    print('\n📋 Next steps:');
    print('   1. Sign up/login to test user creation');
    print('   2. Create a dog profile to test add_dog_with_primary_owner()');
    print('   3. Generate a share link to test create_dog_share_link()');
    print('   4. Use the share link to test use_dog_share_link()');
    print('   5. Check profile screen shows ownership info correctly');
    
  } catch (e) {
    print('❌ Test failed: $e');
    print('\n🔧 Troubleshooting:');
    print('   - Check Supabase connection');
    print('   - Verify migration was applied');
    print('   - Check if tables and functions exist in database');
  }
}
