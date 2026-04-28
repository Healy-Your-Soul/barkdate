import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:http/http.dart' as http;

import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/features/profile/presentation/providers/profile_provider.dart';
// import 'package:barkdate/screens/main_navigation.dart'; // Removed unused import to fix circular dependency
import 'package:barkdate/services/selected_image.dart';
import 'package:barkdate/widgets/supabase_auth_wrapper.dart';
import 'package:barkdate/services/dog_breed_service.dart';
import 'package:barkdate/widgets/location_picker_field.dart';
import 'package:barkdate/screens/map_location_picker_screen.dart';

enum EditMode { createProfile, editDog, editOwner, editBoth, addNewDog }

class CreateProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  final EditMode editMode;
  final String? userName;
  final String? userEmail;
  final String? dogId;
  final bool locationEnabled;

  const CreateProfileScreen({
    super.key,
    this.userId,
    this.editMode = EditMode.editDog, // Default to simple dog editing
    this.userName,
    this.userEmail,
    this.dogId,
    this.locationEnabled = false,
  });

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Owner info controllers
  final _ownerNameController = TextEditingController();
  final _ownerBioController = TextEditingController();
  final _ownerLocationController = TextEditingController();
  // Removed old File-based ownerPhoto; using SelectedImage below
  String? _relationshipStatus;

  // Dog info controllers
  final _dogNameController = TextEditingController();
  final _dogBreedController = TextEditingController();
  final _dogAgeController = TextEditingController();
  final _dogBioController = TextEditingController();
  String _dogSize = 'Medium';
  String _dogGender = 'Male';
  bool _isPublic =
      true; // Dog visibility: true = visible in discovery, false = friends only
  List<SelectedImage> _dogPhotos = [];
  SelectedImage? _ownerPhoto;
  Map<String, dynamic>? _dogProfile; // Track existing dog data

  bool _isLoading = false;

  // --- Owner edit (EditMode.editOwner) state ---
  /// Set true whenever the user touches any owner field so we can warn
  /// on back-press and avoid redundant uploads when nothing changed.
  bool _ownerDirty = false;
  double? _ownerLatitude;
  double? _ownerLongitude;
  // Used to anchor the connection-status popup menu under the field at
  // matching width.
  final GlobalKey _connectionFieldKey = GlobalKey();

  // --- Normalization helpers to keep UI and DB in sync for dropdown/segmented fields ---
  String _normalizeSize(dynamic raw) {
    if (raw == null) return 'Medium';
    final v = raw.toString().trim().toLowerCase();
    switch (v) {
      case 'small':
        return 'Small';
      case 'large':
        return 'Large';
      case 'medium':
        return 'Medium';
      default:
        // Fallback if unexpected value stored
        debugPrint('Unknown size "$raw" – defaulting to Medium');
        return 'Medium';
    }
  }

  String _normalizeGender(dynamic raw) {
    if (raw == null) return 'Male';
    final v = raw.toString().trim().toLowerCase();
    switch (v) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        debugPrint('Unknown gender "$raw" – defaulting to Male');
        return 'Male';
    }
  }

  @override
  void initState() {
    super.initState();
    _ownerNameController.text = widget.userName ?? '';
    // Note: We don't pre-fill email in any field since users should enter their own info

    // For the redesigned owner-edit page we track dirtiness so we can prompt
    // Save/Discard on back-press.
    if (widget.editMode == EditMode.editOwner) {
      _ownerNameController.addListener(_markOwnerDirty);
      _ownerBioController.addListener(_markOwnerDirty);
      _ownerLocationController.addListener(_markOwnerDirty);
    }

    // Load existing data if in edit mode (not for new creation or adding new dog)
    if (widget.editMode != EditMode.createProfile &&
        widget.editMode != EditMode.addNewDog) {
      _loadExistingData();
    }
  }

  void _markOwnerDirty() {
    if (!_ownerDirty && mounted) {
      setState(() => _ownerDirty = true);
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
        if (userProfile['relationship_status'] != null) {
          _relationshipStatus = userProfile['relationship_status'];
        }
        _ownerLatitude = (userProfile['latitude'] as num?)?.toDouble();
        _ownerLongitude = (userProfile['longitude'] as num?)?.toDouble();

        // Load existing owner avatar
        if (userProfile['avatar_url'] != null &&
            userProfile['avatar_url'].toString().isNotEmpty) {
          final avatarImage =
              await _loadImageFromUrl(userProfile['avatar_url']);
          if (avatarImage != null && mounted) {
            setState(() {
              _ownerPhoto = avatarImage;
            });
          }
        }
      }

      // Load dog profile using enhanced method for consistency
      final dogProfiles = await BarkDateUserService.getUserDogs(userId);

      if (dogProfiles.isNotEmpty) {
        // Find specific dog by ID if provided, otherwise use first dog
        Map<String, dynamic>? dogProfile;
        if (widget.dogId != null) {
          dogProfile = dogProfiles.firstWhere(
            (d) => d['id'] == widget.dogId,
            orElse: () => dogProfiles.first,
          );
        } else {
          dogProfile = dogProfiles.first;
        }
        setState(() {
          _dogProfile = dogProfile; // Store dog data for reference
        });
        debugPrint('🐕 Loading dog profile from enhanced service:');
        debugPrint('  - Dog data: $dogProfile');
        debugPrint('  - Dog ID: ${dogProfile['id']}');

        _dogNameController.text = dogProfile['name'] ?? '';
        _dogBreedController.text = dogProfile['breed'] ?? '';
        _dogAgeController.text = dogProfile['age']?.toString() ?? '';
        _dogBioController.text = dogProfile['bio'] ?? '';
        final rawSize = dogProfile['size'];
        final rawGender = dogProfile['gender'];
        _dogSize = _normalizeSize(rawSize);
        _dogGender = _normalizeGender(rawGender);
        _isPublic = dogProfile['is_public'] ?? true;

        // Debug: Log the loaded values
        debugPrint('🐕 Dog profile loaded:');
        debugPrint(
            '  - Size from DB raw: "$rawSize" -> normalized: "$_dogSize"');
        debugPrint(
            '  - Gender from DB raw: "$rawGender" -> normalized: "$_dogGender"');
        if (!['Small', 'Medium', 'Large'].contains(_dogSize)) {
          debugPrint(
              '  ! Size value "$_dogSize" not in allowed set – forcing Medium');
          _dogSize = 'Medium';
        }
        if (!['Male', 'Female'].contains(_dogGender)) {
          debugPrint(
              '  ! Gender value "$_dogGender" not in allowed set – forcing Male');
          _dogGender = 'Male';
        }
        debugPrint(
            '  - Age from DB: "${dogProfile['age']}" -> UI shows: "${_dogAgeController.text}"');

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
        setState(() {
          _isLoading = false;
          // Reset dirty after initial load so listeners triggered by
          // controller.text assignments above don't count as user edits.
          _ownerDirty = false;
        });
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
        for (String url in extraUrls.take(3)) {
          // Max 3 extra photos
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
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

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

      // Add breed if new
      if (_dogBreedController.text.isNotEmpty) {
        await DogBreedService.addBreed(_dogBreedController.text);
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
            baseFilePath:
                '$userId/temp/photo', // Use temp folder, will update after getting dogId
          );

          // Organize: first photo = main, rest = extras (max 3)
          mainPhotoUrl = dogPhotoUrls.isNotEmpty ? dogPhotoUrls[0] : null;
          extraPhotoUrls = dogPhotoUrls.length > 1
              ? dogPhotoUrls.sublist(1, dogPhotoUrls.length.clamp(1, 4))
              : [];
        } catch (e) {
          debugPrint('Error uploading dog photos: $e');
        }
      }

      // 2) Add dog profile (DOG FIRST! 🐕)
      await BarkDateUserService.addDog(userId, {
        'name': _dogNameController.text.trim(),
        'breed': _dogBreedController.text.trim(),
        'age': int.tryParse(_dogAgeController.text) ?? 1,
        'size': _dogSize,
        'gender': _dogGender,
        'bio': _dogBioController.text.trim(),
        'main_photo_url': mainPhotoUrl,
        'extra_photo_urls': extraPhotoUrls,
        'photo_urls':
            dogPhotoUrls, // Keep all photos for backward compatibility
        'is_public': _isPublic,
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
        'relationship_status': _relationshipStatus,
      });

      // Success! Profile created with dog-first approach ✅

      if (mounted) {
        // Success! Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear profile cache so auth wrapper knows profile is now complete
        final uid = SupabaseConfig.auth.currentUser?.id;
        if (uid != null) {
          SupabaseAuthWrapper.clearProfileCache(uid);
        }

        // Navigate based on mode:
        // - createProfile mode: Screen is rendered inline by SupabaseAuthWrapper,
        //   so we must use context.go() to navigate to the main app
        // - edit modes: Screen was pushed as a separate route, so we can pop back
        if (widget.editMode == EditMode.createProfile) {
          const HomeRoute().go(context);
        } else {
          Navigator.pop(context, true);
        }
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
      debugPrint('Profile creation error: $e');
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
          const SnackBar(
              content: Text('Please enter your dog\'s name and breed')),
        );
        return;
      }

      // Validate at least 1 photo is required
      if (_dogPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please add at least one photo of your dog')),
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
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

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
        'relationship_status': _relationshipStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Welcome to BarkDate! You can add your dog anytime from Settings.'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear profile cache so it fetches fresh status (now has dog profile)
        final uid = SupabaseConfig.auth.currentUser?.id;
        if (uid != null) {
          SupabaseAuthWrapper.clearProfileCache(uid);
        }

        // Navigate to main app
        const HomeRoute().go(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Setup failed: $e'), backgroundColor: Colors.red),
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
      // Redesigned to match the DogDetailsScreen visual language:
      // SliverAppBar with a large circular avatar on top + in-appbar save,
      // sectioned fields, no fixed bottom button (keyboard-safe).
      return _buildOwnerDetailsStyleScreen();
    }
    // Note: EditMode.addNewDog is no longer reachable from the UI — the
    // "Add Dog" flow now uses `DogDetailsScreen.newDog()` so the add UI
    // matches the edit UI. The enum value is kept so the generated router
    // code compiles; if it's ever hit (e.g. deep link), fall back to the
    // standard two-step screen.
    // Keep existing 2-step UI for creation and editBoth (and the orphaned
    // addNewDog fallback).
    return _buildTwoStepScreen();
  }

  Widget _buildTwoStepScreen() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            widget.editMode != EditMode.createProfile
                ? 'Edit Profile'
                : 'Create Profile',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 2,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
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
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
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
                                    : widget.editMode != EditMode.createProfile
                                        ? 'Update Profile'
                                        : 'Create Profile',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ), // Close GestureDetector
    );
  }

  Widget _buildOwnerInfoStep() {
    // Add keyboard padding so fields stay visible when keyboard opens
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardHeight + 100),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
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

          // Location field with Google Places autocomplete
          LocationPickerField(
            controller: _ownerLocationController,
            hintText: widget.locationEnabled
                ? 'Auto-detected or search...'
                : 'Search your city...',
            onPlaceSelected: (place) {
              debugPrint(
                  '📍 Location selected: ${place.structuredFormatting.mainText}');
            },
          ),
          const SizedBox(height: 24),

          // Relationship Status Dropdown
          DropdownButtonFormField<String>(
            initialValue: _relationshipStatus,
            decoration: InputDecoration(
              labelText: 'Human Connection Status',
              helperText: 'Optional: Let others know your vibe',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.favorite_outline),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            items: const [
              DropdownMenuItem(
                  value: 'Walk Buddy', child: Text('🚶 Walk Buddy')),
              DropdownMenuItem(
                  value: 'Playdates only', child: Text('🎾 Playdates only')),
              DropdownMenuItem(
                  value: 'Coffee & Chaos', child: Text('☕ Coffee & Chaos')),
              DropdownMenuItem(
                  value: 'Single & Dog-Loving',
                  child: Text('🦴 Single & Dog-Loving')),
              DropdownMenuItem(
                  value: 'Ask my dog', child: Text('🐾 Ask my dog')),
              DropdownMenuItem(
                  value: 'Just here for the dogs',
                  child: Text('🔒 Just here for the dogs')),
            ],
            onChanged: (value) {
              setState(() {
                _relationshipStatus = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDogInfoStep() {
    // Add keyboard padding so fields stay visible when keyboard opens
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardHeight + 100),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
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
          // Breed field (Autocomplete)
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return await DogBreedService.searchBreeds(textEditingValue.text);
            },
            initialValue: TextEditingValue(text: _dogBreedController.text),
            onSelected: (String selection) {
              _dogBreedController.text = selection;
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted) {
              // Sync controller
              if (fieldTextEditingController.text != _dogBreedController.text &&
                  fieldTextEditingController.text.isNotEmpty) {
                // Only sync if local is empty or different?
                // Actually we should use the fieldTextEditingController as the main one, but we have _dogBreedController used elsewhere.
                // Let's hook a listener.
              }

              // We need to sync the changes back to _dogBreedController for validation and saving
              fieldTextEditingController.addListener(() {
                _dogBreedController.text = fieldTextEditingController.text;
              });

              // Initial value sync
              if (fieldTextEditingController.text.isEmpty &&
                  _dogBreedController.text.isNotEmpty) {
                fieldTextEditingController.text = _dogBreedController.text;
              }

              return TextFormField(
                controller: fieldTextEditingController,
                focusNode: fieldFocusNode,
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select or enter a breed';
                  }
                  return null;
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: MediaQuery.of(context).size.width -
                        48, // Adjust based on padding
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
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
          const SizedBox(height: 24),

          // Privacy Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isPublic ? Icons.public : Icons.lock,
                  color: _isPublic ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPublic ? 'Visible to Everyone' : 'Friends Only',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        _isPublic
                            ? 'Other users can discover your dog'
                            : 'Only friends can see your dog',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                  activeThumbColor: Colors.green,
                ),
              ],
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
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
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
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
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            _buildPhotoActionButton(
                              icon: Icons.delete,
                              onPressed: () => _removePhoto(0),
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Main Photo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to add',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
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
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
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
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Extra',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
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
          _dogPhotos
              .add(_dogPhotos.first); // Duplicate main photo as placeholder
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

  // _buildAddNewDogScreen() and _addNewDog() were retired — the "Add Dog"
  // flow now uses DogDetailsScreen.newDog() so the add UI matches the edit
  // UI. See lib/features/profile/presentation/screens/dog_details_screen.dart.

  /// Build single-screen edit UI (dog or owner only)
  /// Redesigned owner edit screen (used for EditMode.editOwner).
  /// Mirrors DogDetailsScreen: SliverAppBar with a large circular avatar on
  /// top, save action in the app bar, sectioned fields below — so the keyboard
  /// never fights a fixed bottom button.
  Widget _buildOwnerDetailsStyleScreen() {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_ownerDirty || _isLoading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscardOwnerChanges();
        if (shouldDiscard && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 1,
              leading: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: _onOwnerBackPressed,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4.0, vertical: 8.0),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: IconButton(
                      iconSize: 20,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, color: Colors.black),
                      tooltip: 'Save',
                      onPressed: _isLoading ? null : _saveSingleEdit,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildOwnerAvatarHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _ownerNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Your Name*',
                        hintText: 'John Doe',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerBioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Bio (optional)',
                        hintText: 'Tell other dog owners about yourself...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Location row: autocomplete field + map picker button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: LocationPickerField(
                            controller: _ownerLocationController,
                            hintText: widget.locationEnabled
                                ? 'Auto-detected or search...'
                                : 'Search your city...',
                            onPlaceSelected: (place) {
                              debugPrint(
                                  '📍 Location selected: ${place.structuredFormatting.mainText}');
                              // Free-typed fallback clears any previous map pin;
                              // we'll only persist lat/lng when the map picker
                              // is used.
                              setState(() {
                                _ownerLatitude = null;
                                _ownerLongitude = null;
                              });
                              _markOwnerDirty();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMapPickerButton(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildConnectionStatusPicker(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small "pick on map" affordance next to the location field. Matches the
  /// compact style used on the Create Event screen: an IconButton inside a
  /// rounded, tinted container so the icon drives the size.
  Widget _buildMapPickerButton() {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: _openMapPicker,
        icon: Icon(Icons.map, color: primary),
        tooltip: 'Pick on Map',
      ),
    );
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapLocationResult>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLatitude: _ownerLatitude,
          initialLongitude: _ownerLongitude,
          initialLabel: _ownerLocationController.text.isNotEmpty
              ? _ownerLocationController.text
              : null,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _ownerLatitude = result.latitude;
      _ownerLongitude = result.longitude;
      final label = result.placeName ?? result.address;
      if (label != null && label.isNotEmpty) {
        _ownerLocationController.text = label;
      }
    });
    _markOwnerDirty();
  }

  /// Tappable field that opens a rounded popup menu anchored directly under
  /// the field at matching width. Uses colored Material icons per option
  /// (no emojis), matching the rounded menu style used elsewhere.
  Widget _buildConnectionStatusPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _kConnectionOptions.firstWhere(
      (o) => o.value == _relationshipStatus,
      orElse: () => const _ConnectionOption(
        value: null,
        label: '',
        icon: Icons.favorite_outline,
        color: Colors.grey,
      ),
    );

    return InkWell(
      key: _connectionFieldKey,
      borderRadius: BorderRadius.circular(12),
      onTap: _openConnectionStatusMenu,
      child: IgnorePointer(
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Human Connection Status',
            helperText: 'Optional: Let others know your vibe',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.surface,
            prefixIcon: selected.value == null
                ? const Icon(Icons.favorite_outline)
                : Icon(selected.icon, color: selected.color),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            selected.value ?? 'Pick your vibe',
            style: TextStyle(
              color: selected.value == null
                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                  : colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openConnectionStatusMenu() async {
    final fieldCtx = _connectionFieldKey.currentContext;
    if (fieldCtx == null) return;
    final fieldBox = fieldCtx.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(fieldCtx).context.findRenderObject() as RenderBox;
    final fieldTopLeft = fieldBox.localToGlobal(Offset.zero, ancestor: overlay);
    final fieldSize = fieldBox.size;

    final chosen = await showMenu<String>(
      context: fieldCtx,
      // Position the menu directly under the field, matching its width.
      position: RelativeRect.fromLTRB(
        fieldTopLeft.dx,
        fieldTopLeft.dy + fieldSize.height + 4,
        overlay.size.width - (fieldTopLeft.dx + fieldSize.width),
        overlay.size.height - (fieldTopLeft.dy + fieldSize.height),
      ),
      constraints: BoxConstraints(
        minWidth: fieldSize.width,
        maxWidth: fieldSize.width,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 8,
      items: _kConnectionOptions.map((opt) {
        final isSelected = opt.value == _relationshipStatus;
        return PopupMenuItem<String>(
          value: opt.value!,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: opt.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(opt.icon, color: opt.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected) Icon(Icons.check, size: 18, color: opt.color),
            ],
          ),
        );
      }).toList(),
    );

    if (chosen != null && mounted) {
      setState(() => _relationshipStatus = chosen);
      _markOwnerDirty();
    }
  }

  /// Centralized back-button handler for the owner edit screen. Handles both
  /// the in-appbar arrow and programmatic pops. System back gestures still
  /// fall through the outer [PopScope].
  Future<void> _onOwnerBackPressed() async {
    if (_isLoading) return;
    if (!_ownerDirty) {
      Navigator.of(context).pop();
      return;
    }
    final shouldLeave = await _confirmDiscardOwnerChanges();
    if (shouldLeave && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Show a Save/Discard/Cancel dialog when the user tries to leave the
  /// owner edit screen with unsaved changes. Returns true if the caller
  /// should proceed with the pop (either because changes were saved or
  /// because the user explicitly chose to discard).
  Future<bool> _confirmDiscardOwnerChanges() async {
    final result = await showDialog<_OwnerLeaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unsaved changes'),
        content: const Text(
            'You have unsaved changes to your profile. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _OwnerLeaveAction.cancel),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _OwnerLeaveAction.discard),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _OwnerLeaveAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result == _OwnerLeaveAction.cancel) return false;
    if (result == _OwnerLeaveAction.discard) return true;

    // _OwnerLeaveAction.save — run the normal save path, which already
    // navigates back on success. We return false so PopScope doesn't also
    // try to pop again on top of that navigation.
    await _saveSingleEdit();
    return false;
  }

  /// Large circular avatar + "tap to change" hint, shown in the flexibleSpace
  /// of the owner edit screen. Avatar is explicitly optional.
  Widget _buildOwnerAvatarHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPhoto = _ownerPhoto != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.25),
                Colors.white,
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final img = await context.showImagePicker();
                    if (img != null && mounted) {
                      setState(() => _ownerPhoto = img);
                      _markOwnerDirty();
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primaryContainer,
                          image: hasPhoto
                              ? DecorationImage(
                                  image: MemoryImage(_ownerPhoto!.bytes),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: hasPhoto
                            ? null
                            : Icon(Icons.person,
                                size: 56, color: colorScheme.primary),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  hasPhoto
                      ? 'Tap to change photo'
                      : 'Tap to add photo (optional)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleEditScreen({required bool isDogEdit}) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            isDogEdit
                ? (_dogProfile != null ? 'Edit Dog Profile' : 'Add Dog Profile')
                : 'Edit Owner Profile',
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
                // Form step's own SingleChildScrollView handles scrolling with keyboard padding
                child: isDogEdit ? _buildDogInfoStep() : _buildOwnerInfoStep(),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  keyboardHeight > 0 ? keyboardHeight + 12 : 24,
                ),
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
                                ? (_dogProfile != null
                                    ? 'Update Dog Profile'
                                    : 'Create Dog Profile')
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
      ), // Close GestureDetector
    );
  }

  /// Save single edit (dog or owner only)
  Future<void> _saveSingleEdit() async {
    debugPrint('=== SAVE SINGLE EDIT DEBUG ===');
    debugPrint('Save button pressed');
    debugPrint('Edit mode: ${widget.editMode}');
    debugPrint('Current dog size: $_dogSize');
    debugPrint('Current dog gender: $_dogGender');
    debugPrint('Dog profile: $_dogProfile');

    setState(() => _isLoading = true);

    try {
      String? userId = widget.userId ?? SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('User ID: $userId');
      await _ensureUserProfileExists(userId);

      if (widget.editMode == EditMode.editDog) {
        // Validate dog info
        if (_dogNameController.text.isEmpty ||
            _dogBreedController.text.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please enter your dog\'s name and breed')),
            );
          }
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
            extraPhotoUrls = dogPhotoUrls.length > 1
                ? dogPhotoUrls.sublist(1, dogPhotoUrls.length.clamp(1, 4))
                : [];
          } catch (e) {
            debugPrint('Error uploading dog photos: $e');
          }
        }

        // Check if dog already exists, then add or update accordingly
        final existingDogs =
            await BarkDateUserService.getUserDogsEnhanced(userId);

        debugPrint('🔍 Checking existing dogs:');
        debugPrint('  - existingDogs.isEmpty: ${existingDogs.isEmpty}');
        debugPrint('  - existingDogs.length: ${existingDogs.length}');
        debugPrint('  - _dogProfile: $_dogProfile');
        debugPrint('  - _dogProfile ID: ${_dogProfile?['id']}');
        if (existingDogs.isNotEmpty) {
          debugPrint('  - existingDogs.first: ${existingDogs.first}');
          debugPrint('  - existingDogs.first ID: ${existingDogs.first['id']}');
          debugPrint(
              '  - existingDogs.first keys: ${existingDogs.first.keys.toList()}');
        }

        // Debug: Log what we're about to save
        debugPrint('🔄 Saving dog profile:');
        debugPrint('  - Size: "$_dogSize"');
        debugPrint('  - Gender: "$_dogGender"');
        debugPrint('  - Age: "${_dogAgeController.text}"');

        // Ensure values are normalized before persisting
        _dogSize = _normalizeSize(_dogSize);
        _dogGender = _normalizeGender(_dogGender);
        final dogData = {
          'name': _dogNameController.text.trim(),
          'breed': _dogBreedController.text.trim(),
          'age': int.tryParse(_dogAgeController.text) ?? 1,
          'size': _dogSize,
          'gender': _dogGender,
          'bio': _dogBioController.text.trim(),
          'main_photo_url': mainPhotoUrl,
          'extra_photo_urls': extraPhotoUrls,
          'photo_urls': dogPhotoUrls,
          'is_public': _isPublic, // Privacy setting
        };

        if (existingDogs.isEmpty) {
          // No dog exists - create a new one (first-time creation)
          debugPrint('📝 Creating new dog...');
          await BarkDateUserService.addDog(userId, dogData);
        } else {
          // Dog exists - update existing profile
          // Include the dog ID for the update
          String? dogId;

          // First try to get ID from existingDogs (most reliable source)
          if (existingDogs.isNotEmpty && existingDogs.first['id'] != null) {
            dogId = existingDogs.first['id'];
            debugPrint('🔧 Dog ID from existingDogs: $dogId');
          } else if (_dogProfile != null && _dogProfile!['id'] != null) {
            dogId = _dogProfile!['id'];
            debugPrint('🔧 Dog ID from _dogProfile: $dogId');
          }

          debugPrint('🔍 Dog ID resolution:');
          debugPrint(
              '  - existingDogs: ${existingDogs.isNotEmpty ? existingDogs.first : 'empty'}');
          debugPrint('  - _dogProfile: $_dogProfile');
          debugPrint('  - Final dogId: $dogId');

          if (dogId == null) {
            debugPrint('❌ Could not determine dog ID for update!');
            throw Exception('Could not determine dog ID for update');
          }

          dogData['id'] = dogId;
          debugPrint('  - Complete dogData with ID: $dogData');
          debugPrint('  - About to call updateDogProfile with data: $dogData');
          await BarkDateUserService.updateDogProfile(userId, dogData);
          debugPrint('  - updateDogProfile completed successfully');
        }
      } else if (widget.editMode == EditMode.editOwner) {
        // Validate owner info
        if (_ownerNameController.text.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter your name')),
            );
          }
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
        final ownerUpdate = <String, dynamic>{
          'name': _ownerNameController.text.trim(),
          'bio': _ownerBioController.text.trim(),
          'location': _ownerLocationController.text.trim(),
          'relationship_status': _relationshipStatus,
        };
        // Only touch avatar_url when we actually uploaded a new one, so we
        // don't wipe an existing avatar if the upload failed or the user
        // didn't change the image.
        if (avatarUrl != null) {
          ownerUpdate['avatar_url'] = avatarUrl;
        }
        // Persist lat/lng when the user picked a location on the map.
        if (_ownerLatitude != null && _ownerLongitude != null) {
          ownerUpdate['latitude'] = _ownerLatitude;
          ownerUpdate['longitude'] = _ownerLongitude;
          ownerUpdate['location_updated_at'] = DateTime.now().toIso8601String();
        }
        await BarkDateUserService.updateUserProfile(userId, ownerUpdate);
        if (mounted) {
          setState(() => _ownerDirty = false);
        }
      }

      // Invalidate caches + Riverpod providers so any screen watching this
      // data (Profile tab, Feed, pack card, etc.) rebuilds with the latest
      // values the moment we pop back — no pull-to-refresh required.
      BarkDateUserService.clearUserDogsCache(userId);
      ref.invalidate(userProfileProvider);
      ref.invalidate(userDogsProvider);
      ref.invalidate(profileRepositoryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        debugPrint('✅ Profile update completed - navigating back');
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    debugPrint('=== END SAVE SINGLE EDIT DEBUG ===');
  }
}

