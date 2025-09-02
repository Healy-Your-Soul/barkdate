import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PlaydateRecapScreen extends StatefulWidget {
  final String playdateId;
  final Map<String, dynamic> playdateData;

  const PlaydateRecapScreen({
    super.key,
    required this.playdateId,
    required this.playdateData,
  });

  @override
  State<PlaydateRecapScreen> createState() => _PlaydateRecapScreenState();
}

class _PlaydateRecapScreenState extends State<PlaydateRecapScreen> {
  final TextEditingController _recapController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  int _experienceRating = 5;
  int _locationRating = 5;
  bool _shareToFeed = false;
  bool _isSubmitting = false;
  
  List<XFile> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  List<Map<String, dynamic>> _participatingDogs = [];
  Set<String> _taggedDogIds = {};

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  @override
  void dispose() {
    _recapController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      // Get all participating dogs
      final participants = await SupabaseConfig.client
          .from('playdate_participants')
          .select('*, dog:dogs(*), user:users(*)')
          .eq('playdate_id', widget.playdateId);

      setState(() {
        _participatingDogs = participants;
        // Auto-tag all participating dogs
        _taggedDogIds = participants
            .map((p) => p['dog_id'] as String)
            .toSet();
      });
    } catch (e) {
      debugPrint('Error loading participants: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick images')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to take photo')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    final List<String> urls = [];
    
    for (final image in _selectedImages) {
      try {
        final bytes = await image.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final path = 'playdate-recaps/$fileName';
        
        await SupabaseConfig.client.storage
            .from('photos')
            .uploadBinary(path, bytes);
        
        final url = SupabaseConfig.client.storage
            .from('photos')
            .getPublicUrl(path);
        
        urls.add(url);
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }
    
    return urls;
  }

  Future<void> _submitRecap() async {
    if (_recapController.text.trim().isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a recap or photos')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user's dog
      final userDogs = await BarkDateUserService.getUserDogs(user.id);
      
      if (userDogs.isEmpty) throw Exception('No dog profile found');
      
      final dogId = userDogs.first['id'];

      // Upload images if any
      List<String> photoUrls = [];
      if (_selectedImages.isNotEmpty) {
        photoUrls = await _uploadImages();
      }

      // Create the recap
      final success = await PlaydateRecapService.createRecap(
        playdateId: widget.playdateId,
        userId: user.id,
        dogId: dogId,
        experienceRating: _experienceRating,
        locationRating: _locationRating,
        recapText: _recapController.text.trim(),
        photos: photoUrls,
        shareToFeed: _shareToFeed,
      );

      if (mounted) {
        if (success) {
          // If sharing to feed, create a social post
          if (_shareToFeed && _recapController.text.trim().isNotEmpty) {
            await _createSocialPost(photoUrls, dogId);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_shareToFeed 
                  ? 'Recap saved and shared to feed! 🎉' 
                  : 'Playdate recap saved! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.pop(context, true);
        } else {
          throw Exception('Failed to save recap');
        }
      }
    } catch (e) {
      debugPrint('Error submitting recap: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _createSocialPost(List<String> photoUrls, String dogId) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      // Create social post with tagged dogs
      final postData = {
        'user_id': user.id,
        'dog_id': dogId,
        'content': _recapController.text.trim(),
        'image_urls': photoUrls,
        'is_public': true,
        'tagged_dogs': _taggedDogIds.toList(),
        'playdate_id': widget.playdateId,
      };

      await SupabaseConfig.client
          .from('posts')
          .insert(postData);

      // Notify tagged dog owners
      for (final taggedDogId in _taggedDogIds) {
        if (taggedDogId != dogId) {
          final taggedDog = await SupabaseConfig.client
              .from('dogs')
              .select('user_id, name')
              .eq('id', taggedDogId)
              .single();

          if (taggedDog['user_id'] != user.id) {
            await NotificationService.createNotification(
              userId: taggedDog['user_id'],
              type: 'social',
              actionType: 'dog_tagged',
              title: 'Your dog was tagged!',
              body: '${taggedDog['name']} was tagged in a playdate recap',
              relatedId: widget.playdateId,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error creating social post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playdate Recap'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          if (!_isSubmitting)
            TextButton(
              onPressed: _submitRecap,
              child: Text(
                'Save',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playdate info card
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playdateData['title'] ?? 'Playdate',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          widget.playdateData['location'] ?? 'Unknown location',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(DateTime.parse(widget.playdateData['scheduled_at'])),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Experience rating
            Text(
              'How was the experience?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _experienceRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _experienceRating = index + 1;
                    });
                  },
                );
              }),
            ),
            
            const SizedBox(height: 24),
            
            // Location rating
            Text(
              'How was the location?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _locationRating ? Icons.star : Icons.star_border,
                    color: Colors.blue,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _locationRating = index + 1;
                    });
                  },
                );
              }),
            ),
            
            const SizedBox(height: 24),
            
            // Recap text
            Text(
              'Share your experience',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recapController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'How did the playdate go? Any fun moments to share?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Photos section
            Text(
              'Add Photos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Photo grid
            if (_selectedImages.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(
                                _selectedImages[index].path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            
            // Add photo buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('From Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Tagged dogs section
            if (_participatingDogs.isNotEmpty) ...[
              Text(
                'Tag Dogs',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _participatingDogs.map((participant) {
                  final dog = participant['dog'] as Map<String, dynamic>?;
                  if (dog == null) return const SizedBox.shrink();
                  
                  final dogId = dog['id'] as String;
                  final isTagged = _taggedDogIds.contains(dogId);
                  
                  return FilterChip(
                    label: Text(dog['name'] ?? 'Unknown'),
                    selected: isTagged,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _taggedDogIds.add(dogId);
                        } else {
                          _taggedDogIds.remove(dogId);
                        }
                      });
                    },
                    avatar: CircleAvatar(
                      backgroundImage: dog['main_photo_url'] != null
                          ? NetworkImage(dog['main_photo_url'])
                          : null,
                      child: dog['main_photo_url'] == null
                          ? const Icon(Icons.pets, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            
            // Share to feed option
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: CheckboxListTile(
                title: const Text('Share to Social Feed'),
                subtitle: const Text('Let others see this wonderful playdate!'),
                value: _shareToFeed,
                onChanged: (value) {
                  setState(() {
                    _shareToFeed = value ?? false;
                  });
                },
                secondary: Icon(
                  Icons.share,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRecap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Recap',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}