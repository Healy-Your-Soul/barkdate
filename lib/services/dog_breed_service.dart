import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart';

class DogBreedService {
  static final _supabase = SupabaseConfig.client;

  /// Search for breeds matching query
  static Future<List<String>> searchBreeds(String query) async {
    try {
      final response = await _supabase
          .from('dog_breeds')
          .select('name')
          .ilike('name', '%$query%')
          .eq('status', 'approved')
          .limit(10)
          .order('name');
      
      return (response as List).map((e) => e['name'] as String).toList();
    } catch (e) {
      debugPrint('Error searching breeds: $e');
      return [];
    }
  }

  /// Get all approved breeds (cached preferably, but simple query for now)
  static Future<List<String>> getAllBreeds() async {
    try {
      final response = await _supabase
          .from('dog_breeds')
          .select('name')
          .eq('status', 'approved')
          .order('name');
      
      return (response as List).map((e) => e['name'] as String).toList();
    } catch (e) {
      debugPrint('Error getting all breeds: $e');
      return [];
    }
  }

  /// Submit a new breed for approval
  static Future<void> addBreed(String name) async {
    if (name.trim().isEmpty) return;
    
    try {
      // Try to insert. RLS will handle permission. 
      // ON CONFLICT DO NOTHING is handled by database if configured, 
      // or we just catch the unique constraint error.
      await _supabase.from('dog_breeds').upsert(
        {
          'name': name.trim(),
          'status': 'pending', // Force pending for new submissions
          'created_by': SupabaseConfig.auth.currentUser?.id,
        },
        onConflict: 'name',
        ignoreDuplicates: true, 
      );
      debugPrint('Breed submitted: $name');
    } catch (e) {
      // Ignore duplicates or errors silently for UX flow
      debugPrint('Breed submission result: $e');
    }
  }
}