/// Action chosen by the user in the "Unsaved changes" dialog.
enum _OwnerLeaveAction { cancel, discard, save }

/// Static definition of the human connection status options: value,
/// display label, and a colored icon to render instead of the old emojis.
class _ConnectionOption {
  final String? value;
  final String label;
  final IconData icon;
  final Color color;

  const _ConnectionOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_ConnectionOption> _kConnectionOptions = [
  _ConnectionOption(
    value: 'Walk Buddy',
    label: 'Walk Buddy',
    icon: Icons.directions_walk,
    color: Color(0xFF388E3C), // green 700
  ),
  _ConnectionOption(
    value: 'Playdates only',
    label: 'Playdates only',
    icon: Icons.sports_tennis,
    color: Color(0xFFF57C00), // orange 700
  ),
  _ConnectionOption(
    value: 'Coffee & Chaos',
    label: 'Coffee & Chaos',
    icon: Icons.local_cafe,
    color: Color(0xFF8D6E63), // brown 400
  ),
  _ConnectionOption(
    value: 'Single & Dog-Loving',
    label: 'Single & Dog-Loving',
    icon: Icons.favorite,
    color: Color(0xFFEC407A), // pink 400
  ),
  _ConnectionOption(
    value: 'Ask my dog',
    label: 'Ask my dog',
    icon: Icons.pets,
    color: Color(0xFFFFA000), // amber 700
  ),
  _ConnectionOption(
    value: 'Just here for the dogs',
    label: 'Just here for the dogs',
    icon: Icons.lock_outline,
    color: Color(0xFF607D8B), // blue grey 500
  ),
];
