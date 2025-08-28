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

      // Upload user avatar if selected 📸
      String? avatarUrl;
      if (_ownerPhoto != null) {
        try {
          avatarUrl = await PhotoUploadService.uploadUserAvatar(
            image: _ownerPhoto!,
            userId: userId,
          );
        } catch (e) {
          debugPrint('Error uploading avatar: $e');
          // Continue without avatar
        }
      }

      // Update user profile in database 🎉
      await BarkDateUserService.updateUserProfile(userId, {
        'name': _ownerNameController.text.trim(),
        'bio': _ownerBioController.text.trim(),
        'location': _ownerLocationController.text.trim(),
        'avatar_url': avatarUrl,
      });

      // 1) Add dog profile first (without photos) to get real dog_id 🐕
      final dogData = await BarkDateUserService.addDog(userId, {
        'name': _dogNameController.text.trim(),
        'breed': _dogBreedController.text.trim(),
        'age': int.tryParse(_dogAgeController.text) ?? 1,
        'size': _dogSize,
        'gender': _dogGender,
        'bio': _dogBioController.text.trim(),
        'photo_urls': [],
      });

      // 2) If user selected photos, upload them under {user_id}/{dog_id}/photo_*.jpg and then update dog
      if (_dogPhotos.isNotEmpty && dogData.isNotEmpty) {
        try {
          final dogId = dogData['id'] as String;
          final uploadedUrls = await PhotoUploadService.uploadDogPhotos(
            imageFiles: _dogPhotos,
            dogId: dogId,
            userId: userId,
          );

          if (uploadedUrls.isNotEmpty) {
            await SupabaseService.update(
              'dogs',
              {
                'photo_urls': uploadedUrls,
                'updated_at': DateTime.now().toIso8601String(),
              },
              filters: {'id': dogId},
            );
          }
        } catch (e) {
          debugPrint('Error uploading/updating dog photos: $e');
        }
      }
      
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
      // Validate owner info
      if (_ownerNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
        return;
      }
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 1);
    } else {
      // Validate dog info
      if (_dogNameController.text.isEmpty || _dogBreedController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields')),
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
                  _buildOwnerInfoStep(),
                  _buildDogInfoStep(),
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
                          _currentStep == 0 ? 'Next' : 'Create Profile',
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
            'Your Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us a bit about yourself',
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
            'Your Dog',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Let's create a profile for your furry friend",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          
          // Dog photos (multi-image gallery)
          EnhancedImagePicker(
            allowMultiple: true,
            maxImages: 5,
            initialImages: _dogPhotos,
            onImagesChanged: (images) {
              setState(() {
                _dogPhotos = images;
              });
            },
            title: 'Dog Photos',
            showPreview: true,
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
