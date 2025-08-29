import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/widgets/enhanced_image_picker.dart';
import 'package:barkdate/services/selected_image.dart';

enum EditMode { createProfile, editDog, editOwner, editBoth }

class CreateProfileScreen extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final bool locationEnabled;
  final String? userId; // Add userId parameter
  final EditMode editMode; // Replace isEditing with editMode

  const CreateProfileScreen({
    super.key,
    this.userName,
    this.userEmail,
    this.locationEnabled = true,
    this.userId, // Optional - will get from auth if not provided
    this.editMode = EditMode.createProfile, // Default to creation
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
  Map<String, dynamic>? _dogProfile; // Track existing dog data
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ownerNameController.text = widget.userName ?? '';
    // Note: We don't pre-fill email in any field since users should enter their own info
    
    // Load existing data if in any edit mode
    if (widget.editMode != EditMode.createProfile) {
      _loadExistingData();
    }
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

  /// Load existing user and dog data for edit mode
  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
    
    try {
      String? userId = widget.userId ?? SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      // Load user profile
      final userProfile = await SupabaseService.selectSingle(
        'users',
        filters: {'id': userId},
      );
      
      if (userProfile != null) {
        _ownerNameController.text = userProfile['name'] ?? '';
        _ownerBioController.text = userProfile['bio'] ?? '';
        _ownerLocationController.text = userProfile['location'] ?? '';
        
        // Load existing owner avatar
        if (userProfile['avatar_url'] != null && userProfile['avatar_url'].toString().isNotEmpty) {
          final avatarImage = await _loadImageFromUrl(userProfile['avatar_url']);
          if (avatarImage != null && mounted) {
            setState(() {
              _ownerPhoto = avatarImage;
            });
          }
        }
      }

      // Load dog profile
      final dogProfiles = await SupabaseService.select(
        'dogs',
        filters: {'user_id': userId},
      );
      
      if (dogProfiles.isNotEmpty) {
        final dogProfile = dogProfiles.first;
        setState(() {
          _dogProfile = dogProfile; // Store dog data for reference
        });
        _dogNameController.text = dogProfile['name'] ?? '';
        _dogBreedController.text = dogProfile['breed'] ?? '';
        _dogAgeController.text = dogProfile['age']?.toString() ?? '';
        _dogBioController.text = dogProfile['bio'] ?? '';
        _dogSize = dogProfile['size'] ?? 'Medium';
        _dogGender = dogProfile['gender'] ?? 'Male';
        
        // Load existing dog photos
        await _loadDogPhotos(dogProfile);
      } else {
        setState(() {
          _dogProfile = null; // No dog exists
        });
      }
    } catch (e) {
      debugPrint('Error loading existing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load dog photos from URLs for edit mode
  Future<void> _loadDogPhotos(Map<String, dynamic> dogProfile) async {
    try {
      List<SelectedImage> loadedPhotos = [];
      
      // Load main photo
      if (dogProfile['main_photo_url'] != null) {
        final mainPhoto = await _loadImageFromUrl(dogProfile['main_photo_url']);
        if (mainPhoto != null) loadedPhotos.add(mainPhoto);
      }
      
      // Load extra photos
      if (dogProfile['extra_photo_urls'] != null) {
        final extraUrls = List<String>.from(dogProfile['extra_photo_urls']);
        for (String url in extraUrls.take(3)) { // Max 3 extra photos
          final photo = await _loadImageFromUrl(url);
          if (photo != null) loadedPhotos.add(photo);
        }
      }
      
      if (mounted) {
        setState(() {
          _dogPhotos = loadedPhotos;
        });
      }
    } catch (e) {
      debugPrint('Error loading dog photos: $e');
    }
  }

  /// Helper to convert network image URL to SelectedImage
  Future<SelectedImage?> _loadImageFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return SelectedImage(
          bytes: response.bodyBytes,
          fileName: url.split('/').last,
          mimeType: 'image/jpeg',
        );
      }
    } catch (e) {
      debugPrint('Error loading image from $url: $e');
    }
    return null;
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
            imageFiles: _dogPhotos,
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
          avatarUrl = await PhotoUploadService.uploadUserAvatar(
            image: _ownerPhoto!,
            userId: userId,
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
      
      // Validate at least 1 photo is required
      if (_dogPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one photo of your dog')),
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

  /// Skip dog step and go directly to owner info
  void _skipDogStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = 1);
  }

  /// Enter app with minimal setup (just user profile, no dog)
  Future<void> _enterAppWithMinimalSetup() async {
    // Validate at least owner name
    if (_ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      String? userId = widget.userId ?? SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user found');
      }

      // Ensure user profile exists
      await _ensureUserProfileExists(userId);

      // Update only owner profile (no dog)
      String? avatarUrl;
      if (_ownerPhoto != null) {
        try {
          avatarUrl = await PhotoUploadService.uploadUserAvatar(
            image: _ownerPhoto!,
            userId: userId,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to BarkDate! You can add your dog anytime from Settings.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to main app
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    // For single-screen edits, skip the stepper UI
    if (widget.editMode == EditMode.editDog) {
      return _buildSingleEditScreen(isDogEdit: true);
    }
    if (widget.editMode == EditMode.editOwner) {
      return _buildSingleEditScreen(isDogEdit: false);
    }
    
    // Keep existing 2-step UI for creation and editBoth
    return _buildTwoStepScreen();
  }

  Widget _buildTwoStepScreen() {
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
          widget.editMode != EditMode.createProfile ? 'Edit Profile' : 'Create Profile',
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
            
            // Action buttons (Next + Skip)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Primary action button
                  SizedBox(
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
                              _currentStep == 0 
                                  ? 'Next: Owner Info' 
                                  : widget.editMode != EditMode.createProfile ? 'Update Profile' : 'Create Profile',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Skip buttons (only for creation mode)
                  if (widget.editMode == EditMode.createProfile) ...[
                    if (_currentStep == 0) ...[
                      // Skip dog step
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isLoading ? null : _skipDogStep,
                          child: Text(
                            'Skip for now - Just set up my profile',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Option to go back and add dog
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isLoading ? null : () {
                            setState(() => _currentStep = 0);
                            _pageController.animateToPage(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Text('← Back to add dog info'),
                        ),
                      ),
                    ],
                    
                    // Enter app without full setup
                    TextButton(
                      onPressed: _isLoading ? null : _enterAppWithMinimalSetup,
                      child: Text(
                        'Enter app with basic setup',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
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
          
          // Dog Photos Layout (Main + Extra)
          _buildDogPhotosSection(),
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

  /// Custom dog photos layout: Large main photo + 3 smaller extra photos
  Widget _buildDogPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Add Photos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Main Photo (Large, Center)
        _buildMainPhotoArea(),
        const SizedBox(height: 16),
        
        // Extra Photos (3 smaller slots)
        _buildExtraPhotosRow(),
        const SizedBox(height: 8),
        
        // Helper text
        Text(
          'First photo will be your dog\'s main profile picture',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Large main photo area (center, prominent)
  Widget _buildMainPhotoArea() {
    final hasMainPhoto = _dogPhotos.isNotEmpty;
    final mainPhoto = hasMainPhoto ? _dogPhotos[0] : null;

    return Center(
      child: GestureDetector(
        onTap: _pickMainPhoto,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasMainPhoto 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: hasMainPhoto && mainPhoto != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      Image(
                        image: mainPhoto.imageProvider!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                      // Edit/Delete overlay
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPhotoActionButton(
                              icon: Icons.edit,
                              onPressed: _pickMainPhoto,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            _buildPhotoActionButton(
                              icon: Icons.delete,
                              onPressed: () => _removePhoto(0),
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate, // Material Design icon
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Main Photo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to add',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Row of 3 smaller extra photo slots
  Widget _buildExtraPhotosRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        final photoIndex = index + 1; // +1 because main photo is index 0
        final hasPhoto = _dogPhotos.length > photoIndex;
        final photo = hasPhoto ? _dogPhotos[photoIndex] : null;

        return GestureDetector(
          onTap: () => _pickExtraPhoto(photoIndex),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPhoto 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: hasPhoto && photo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image(
                          image: photo.imageProvider!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                        // Delete button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: _buildPhotoActionButton(
                            icon: Icons.close,
                            onPressed: () => _removePhoto(photoIndex),
                            backgroundColor: Theme.of(context).colorScheme.error,
                            size: 24,
                            iconSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 24,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Extra',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }),
    );
  }

  /// Small circular action button for photo actions
  Widget _buildPhotoActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 32,
    double iconSize = 18,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Pick main photo (index 0)
  Future<void> _pickMainPhoto() async {
    final image = await context.showImagePicker();
    if (image != null) {
      setState(() {
        if (_dogPhotos.isEmpty) {
          _dogPhotos = [image];
        } else {
          _dogPhotos[0] = image;
        }
      });
    }
  }

  /// Pick extra photo at specific index
  Future<void> _pickExtraPhoto(int index) async {
    final image = await context.showImagePicker();
    if (image != null) {
      setState(() {
        // Ensure list is long enough
        while (_dogPhotos.length <= index) {
          _dogPhotos.add(_dogPhotos.first); // Duplicate main photo as placeholder
        }
        _dogPhotos[index] = image;
      });
    }
  }

  /// Remove photo at index and reorganize
  void _removePhoto(int index) {
    setState(() {
      if (index < _dogPhotos.length) {
        _dogPhotos.removeAt(index);
      }
    });
  }

  /// Build single-screen edit UI (dog or owner only)
  Widget _buildSingleEditScreen({required bool isDogEdit}) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isDogEdit ? (_dogProfile != null ? 'Edit Dog Profile' : 'Add Dog Profile') : 'Edit Owner Profile',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: isDogEdit ? _buildDogInfoStep() : _buildOwnerInfoStep(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSingleEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isDogEdit 
                              ? (_dogProfile != null ? 'Update Dog Profile' : 'Create Dog Profile')
                              : 'Update Owner Profile',
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

  /// Save single edit (dog or owner only)
  Future<void> _saveSingleEdit() async {
    setState(() => _isLoading = true);
    
    try {
      String? userId = widget.userId ?? SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _ensureUserProfileExists(userId);

      if (widget.editMode == EditMode.editDog) {
        // Validate dog info
        if (_dogNameController.text.isEmpty || _dogBreedController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your dog\'s name and breed')),
          );
          return;
        }

        // Upload dog photos
        List<String> dogPhotoUrls = [];
        String? mainPhotoUrl;
        List<String> extraPhotoUrls = [];

        if (_dogPhotos.isNotEmpty) {
          try {
            dogPhotoUrls = await PhotoUploadService.uploadMultipleImages(
              imageFiles: _dogPhotos,
              bucketName: PhotoUploadService.dogPhotosBucket,
              baseFilePath: '$userId/dog/photo',
            );
            mainPhotoUrl = dogPhotoUrls.isNotEmpty ? dogPhotoUrls[0] : null;
            extraPhotoUrls = dogPhotoUrls.length > 1 ? dogPhotoUrls.sublist(1, dogPhotoUrls.length.clamp(1, 4)) : [];
          } catch (e) {
            debugPrint('Error uploading dog photos: $e');
          }
        }

        // Check if dog already exists, then add or update accordingly
        final existingDogs = await BarkDateUserService.getUserDogs(userId);
        
        if (existingDogs.isEmpty) {
          // No dog exists - create a new one (first-time creation)
          await BarkDateUserService.addDog(userId, {
            'name': _dogNameController.text.trim(),
            'breed': _dogBreedController.text.trim(),
            'age': int.tryParse(_dogAgeController.text) ?? 1,
            'size': _dogSize,
            'gender': _dogGender,
            'bio': _dogBioController.text.trim(),
            'main_photo_url': mainPhotoUrl,
            'extra_photo_urls': extraPhotoUrls,
            'photo_urls': dogPhotoUrls,
          });
        } else {
          // Dog exists - update existing profile
          await BarkDateUserService.updateDogProfile(userId, {
            'name': _dogNameController.text.trim(),
            'breed': _dogBreedController.text.trim(),
            'age': int.tryParse(_dogAgeController.text) ?? 1,
            'size': _dogSize,
            'gender': _dogGender,
            'bio': _dogBioController.text.trim(),
            'main_photo_url': mainPhotoUrl,
            'extra_photo_urls': extraPhotoUrls,
            'photo_urls': dogPhotoUrls,
          });
        }

      } else if (widget.editMode == EditMode.editOwner) {
        // Validate owner info
        if (_ownerNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your name')),
          );
          return;
        }

        // Upload owner avatar
        String? avatarUrl;
        if (_ownerPhoto != null) {
          try {
            avatarUrl = await PhotoUploadService.uploadUserAvatar(
              image: _ownerPhoto!,
              userId: userId,
            );
          } catch (e) {
            debugPrint('Error uploading avatar: $e');
          }
        }

        // Update owner profile
        await BarkDateUserService.updateUserProfile(userId, {
          'name': _ownerNameController.text.trim(),
          'bio': _ownerBioController.text.trim(),
          'location': _ownerLocationController.text.trim(),
          'avatar_url': avatarUrl,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }

    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
