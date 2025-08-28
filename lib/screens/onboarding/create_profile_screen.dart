import 'package:flutter/material.dart';
import 'dart:io';

import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/widgets/enhanced_image_picker.dart';
import 'package:barkdate/services/selected_image.dart';

class CreateProfileScreen extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final bool locationEnabled;
  final String? userId; // Add userId parameter

  const CreateProfileScreen({
    super.key,
    this.userName,
    this.userEmail,
    this.locationEnabled = true,
    this.userId, // Optional - will get from auth if not provided
  });

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Owner info controllers
  final _ownerNameController = TextEditingController();
  final _ownerBioController = TextEditingController();
  final _ownerLocationController = TextEditingController();
  // Removed old File-based ownerPhoto; using SelectedImage below
  
  // Dog info controllers
  final _dogNameController = TextEditingController();
  final _dogBreedController = TextEditingController();
  final _dogAgeController = TextEditingController();
  final _dogBioController = TextEditingController();
  String _dogSize = 'Medium';
  String _dogGender = 'Male';
  List<SelectedImage> _dogPhotos = [];
  SelectedImage? _ownerPhoto;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ownerNameController.text = widget.userName ?? '';
    // Note: We don't pre-fill email in any field since users should enter their own info
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ownerNameController.dispose();
    _ownerBioController.dispose();
    _ownerLocationController.dispose();
    _dogNameController.dispose();
    _dogBreedController.dispose();
    _dogAgeController.dispose();
    _dogBioController.dispose();
    super.dispose();
  }

  Future<void> _ensureUserProfileExists(String userId) async {
    try {
      // Check if user profile exists
      final existingUser = await SupabaseService.selectSingle(
        'users',
        filters: {'id': userId},
      );

      if (existingUser == null) {
        // Create user profile if it doesn't exist (fallback if trigger didn't work)
        final user = SupabaseAuth.currentUser;
        await SupabaseService.insert('users', {
          'id': userId,
          'email': user?.email ?? '',
          'name': _ownerNameController.text.trim().isNotEmpty 
              ? _ownerNameController.text.trim() 
              : 'User',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error ensuring user profile exists: $e');
      // Continue anyway - user might exist but we had a query error
    }
  }

  Future<void> _createProfile() async {
    setState(() => _isLoading = true);
    
    try {
      // Get user ID - either from parameter or current auth
      String? userId = widget.userId;
      if (userId == null) {
        final user = SupabaseAuth.currentUser;
        if (user == null) {
          throw Exception('No authenticated user found. Please sign in again.');
        }
        userId = user.id;
      }

      // Ensure user profile exists (created by database trigger)
      await _ensureUserProfileExists(userId);

      // 1) Upload dog photos first and organize: main + extras 🐕📸
      List<String> dogPhotoUrls = [];
      String? mainPhotoUrl;
      List<String> extraPhotoUrls = [];
      
      if (_dogPhotos.isNotEmpty) {
        try {
          // Upload all photos first
          dogPhotoUrls = await PhotoUploadService.uploadMultipleImages(
            images: _dogPhotos,
            bucketName: PhotoUploadService.dogPhotosBucket,
            baseFilePath: '$userId/temp/photo', // Use temp folder, will update after getting dogId
          );
          
          // Organize: first photo = main, rest = extras (max 3)
          mainPhotoUrl = dogPhotoUrls.isNotEmpty ? dogPhotoUrls[0] : null;
          extraPhotoUrls = dogPhotoUrls.length > 1 ? dogPhotoUrls.sublist(1, dogPhotoUrls.length.clamp(1, 4)) : [];
        } catch (e) {
          debugPrint('Error uploading dog photos: $e');
        }
      }

      // 2) Add dog profile (DOG FIRST! 🐕)
      final dogData = await BarkDateUserService.addDog(userId, {
        'name': _dogNameController.text.trim(),
        'breed': _dogBreedController.text.trim(),
        'age': int.tryParse(_dogAgeController.text) ?? 1,
        'size': _dogSize,
        'gender': _dogGender,
        'bio': _dogBioController.text.trim(),
        'main_photo_url': mainPhotoUrl,
        'extra_photo_urls': extraPhotoUrls,
        'photo_urls': dogPhotoUrls, // Keep all photos for backward compatibility
      });

      // 3) Upload owner avatar and update owner profile (OWNER SECOND! 👤)
      String? avatarUrl;
      if (_ownerPhoto != null) {
        try {
          avatarUrl = await PhotoUploadService.uploadSingleImage(
            image: _ownerPhoto!,
            bucketName: PhotoUploadService.userAvatarsBucket,
            filePath: '$userId/avatar.jpg',
          );
        } catch (e) {
          debugPrint('Error uploading avatar: $e');
        }
      }

      await BarkDateUserService.updateUserProfile(userId, {
        'name': _ownerNameController.text.trim(),
        'bio': _ownerBioController.text.trim(),
        'location': _ownerLocationController.text.trim(),
        'avatar_url': avatarUrl,
      });

      // Success! Profile created with dog-first approach ✅
      
      if (mounted) {
        // Success! Show confirmation 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Return success to caller (if called from ProfileScreen)
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Profile creation error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate dog info (DOG FIRST!)
      if (_dogNameController.text.isEmpty || _dogBreedController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your dog\'s name and breed')),
        );
        return;
      }
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 1);
    } else {
      // Validate owner info (OWNER SECOND!)
      if (_ownerNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
        return;
      }
      
      _createProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: _previousStep,
              )
            : null,
        title: Text(
          'Create Profile',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 2,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      'Step ${_currentStep + 1} of 2',
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDogInfoStep(), // DOG FIRST! 🐕
                  _buildOwnerInfoStep(), // OWNER SECOND! 👤
                ],
              ),
            ),
            
            // Next button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep == 0 ? 'Next: Owner Info' : 'Create Profile',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👤 Your Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Now tell us about yourself, the proud dog parent!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          
          // Profile photo
          Center(
            child: GestureDetector(
              onTap: () async {
                final img = await context.showImagePicker();
                if (img != null && mounted) {
                  setState(() => _ownerPhoto = img);
                }
              },
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      image: _ownerPhoto != null
                          ? DecorationImage(
                              image: MemoryImage(_ownerPhoto!.bytes),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _ownerPhoto == null
                        ? Icon(
                            Icons.person,
                            size: 50,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Name field
          TextFormField(
            controller: _ownerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Your Name*',
              hintText: 'John Doe',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Bio field
          TextFormField(
            controller: _ownerBioController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Bio (optional)',
              hintText: 'Tell other dog owners about yourself...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Location field
          TextFormField(
            controller: _ownerLocationController,
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: widget.locationEnabled ? 'Auto-detected' : 'Enter your city',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDogInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🐕 Your Dog Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Dogs come first! Let's create your furry friend's profile",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          
          // Dog photos (1 main + 3 extras = 4 total)
          EnhancedImagePicker(
            allowMultiple: true,
            maxImages: 4, // 1 main + 3 extras
            initialImages: _dogPhotos,
            onImagesChanged: (images) {
              setState(() {
                _dogPhotos = images;
              });
            },
            title: 'Dog Photos (1st = Main Profile Photo)',
            showPreview: true,
          ),
          if (_dogPhotos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '📸 First photo will be your dog\'s main profile picture',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 32),
          
          // Dog name field
          TextFormField(
            controller: _dogNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: "Dog's Name*",
              hintText: 'Buddy',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Breed field
          TextFormField(
            controller: _dogBreedController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Breed*',
              hintText: 'Golden Retriever',
              suffixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Age field
          TextFormField(
            controller: _dogAgeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Age (years)',
              hintText: '3',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Size selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Size',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Small', label: Text('Small')),
                  ButtonSegment(value: 'Medium', label: Text('Medium')),
                  ButtonSegment(value: 'Large', label: Text('Large')),
                ],
                selected: {_dogSize},
                onSelectionChanged: (Set<String> selection) {
                  setState(() => _dogSize = selection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Gender selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gender',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Male', label: Text('Male')),
                  ButtonSegment(value: 'Female', label: Text('Female')),
                ],
                selected: {_dogGender},
                onSelectionChanged: (Set<String> selection) {
                  setState(() => _dogGender = selection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Bio field
          TextFormField(
            controller: _dogBioController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Bio/Personality',
              hintText: 'Describe your dog\'s personality...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}
