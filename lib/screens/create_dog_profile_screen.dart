import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/photo_upload_service.dart';
import '../supabase/barkdate_services.dart';
import '../supabase/supabase_config.dart';

class CreateDogProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? existingDogData; // For editing existing dog

  const CreateDogProfileScreen({
    super.key,
    required this.userId,
    this.existingDogData,
  });

  @override
  State<CreateDogProfileScreen> createState() => _CreateDogProfileScreenState();
}

class _CreateDogProfileScreenState extends State<CreateDogProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dogNameController = TextEditingController();
  final _dogBreedController = TextEditingController();
  final _dogAgeController = TextEditingController();
  final _dogBioController = TextEditingController();
  
  String _dogSize = 'Medium';
  String _dogGender = 'Male';
  bool _isLoading = false;
  
  // Photo management - web compatible
  Uint8List? _mainPhotoBytes;
  List<Uint8List?> _extraPhotosBytes = [null, null, null, null]; // 4 extra photos
  final ImagePicker _picker = ImagePicker();

  final List<String> _sizeOptions = ['Small', 'Medium', 'Large'];
  final List<String> _genderOptions = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _dogNameController.dispose();
    _dogBreedController.dispose();
    _dogAgeController.dispose();
    _dogBioController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    if (widget.existingDogData != null) {
      final data = widget.existingDogData!;
      setState(() {
        _dogNameController.text = data['name'] ?? '';
        _dogBreedController.text = data['breed'] ?? '';
        _dogAgeController.text = data['age']?.toString() ?? '';
        _dogBioController.text = data['bio'] ?? '';
        _dogSize = data['size'] ?? 'Medium';
        _dogGender = data['gender'] ?? 'Male';
      });
      
      // Load existing photos from URLs - convert to bytes for web compatibility
      await _loadExistingPhotos(data);
    }
  }

  Future<void> _loadExistingPhotos(Map<String, dynamic> dogData) async {
    try {
      // Load main photo from URL
      if (dogData['main_photo_url'] != null) {
        final imageUrl = dogData['main_photo_url'] as String;
        final response = await _downloadImageFromUrl(imageUrl);
        if (response != null) {
          setState(() {
            _mainPhotoBytes = response;
          });
        }
      }

      // Load extra photos from URLs
      if (dogData['extra_photo_urls'] != null) {
        final extraUrls = List<String>.from(dogData['extra_photo_urls']);
        for (int i = 0; i < extraUrls.length && i < 4; i++) {
          final response = await _downloadImageFromUrl(extraUrls[i]);
          if (response != null) {
            setState(() {
              _extraPhotosBytes[i] = response;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading existing photos: $e');
      // Continue without photos if there's an error
    }
  }

  Future<Uint8List?> _downloadImageFromUrl(String url) async {
    try {
      // For now, we'll skip loading existing images in edit mode
      // The user can add new images if needed, and existing ones are preserved
      return null;
    } catch (e) {
      debugPrint('Error downloading image from URL: $e');
      return null;
    }
  }

  Future<void> _pickImage(int index) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (index == 0) {
            _mainPhotoBytes = bytes;
          } else {
            _extraPhotosBytes[index - 1] = bytes;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Widget _buildPhotoSlot(int index) {
    Uint8List? photoBytes = index == 0 ? _mainPhotoBytes : _extraPhotosBytes[index - 1];
    bool isMainPhoto = index == 0;
    bool hasExistingPhoto = false;
    
    // Check if there's an existing photo for this slot when editing
    if (widget.existingDogData != null) {
      if (isMainPhoto) {
        hasExistingPhoto = widget.existingDogData!['main_photo_url'] != null;
      } else {
        final extraUrls = widget.existingDogData!['extra_photo_urls'];
        hasExistingPhoto = extraUrls != null && 
                          extraUrls is List && 
                          extraUrls.length > (index - 1);
      }
    }
    
    return GestureDetector(
      onTap: () => _pickImage(index),
      child: Container(
        width: isMainPhoto ? 120 : 80,
        height: isMainPhoto ? 120 : 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMainPhoto 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.5),
            width: isMainPhoto ? 2 : 1,
          ),
        ),
        child: photoBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.memory(
                photoBytes,
                fit: BoxFit.cover,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasExistingPhoto ? Icons.edit : Icons.add_a_photo,
                  size: isMainPhoto ? 32 : 24,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  hasExistingPhoto 
                    ? (isMainPhoto ? 'Change' : 'Edit') 
                    : (isMainPhoto ? 'Main' : '${index}'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Future<void> _saveDogProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    // For new dogs, require a main photo. For editing, it's optional (keeps existing)
    if (_mainPhotoBytes == null && widget.existingDogData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo of your dog')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? mainPhotoUrl;
      List<String> extraPhotoUrls = [];

      // Only upload main photo if a new one was selected
      if (_mainPhotoBytes != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        mainPhotoUrl = await PhotoUploadService.uploadImage(
          bytes: _mainPhotoBytes!,
          bucketName: PhotoUploadService.dogPhotosBucket,
          filePath: '${widget.userId}/main_photo_$timestamp.jpg',
        );
      } else if (widget.existingDogData != null) {
        // Keep existing main photo URL
        mainPhotoUrl = widget.existingDogData!['main_photo_url'];
      }

      // Only upload extra photos if new ones were selected
      for (int i = 0; i < _extraPhotosBytes.length; i++) {
        final photoBytes = _extraPhotosBytes[i];
        if (photoBytes != null) {
          final photoTimestamp = DateTime.now().millisecondsSinceEpoch;
          final url = await PhotoUploadService.uploadImage(
            bytes: photoBytes,
            bucketName: PhotoUploadService.dogPhotosBucket,
            filePath: '${widget.userId}/extra_photo_${i}_$photoTimestamp.jpg',
          );
          if (url != null) {
            extraPhotoUrls.add(url);
          }
        }
      }

      // If updating and no new extra photos, keep existing ones
      if (widget.existingDogData != null && extraPhotoUrls.isEmpty) {
        final existingExtraUrls = widget.existingDogData!['extra_photo_urls'];
        if (existingExtraUrls != null) {
          extraPhotoUrls = List<String>.from(existingExtraUrls);
        }
      }

      // Prepare dog data
      final dogData = {
        'name': _dogNameController.text.trim(),
        'breed': _dogBreedController.text.trim(),
        'age': int.parse(_dogAgeController.text.trim()),
        'size': _dogSize,
        'gender': _dogGender,
        'bio': _dogBioController.text.trim(),
        'main_photo_url': mainPhotoUrl,
        'extra_photo_urls': extraPhotoUrls,
      };

      if (widget.existingDogData != null) {
        // Update existing dog - add updated_at timestamp
        dogData['updated_at'] = DateTime.now().toIso8601String();
        await BarkDateUserService.updateDogProfile(
          widget.userId,
          dogData,
        );
      } else {
        // Create new dog - add user_id and created_at
        dogData['user_id'] = widget.userId;
        dogData['created_at'] = DateTime.now().toIso8601String();
        await BarkDateUserService.addDog(widget.userId, dogData);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving dog profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingDogData != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Dog Profile' : 'Add Your Dog'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                isEditing ? 'Update your furry friend\'s info' : 'Tell us about your furry friend!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add photos and details so other dog parents can get to know your pup.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Photo section
              Text(
                'Photos (${_mainPhotoBytes != null ? '1' : '0'} + ${_extraPhotosBytes.where((p) => p != null).length} photos)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              // Main photo + extra photos row
              Row(
                children: [
                  _buildPhotoSlot(0), // Main photo
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 1; i <= 4; i++) _buildPhotoSlot(i),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dog details
              Text(
                'Dog Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _dogNameController,
                decoration: const InputDecoration(
                  labelText: 'Dog Name*',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your dog\'s name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Breed
              TextFormField(
                controller: _dogBreedController,
                decoration: const InputDecoration(
                  labelText: 'Breed*',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your dog\'s breed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Age and Size row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dogAgeController,
                      decoration: const InputDecoration(
                        labelText: 'Age (years)*',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter age';
                        }
                        final age = int.tryParse(value.trim());
                        if (age == null || age < 0 || age > 30) {
                          return 'Please enter a valid age';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _dogSize,
                      decoration: const InputDecoration(
                        labelText: 'Size*',
                        border: OutlineInputBorder(),
                      ),
                      items: _sizeOptions.map((size) {
                        return DropdownMenuItem(
                          value: size,
                          child: Text(size),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _dogSize = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<String>(
                value: _dogGender,
                decoration: const InputDecoration(
                  labelText: 'Gender*',
                  border: OutlineInputBorder(),
                ),
                items: _genderOptions.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _dogGender = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _dogBioController,
                decoration: const InputDecoration(
                  labelText: 'Tell us about your dog\'s personality',
                  border: OutlineInputBorder(),
                  hintText: 'Loves fetch, friendly with other dogs, great with kids...',
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDogProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(isEditing ? 'Update Dog Profile' : 'Create Dog Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
