import 'package:flutter/material.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/selected_image.dart';

/// Test screen to verify all storage buckets are working
class BucketTestScreen extends StatefulWidget {
  const BucketTestScreen({super.key});

  @override
  State<BucketTestScreen> createState() => _BucketTestScreenState();
}

class _BucketTestScreenState extends State<BucketTestScreen> {
  final Map<String, String> _bucketResults = {};
  bool _isLoading = false;

  final List<Map<String, dynamic>> _buckets = [
    {
      'name': 'Dog Photos',
      'bucket': PhotoUploadService.dogPhotosBucket,
      'description': 'Store dog profile photos (main + extras)',
    },
    {
      'name': 'User Avatars', 
      'bucket': PhotoUploadService.userAvatarsBucket,
      'description': 'Store user profile pictures',
    },
    {
      'name': 'Post Images',
      'bucket': PhotoUploadService.postImagesBucket,
      'description': 'Store social media post images',
    },
    {
      'name': 'Chat Media',
      'bucket': PhotoUploadService.chatMediaBucket,
      'description': 'Store images shared in messages',
    },
    {
      'name': 'Playdate Albums',
      'bucket': PhotoUploadService.playdateAlbumsBucket,
      'description': 'Store playdate memory photos',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Bucket Test'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test all storage buckets to ensure they work correctly',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testAllBuckets,
              child: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test All Buckets'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _buckets.length,
                itemBuilder: (context, index) {
                  final bucket = _buckets[index];
                  final result = _bucketResults[bucket['bucket']];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        _getBucketIcon(bucket['bucket']),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(bucket['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bucket['description']),
                          const SizedBox(height: 4),
                          Text(
                            'Bucket: ${bucket['bucket']}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      trailing: result != null 
                          ? Icon(
                              result == 'success' ? Icons.check_circle : Icons.error,
                              color: result == 'success' ? Colors.green : Colors.red,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBucketIcon(String bucketName) {
    switch (bucketName) {
      case 'dog-photos': return Icons.pets;
      case 'user-avatars': return Icons.person;
      case 'post-images': return Icons.photo;
      case 'chat-media': return Icons.chat;
      case 'playdate-albums': return Icons.photo_album;
      default: return Icons.storage;
    }
  }

  Future<void> _testAllBuckets() async {
    setState(() {
      _isLoading = true;
      _bucketResults.clear();
    });

    // Create a small test image (1x1 pixel)
    final testImageBytes = _createTestImage();
    final testImage = SelectedImage(
      bytes: testImageBytes,
      fileName: 'test.jpg',
      mimeType: 'image/jpeg',
    );

    for (final bucket in _buckets) {
      try {
        await PhotoUploadService.ensureBucketExists(bucket['bucket']);
        
        // Try to upload a test file
        final result = await PhotoUploadService.uploadImage(
          bytes: testImage.bytes,
          bucketName: bucket['bucket'],
          filePath: 'test/bucket_test_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        setState(() {
          _bucketResults[bucket['bucket']] = result != null ? 'success' : 'failed';
        });
      } catch (e) {
        debugPrint('Bucket ${bucket['bucket']} test failed: $e');
        setState(() {
          _bucketResults[bucket['bucket']] = 'error: $e';
        });
      }
    }

    setState(() => _isLoading = false);

    // Show results
    final successCount = _bucketResults.values.where((r) => r == 'success').length;
    final totalCount = _buckets.length;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bucket Test Complete: $successCount/$totalCount working'),
          backgroundColor: successCount == totalCount ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// Create a minimal test image (1x1 pixel JPEG)
  List<int> _createTestImage() {
    // Minimal JPEG header + 1x1 pixel data
    return [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03, 0x02, 0x02, 0x02, 0x03,
      0x03, 0x03, 0x03, 0x04, 0x06, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x06,
      0x06, 0x05, 0x06, 0x09, 0x08, 0x0A, 0x0A, 0x09, 0x08, 0x09, 0x09, 0x0A,
      0x0C, 0x0F, 0x0C, 0x0A, 0x0B, 0x0E, 0x0B, 0x09, 0x09, 0x0D, 0x11, 0x0D,
      0x0E, 0x0F, 0x10, 0x10, 0x11, 0x10, 0x0A, 0x0C, 0x12, 0x13, 0x12, 0x10,
      0x13, 0x0F, 0x10, 0x10, 0x10, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
      0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
      0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x00, 0xFF, 0xD9
    ];
  }
}
