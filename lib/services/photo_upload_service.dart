import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling photo uploads to Supabase Storage
/// Think of this as your app's camera and photo album manager! 📸
class PhotoUploadService {
  static const String dogPhotosBucket = 'dog-photos';
  static const String userAvatarsBucket = 'user-avatars';
  
  /// Pick image from gallery or camera
  static Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: 1080, // Reasonable size for mobile
        maxHeight: 1080,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Upload a dog photo to Supabase Storage
  static Future<String?> uploadDogPhoto({
    required File imageFile,
    required String dogId,
    String? oldPhotoUrl, // To replace an existing photo
  }) async {
    try {
      final user = SupabaseAuth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create unique filename like: user_123/dog_456/photo_1234567890.jpg
      final fileName = 'user_${user.id}/dog_$dogId/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Supabase Storage! 🚀
      final response = await SupabaseConfig.client.storage
          .from(dogPhotosBucket)
          .upload(fileName, imageFile);

      // Get the public URL for the uploaded photo
      final publicUrl = SupabaseConfig.client.storage
          .from(dogPhotosBucket)
          .getPublicUrl(fileName);

      // Delete old photo if replacing
      if (oldPhotoUrl != null) {
        await _deletePhotoFromUrl(oldPhotoUrl, dogPhotosBucket);
      }

      return publicUrl;
    } catch (e) {
      print('Error uploading dog photo: $e');
      throw Exception('Failed to upload photo: ${e.toString()}');
    }
  }

  /// Upload a user avatar to Supabase Storage
  static Future<String?> uploadUserAvatar({
    required File imageFile,
    required String userId,
    String? oldAvatarUrl,
  }) async {
    try {
      // Create unique filename like: avatars/user_123_1234567890.jpg
      final fileName = 'avatars/user_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Supabase Storage! 🚀
      await SupabaseConfig.client.storage
          .from(userAvatarsBucket)
          .upload(fileName, imageFile);

      // Get the public URL
      final publicUrl = SupabaseConfig.client.storage
          .from(userAvatarsBucket)
          .getPublicUrl(fileName);

      // Delete old avatar if replacing
      if (oldAvatarUrl != null) {
        await _deletePhotoFromUrl(oldAvatarUrl, userAvatarsBucket);
      }

      return publicUrl;
    } catch (e) {
      print('Error uploading user avatar: $e');
      throw Exception('Failed to upload avatar: ${e.toString()}');
    }
  }

  /// Upload multiple dog photos at once
  static Future<List<String>> uploadMultipleDogPhotos({
    required List<File> imageFiles,
    required String dogId,
  }) async {
    final List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final url = await uploadDogPhoto(
          imageFile: imageFiles[i],
          dogId: dogId,
        );
        if (url != null) {
          uploadedUrls.add(url);
        }
      } catch (e) {
        print('Error uploading photo ${i + 1}: $e');
        // Continue with other photos even if one fails
      }
    }
    
    return uploadedUrls;
  }

  /// Delete a photo from Supabase Storage
  static Future<void> deletePhoto(String fileName, String bucket) async {
    try {
      await SupabaseConfig.client.storage
          .from(bucket)
          .remove([fileName]);
    } catch (e) {
      print('Error deleting photo: $e');
    }
  }

  /// Helper method to delete photo from URL
  static Future<void> _deletePhotoFromUrl(String photoUrl, String bucket) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(photoUrl);
      final fileName = uri.pathSegments.last;
      await deletePhoto(fileName, bucket);
    } catch (e) {
      print('Error deleting photo from URL: $e');
    }
  }

  /// Show photo picker dialog (Gallery vs Camera)
  static Future<File?> showPhotoPickerDialog(BuildContext context) async {
    return await showDialog<File?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await pickImage(source: ImageSource.camera);
                  Navigator.pop(context, file);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Check if Storage buckets exist and create them if needed
  static Future<void> ensureBucketsExist() async {
    try {
      // Try to list buckets to see if they exist
      final buckets = await SupabaseConfig.client.storage.listBuckets();
      
      bool dogPhotosBucketExists = buckets.any((bucket) => bucket.name == dogPhotosBucket);
      bool userAvatarsBucketExists = buckets.any((bucket) => bucket.name == userAvatarsBucket);

      // Create buckets if they don't exist
      if (!dogPhotosBucketExists) {
        await SupabaseConfig.client.storage.createBucket(
          dogPhotosBucket,
          BucketOptions(public: true),
        );
        if (kDebugMode) {
          print('Created $dogPhotosBucket bucket');
        }
      }

      if (!userAvatarsBucketExists) {
        await SupabaseConfig.client.storage.createBucket(
          userAvatarsBucket,
          BucketOptions(public: true),
        );
        if (kDebugMode) {
          print('Created $userAvatarsBucket bucket');
        }
      }
    } catch (e) {
      print('Error ensuring buckets exist: $e');
      // Don't throw here - buckets might already exist
    }
  }
}

/// Helper extension for showing image picker bottom sheet
extension PhotoPickerExtension on BuildContext {
  Future<File?> showImagePicker() async {
    return await PhotoUploadService.showPhotoPickerDialog(this);
  }
}
