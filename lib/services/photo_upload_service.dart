import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/services/selected_image.dart';

/// Upload progress callback types
typedef ProgressCallback = void Function(double progress);
typedef MultiProgressCallback = void Function(int current, int total);

/// Enhanced Photo Upload Service with compression, multi-image support, and progress tracking
/// Think of this as your app's professional photography studio! 📸✨
class PhotoUploadService {
  // Storage bucket names following our secure architecture
  static const String dogPhotosBucket = 'dog-photos';
  static const String userAvatarsBucket = 'user-avatars';
  static const String postImagesBucket = 'post-images';
  static const String chatMediaBucket = 'chat-media';
  static const String playdateAlbumsBucket = 'playdate-albums';

  /// Compress and optimize image before upload
  static Future<File> compressImage(
    File imageFile, {
    int maxWidth = 1080,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    try {
      // Get temporary directory for compressed image
      final tempDir = await getTemporaryDirectory();
      final compressedFileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedPath = '${tempDir.path}/$compressedFileName';

      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      // Save compressed image to file
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      // Return original file if compression fails
      return imageFile;
    }
  }

  /// Enhanced image picking with multi-selection support
  /// Returns SelectedImage (bytes-based) for web-safety
  static Future<SelectedImage?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
    int maxWidth = 1080,
    int maxHeight = 1920,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final compressed = await _compressBytes(bytes,
            maxWidth: maxWidth, maxHeight: maxHeight, quality: imageQuality);
        return SelectedImage(
          bytes: compressed,
          fileName: image.name,
          mimeType: 'image/jpeg',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Pick multiple images for galleries
  static Future<List<SelectedImage>> pickMultipleImages({
    int maxImages = 10,
    int imageQuality = 85,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: imageQuality,
        maxWidth: 1080,
        maxHeight: 1920,
      );

      // Limit to maxImages
      final limitedImages = images.take(maxImages).toList();
      
      // Convert to Files and compress
      final List<SelectedImage> compressedFiles = [];
      for (final xFile in limitedImages) {
        final bytes = await xFile.readAsBytes();
        final compressed = await _compressBytes(bytes, quality: imageQuality);
        compressedFiles.add(SelectedImage(
          bytes: compressed,
          fileName: xFile.name,
          mimeType: 'image/jpeg',
        ));
      }

      return compressedFiles;
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  /// Core upload method with progress tracking
  static Future<String?> uploadImage({
    required Uint8List bytes,
    required String bucketName,
    required String filePath,
    ProgressCallback? onProgress,
  }) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Supabase Storage with progress tracking
      // On web we must upload bytes; on mobile we can upload file as well.
      await SupabaseConfig.client.storage
          .from(bucketName)
          .uploadBinary(filePath, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));

      // Get the public URL
      final publicUrl = SupabaseConfig.client.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      // Simulate progress for now (Supabase doesn't provide real-time progress)
      onProgress?.call(1.0);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Upload multiple images with progress tracking
  static Future<List<String>> uploadMultipleImages({
    required List<SelectedImage> imageFiles,
    required String bucketName,
    required String baseFilePath,
    MultiProgressCallback? onProgress,
  }) async {
    final List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      try {
        // Create unique file path for each image
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${baseFilePath}_${timestamp}_$i.jpg';
        
        final url = await uploadImage(
          bytes: imageFiles[i].bytes,
          bucketName: bucketName,
          filePath: filePath,
        );
        
        if (url != null) {
          uploadedUrls.add(url);
        }
        
        // Update progress
        onProgress?.call(i + 1, imageFiles.length);
      } catch (e) {
        debugPrint('Error uploading image ${i + 1}: $e');
        // Continue with other images even if one fails
      }
    }
    
    return uploadedUrls;
  }

  /// Upload user avatar
  static Future<String?> uploadUserAvatar({
    required SelectedImage image,
    required String userId,
    ProgressCallback? onProgress,
  }) async {
    final filePath = '$userId/avatar.jpg';
    return await uploadImage(
      bytes: image.bytes,
      bucketName: userAvatarsBucket,
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  /// Upload multiple dog photos for gallery
  static Future<List<String>> uploadDogPhotos({
    required List<SelectedImage> imageFiles,
    required String dogId,
    required String userId,
    MultiProgressCallback? onProgress,
  }) async {
    final baseFilePath = '$userId/$dogId/photo';
    return await uploadMultipleImages(
      imageFiles: imageFiles,
      bucketName: dogPhotosBucket,
      baseFilePath: baseFilePath,
      onProgress: onProgress,
    );
  }

  /// Upload single dog photo
  static Future<String?> uploadDogPhoto({
    required SelectedImage image,
    required String dogId,
    required String userId,
    ProgressCallback? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$userId/$dogId/photo_$timestamp.jpg';
    return await uploadImage(
      bytes: image.bytes,
      bucketName: dogPhotosBucket,
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  /// Upload post image
  static Future<String?> uploadPostImage({
    required SelectedImage image,
    required String postId,
    required String userId,
    int imageIndex = 0,
    ProgressCallback? onProgress,
  }) async {
    final filePath = '$userId/posts/${postId}_$imageIndex.jpg';
    return await uploadImage(
      bytes: image.bytes,
      bucketName: postImagesBucket,
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  /// Upload chat media
  static Future<String?> uploadChatMedia({
    required SelectedImage media,
    required String matchId,
    required String messageId,
    required String userId,
    ProgressCallback? onProgress,
  }) async {
    final filePath = '$matchId/$userId/$messageId.jpg';
    return await uploadImage(
      bytes: media.bytes,
      bucketName: chatMediaBucket,
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  /// Upload playdate photo
  static Future<String?> uploadPlaydatePhoto({
    required SelectedImage image,
    required String playdateId,
    required String userId,
    ProgressCallback? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$playdateId/$userId/memory_$timestamp.jpg';
    return await uploadImage(
      bytes: image.bytes,
      bucketName: playdateAlbumsBucket,
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  /// Delete image from storage
  static Future<void> deleteImage(String imageUrl, String bucketName) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the file path after the bucket name
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        
        await SupabaseConfig.client.storage
            .from(bucketName)
            .remove([filePath]);
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  /// Show enhanced photo picker dialog
  static Future<SelectedImage?> showPhotoPickerDialog(BuildContext context) async {
    return await showModalBottomSheet<SelectedImage?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  'Add Photo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerOption(
                        context,
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: () async {
                          final img = await pickImage(source: ImageSource.camera);
                          if (context.mounted) Navigator.pop(context, img);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPickerOption(
                        context,
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: () async {
                          final img = await pickImage(source: ImageSource.gallery);
                          if (context.mounted) Navigator.pop(context, img);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show multi-image picker dialog
  static Future<List<SelectedImage>?> showMultiImagePickerDialog(
    BuildContext context, {
    int maxImages = 10,
  }) async {
    return await showModalBottomSheet<List<SelectedImage>?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  'Add Photos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Select up to $maxImages photos',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerOption(
                        context,
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: () async {
                          final img = await pickImage(source: ImageSource.camera);
                          if (context.mounted && img != null) {
                            Navigator.pop(context, [img]);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPickerOption(
                        context,
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: () async {
                          final imgs = await pickMultipleImages(maxImages: maxImages);
                          if (context.mounted && imgs.isNotEmpty) {
                            Navigator.pop(context, imgs);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build picker option widget
  static Widget _buildPickerOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Ensure all storage buckets exist with proper configuration
  static Future<void> ensureBucketsExist() async {
    const buckets = [
      userAvatarsBucket,
      dogPhotosBucket,
      postImagesBucket,
      chatMediaBucket,
      playdateAlbumsBucket,
    ];

    for (final bucketName in buckets) {
      await _createBucketIfNotExists(bucketName);
    }
  }

  /// Create a bucket if it doesn't exist
  static Future<void> _createBucketIfNotExists(String bucketName) async {
    try {
      // Try to list buckets to see if it exists
      final buckets = await SupabaseConfig.client.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == bucketName);

      if (!bucketExists) {
        try {
          await SupabaseConfig.client.storage.createBucket(bucketName);
          if (kDebugMode) {
            debugPrint('✅ Created bucket: $bucketName');
          }
        } catch (e) {
          if (e.toString().contains('already exists') || 
              e.toString().contains('409')) {
            if (kDebugMode) {
              debugPrint('ℹ️ Bucket already exists: $bucketName');
            }
          } else {
            debugPrint('❌ Error creating bucket $bucketName: $e');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ Bucket exists: $bucketName');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking/creating bucket $bucketName: $e');
    }
  }
}

/// Upload progress model
class UploadProgress {
  final int current;
  final int total;
  final double percentage;
  final String? currentFileName;
  
  UploadProgress({
    required this.current,
    required this.total,
    required this.percentage,
    this.currentFileName,
  });

  bool get isComplete => current >= total;
}

/// Helper extension for easier photo picking
extension PhotoPickerExtension on BuildContext {
  Future<SelectedImage?> showImagePicker() async {
    return await PhotoUploadService.showPhotoPickerDialog(this);
  }

  Future<List<SelectedImage>?> showMultiImagePicker({int maxImages = 10}) async {
    return await PhotoUploadService.showMultiImagePickerDialog(this, maxImages: maxImages);
  }
}

/// Compress raw bytes (web-safe)
Future<Uint8List> _compressBytes(Uint8List input, {int maxWidth = 1080, int maxHeight = 1920, int quality = 85}) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      input,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return Uint8List.fromList(result);
  } catch (_) {
    return input;
  }
}