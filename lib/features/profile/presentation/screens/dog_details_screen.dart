import 'package:flutter/material.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_colors.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/services/conversation_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/features/profile/presentation/providers/profile_provider.dart';
import 'package:barkdate/features/feed/presentation/providers/feed_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:barkdate/widgets/send_walk_sheet.dart';
import 'package:barkdate/services/selected_image.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/dog_breed_service.dart';

class DogDetailsScreen extends ConsumerStatefulWidget {
  final Dog dog;
  final bool startInEditMode;

  /// When true the screen acts as "Add a new dog": it starts in edit mode
  /// with blank fields, hides share/delete affordances, and saves by creating
  /// a new dog row (via [BarkDateUserService.addDog]) instead of updating.
  final bool isNewDog;

  const DogDetailsScreen({
    super.key,
    required this.dog,
    this.startInEditMode = false,
    this.isNewDog = false,
  });

  /// Convenience constructor for the "Add Dog" flow. Wraps an empty [Dog]
  /// owned by the current auth user and flips [isNewDog] on.
  factory DogDetailsScreen.newDog({Key? key}) {
    final user = SupabaseConfig.auth.currentUser;
    final blank = Dog(
      id: '',
      name: '',
      breed: '',
      age: 1,
      size: 'Medium',
      gender: 'Male',
      bio: '',
      photos: const [],
      ownerId: user?.id ?? '',
      ownerName: user?.userMetadata?['name']?.toString() ??
          user?.userMetadata?['full_name']?.toString() ??
          '',
      ownerAvatarUrl: user?.userMetadata?['avatar_url']?.toString(),
      distanceKm: 0,
    );
    return DogDetailsScreen(
      key: key,
      dog: blank,
      startInEditMode: true,
      isNewDog: true,
    );
  }

  @override
  ConsumerState<DogDetailsScreen> createState() => _DogDetailsScreenState();
}

class _DogDetailsScreenState extends ConsumerState<DogDetailsScreen> {
  late PageController _pageController;
  int _currentPhotoIndex = 0;
  bool _isBarked = false;
  bool _isLoading = false;
  String? _friendshipStatus; // null, 'pending', 'accepted', 'declined'
  String? _friendshipId;
  String? _myDogId;
  Map<String, dynamic>? _ownerProfile;
  bool _ownerAvatarError = false;
  bool _isEditMode = false;
  bool _isSavingEdit = false;

  late final TextEditingController _editNameController;
  late final TextEditingController _editBreedController;
  late final TextEditingController _editBioController;

  late String _displayName;
  late String _displayBreed;
  late int _displayAge;
  late String _displayBio;
  late String _displaySize;
  late String _displayGender;

  late String _editSize;
  late String _editGender;
  late int _editAge;

  // Photo state:
  //  - _displayPhotos: current photos shown in the read-only carousel.
  //  - _editPhotoSlots: exactly 3 slots, filled packed at the front (slot 0 = main).
  static const int _kMaxPhotos = 3;
  late List<String> _displayPhotos;
  late List<_PhotoSlot> _editPhotoSlots;

  /// Whether user has made any changes in edit mode
  bool get _hasUnsavedChanges {
    if (!_isEditMode) return false;
    return _editNameController.text.trim() != _displayName ||
        _editBreedController.text.trim() != _displayBreed ||
        _editAge != _displayAge ||
        _editBioController.text.trim() != _displayBio ||
        _editSize != _displaySize ||
        _editGender != _displayGender ||
        _photosChanged();
  }

  bool _photosChanged() {
    // Any newly picked image counts as a change.
    if (_editPhotoSlots.any((s) => s.isPicked)) return true;
    // Otherwise compare ordered existing URLs against the displayed list.
    final editUrls =
        _editPhotoSlots.where((s) => s.isFilled).map((s) => s.url!).toList();
    if (editUrls.length != _displayPhotos.length) return true;
    for (var i = 0; i < editUrls.length; i++) {
      if (editUrls[i] != _displayPhotos[i]) return true;
    }
    return false;
  }

  List<_PhotoSlot> _slotsFromUrls(List<String> urls) {
    final slots = <_PhotoSlot>[];
    for (final url in urls.take(_kMaxPhotos)) {
      slots.add(_PhotoSlot.existing(url));
    }
    while (slots.length < _kMaxPhotos) {
      slots.add(_PhotoSlot.empty());
    }
    return slots;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _displayName = widget.dog.name;
    _displayBreed = widget.dog.breed;
    _displayAge = widget.dog.age;
    _displayBio = widget.dog.bio;
    _displaySize = widget.dog.size;
    _displayGender = widget.dog.gender;

    _editNameController = TextEditingController(text: _displayName);
    _editBreedController = TextEditingController(text: _displayBreed);
    _editBioController = TextEditingController(text: _displayBio);
    _editSize = _displaySize;
    _editGender = _displayGender;
    _editAge = _displayAge;
    _displayPhotos = List<String>.from(widget.dog.photos);
    _editPhotoSlots = _slotsFromUrls(_displayPhotos);

    // Defer all async loading to after the first frame to prevent
    // "Build scheduled during frame" errors when data is cached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // No friendship / owner lookups for a brand-new dog — the owner is
      // the current user and there's nothing to be friends with yet.
      if (!widget.isNewDog) {
        _loadFriendshipStatus();
      }
      if (widget.startInEditMode || widget.isNewDog) {
        _enterEditMode();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DogDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle GoRouter reuse: if startInEditMode changed, enter edit mode
    if (widget.startInEditMode && !oldWidget.startInEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enterEditMode();
      });
    }
  }

  Future<void> _loadFriendshipStatus() async {
    final userId = SupabaseConfig.auth.currentUser?.id;

    // Always load owner profile first (for both own dogs and others' dogs)
    try {
      final ownerProfile =
          await BarkDateUserService.getUserProfile(widget.dog.ownerId);
      debugPrint('🟢 Owner profile fetched: $ownerProfile');
      if (mounted && ownerProfile != null) {
        setState(() {
          _ownerProfile = ownerProfile;
        });
      }
    } catch (e) {
      debugPrint('🔴 Error fetched owner profile: $e');
    }

    if (userId == null) return;

    final myDogs = await BarkDateUserService.getUserDogs(userId);
    if (myDogs.isEmpty) return;

    _myDogId = myDogs.first['id'];
    if (_myDogId == null) return;

    // Don't show bark for your own dogs
    if (_myDogId == widget.dog.id) return;

    final friendship = await DogFriendshipService.getFriendshipStatus(
      dogId1: _myDogId!,
      dogId2: widget.dog.id,
    );

    if (mounted) {
      setState(() {
        _friendshipStatus = friendship?['status'];
        _friendshipId = friendship?['id'];
        _isBarked = _friendshipStatus != null;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _editNameController.dispose();
    _editBreedController.dispose();
    _editBioController.dispose();
    super.dispose();
  }

  Future<void> _onAddToPack() async {
    if (_myDogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need a dog to add friends!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_friendshipStatus == null) {
        // Send a new friend request
        final success = await DogFriendshipService.sendBark(
          fromDogId: _myDogId!,
          toDogId: widget.dog.id,
        );

        if (success && mounted) {
          setState(() {
            _isBarked = true;
            _friendshipStatus = 'pending';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${widget.dog.name}! 🐕'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Auto-refresh stats and lists
          ref.invalidate(userStatsProvider);
          ref.invalidate(nearbyDogsProvider);
          // Also invalidate friend requests in case we are accepting
          ref.invalidate(pendingFriendRequestsProvider);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already friends or error occurred')),
          );
        }
      } else if (_friendshipId != null) {
        // Remove existing bark/friendship
        final success =
            await DogFriendshipService.removeFriendship(_friendshipId!);

        if (success && mounted) {
          setState(() {
            _isBarked = false;
            _friendshipStatus = null;
            _friendshipId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${widget.dog.name} from pack'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Auto-refresh stats and lists
          ref.invalidate(userStatsProvider);
          ref.invalidate(
              userDogsProvider); // In case friend list was cached there
          ref.invalidate(nearbyDogsProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onBarkPoke() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendWalkSheet(targetDog: widget.dog),
    );
  }

  Future<void> _onMessage() async {
    final currentUser = SupabaseConfig.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages')),
      );
      return;
    }

    // Don't allow messaging yourself
    if (currentUser.id == widget.dog.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your dog!')),
      );
      return;
    }

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Opening chat...'), duration: Duration(seconds: 1)),
      );

      // Get or create conversation
      final conversationId = await ConversationService.getOrCreateConversation(
        user1Id: currentUser.id,
        user2Id: widget.dog.ownerId,
      );

      if (mounted) {
        // Navigate to chat screen
        ChatRoute(
          matchId: conversationId, // ChatScreen uses matchId
          recipientId: widget.dog.ownerId,
          recipientName: widget.dog.ownerName,
          recipientAvatarUrl: widget.dog.ownerAvatarUrl ?? '',
        ).push(context);
      }
    } catch (e) {
      debugPrint('❌ Error starting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start conversation: $e')),
        );
      }
    }
  }

  void _onSuggestPlaydate() {
    CreatePlaydateRoute($extra: widget.dog).push(context);
  }

  void _enterEditMode() {
    debugPrint('🟢 _enterEditMode called, mounted=$mounted');
    // Use microtask to ensure setState runs outside any frame build/layout phase
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _editNameController.text = _displayName;
        _editBreedController.text = _displayBreed;
        _editBioController.text = _displayBio;
        _editSize = _displaySize;
        _editGender = _displayGender;
        _editAge = _displayAge;
        _editPhotoSlots = _slotsFromUrls(_displayPhotos);
        _isEditMode = true;
      });
    });
  }

  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
    });
  }

  Future<void> _showDeleteConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Delete $_displayName\'s profile?', style: AppTypography.h3()),
        content: Text(
          'This will remove $_displayName from your pack. This action cannot be undone.',
          style: AppTypography.bodyMedium()
              .copyWith(color: AppColors.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.bodyMedium()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Delete',
                style: AppTypography.bodyMedium().copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final dogId = widget.dog.id;
      debugPrint('🗑️ Deleting dog with ID: $dogId');

      // Soft delete
      await SupabaseConfig.client
          .from('dogs')
          .update({'is_active': false}).eq('id', dogId);

      // Clean up related records
      try {
        await SupabaseConfig.client
            .from('playdate_participants')
            .delete()
            .eq('dog_id', dogId);
        await SupabaseConfig.client
            .from('playdate_requests')
            .delete()
            .eq('invitee_dog_id', dogId);
        await SupabaseConfig.client
            .from('playdate_requests')
            .delete()
            .eq('requester_dog_id', dogId);
      } catch (cleanupError) {
        debugPrint('⚠️ Cleanup warning: $cleanupError');
      }

      // Clear cache and refresh providers
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId != null) {
        BarkDateUserService.clearUserDogsCache(userId);
      }
      ref.invalidate(userDogsProvider);
      ref.invalidate(userProfileProvider);

      debugPrint('✅ Dog deleted');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$_displayName's profile deleted")),
        );
        Navigator.pop(context); // Go back to profile
      }
    } catch (e) {
      debugPrint('❌ Error deleting dog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Centralized back-button handler for the in-appbar arrow. For an existing
  /// dog we just pop — unsaved-changes guarding stays light. For a new dog we
  /// prompt the user to confirm discarding if they've entered anything.
  Future<void> _onBackPressed() async {
    if (_isSavingEdit) return;
    if (!widget.isNewDog || !_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldLeave = await _confirmDiscardNewDog();
    if (shouldLeave && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscardNewDog() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard new dog?'),
        content: const Text(
            'You have unsaved details for this new dog. Leave without adding it to your pack?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return choice == true;
  }

  Future<void> _saveInlineDogEdits() async {
    if (_isSavingEdit) return;

    final name = _editNameController.text.trim();
    final breed = _editBreedController.text.trim();
    final age = _editAge;

    if (name.isEmpty || breed.isEmpty || age < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter valid name, breed, and age')),
      );
      return;
    }

    setState(() => _isSavingEdit = true);
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // ---- Add new dog branch ----
      if (widget.isNewDog) {
        // Upload any picked photos (slot order wins).
        final filled =
            _editPhotoSlots.where((s) => s.isFilled).toList(growable: false);
        final newImages =
            filled.where((s) => s.isPicked).map((s) => s.image!).toList();

        if (newImages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please add at least one photo of your dog')),
          );
          setState(() => _isSavingEdit = false);
          return;
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uploadedUrls = await PhotoUploadService.uploadMultipleImages(
          imageFiles: newImages,
          bucketName: PhotoUploadService.dogPhotosBucket,
          baseFilePath: '$userId/dog_$timestamp/photo',
        );
        if (uploadedUrls.length != newImages.length) {
          throw Exception(
              'Some photos failed to upload (${uploadedUrls.length}/${newImages.length})');
        }

        final mainPhotoUrl =
            uploadedUrls.isNotEmpty ? uploadedUrls.first : null;
        final extraPhotoUrls = uploadedUrls.length > 1
            ? uploadedUrls.sublist(1)
            : const <String>[];

        final dogData = <String, dynamic>{
          'name': name,
          'breed': breed,
          'age': age,
          'size': _editSize,
          'gender': _editGender,
          'bio': _editBioController.text.trim(),
          'main_photo_url': mainPhotoUrl,
          'extra_photo_urls': extraPhotoUrls,
          'photo_urls': uploadedUrls,
          'is_active': true,
          'is_public': true,
        };

        debugPrint('Adding new dog to pack: $dogData');
        await BarkDateUserService.addDog(userId, dogData);

        BarkDateUserService.clearUserDogsCache(userId);
        ref.invalidate(userDogsProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(userStatsProvider);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added to your pack! 🐕'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }

      // ---- Edit existing dog branch ----
      // Resolve final ordered photo URLs (upload new picks first).
      List<String> finalPhotoUrls = List<String>.from(_displayPhotos);
      final photosChanged = _photosChanged();
      if (photosChanged) {
        final filled =
            _editPhotoSlots.where((s) => s.isFilled).toList(growable: false);
        final newImages =
            filled.where((s) => s.isPicked).map((s) => s.image!).toList();
        List<String> newUrls = const [];
        if (newImages.isNotEmpty) {
          newUrls = await PhotoUploadService.uploadMultipleImages(
            imageFiles: newImages,
            bucketName: PhotoUploadService.dogPhotosBucket,
            baseFilePath: '$userId/${widget.dog.id}/photo',
          );
          if (newUrls.length != newImages.length) {
            throw Exception(
                'Some photos failed to upload (${newUrls.length}/${newImages.length})');
          }
        }

        var newIdx = 0;
        finalPhotoUrls = filled.map((s) {
          if (s.isPicked) {
            return newUrls[newIdx++];
          }
          return s.url!;
        }).toList();
      }

      final mainPhotoUrl =
          finalPhotoUrls.isNotEmpty ? finalPhotoUrls.first : null;
      final extraPhotoUrls = finalPhotoUrls.length > 1
          ? finalPhotoUrls.sublist(1)
          : const <String>[];

      final updateData = <String, dynamic>{
        'id': widget.dog.id,
        'name': name,
        'breed': breed,
        'age': age,
        'bio': _editBioController.text.trim(),
        'size': _editSize,
        'gender': _editGender,
      };
      if (photosChanged) {
        updateData['main_photo_url'] = mainPhotoUrl;
        updateData['extra_photo_urls'] = extraPhotoUrls;
        updateData['photo_urls'] = finalPhotoUrls;
      }

      await BarkDateUserService.updateDogProfile(userId, updateData);

      if (!mounted) return;
      setState(() {
        _displayName = name;
        _displayBreed = breed;
        _displayAge = age;
        _displayBio = _editBioController.text.trim();
        _displaySize = _editSize;
        _displayGender = _editGender;
        if (photosChanged) {
          _displayPhotos = finalPhotoUrls;
          if (_currentPhotoIndex >= _displayPhotos.length) {
            _currentPhotoIndex = 0;
          }
          _editPhotoSlots = _slotsFromUrls(_displayPhotos);
        }
        _isEditMode = false;
      });

      BarkDateUserService.clearUserDogsCache(userId);
      ref.invalidate(userDogsProvider);
      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dog profile saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingEdit = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    final isOwnDog =
        currentUserId != null && currentUserId == widget.dog.ownerId;

    final photos = _displayPhotos.isNotEmpty
        ? _displayPhotos
        : ['https://via.placeholder.com/400'];

    // Determine owner avatar URL
    // Use profile override if available, otherwise dog's owner info
    var ownerAvatarUrl =
        _ownerProfile?['avatar_url'] ?? widget.dog.ownerAvatarUrl;

    // Resolve storage path if needed (if it doesn't start with http)
    if (ownerAvatarUrl != null &&
        ownerAvatarUrl.toString().isNotEmpty &&
        !ownerAvatarUrl.toString().startsWith('http')) {
      // Assuming it's in 'user-avatars' bucket if it's a relative path
      // Try to construct public URL - this is a best-guess if we have just a filename/path
      try {
        final path = ownerAvatarUrl.toString();
        // If it looks like a path (fast check)
        ownerAvatarUrl = SupabaseConfig.client.storage
            .from('user-avatars') // Standard bucket name
            .getPublicUrl(path);
      } catch (e) {
        debugPrint('Error resolving avatar URL: $e');
      }
    }

    final ownerName = _ownerProfile?['name'] ?? widget.dog.ownerName;

    return PopScope(
      canPop: !widget.isNewDog || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscardNewDog();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // 1. Sliver App Bar with Image Carousel
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    backgroundColor: Colors.white,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.0, vertical: 8.0),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: IconButton(
                          iconSize: 20,
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: _onBackPressed,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    actions: [
                      if (isOwnDog)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4.0, vertical: 8.0),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              key: ValueKey('edit_btn_$_isEditMode'),
                              iconSize: 20,
                              icon: Icon(
                                widget.isNewDog
                                    ? Icons.check
                                    : (_isEditMode
                                        ? (_hasUnsavedChanges
                                            ? Icons.check
                                            : Icons.close)
                                        : Icons.edit_outlined),
                                color: _hasUnsavedChanges
                                    ? Colors.green
                                    : Colors.black,
                              ),
                              tooltip: widget.isNewDog
                                  ? 'Save new dog'
                                  : (_isEditMode
                                      ? (_hasUnsavedChanges
                                          ? 'Save changes'
                                          : 'Cancel editing')
                                      : 'Edit dog profile'),
                              onPressed: () {
                                debugPrint(
                                    '🔵 EDIT BUTTON TAPPED - _isEditMode=$_isEditMode isNewDog=${widget.isNewDog}');
                                if (widget.isNewDog) {
                                  _saveInlineDogEdits();
                                  return;
                                }
                                if (_isEditMode) {
                                  if (_hasUnsavedChanges) {
                                    _saveInlineDogEdits();
                                  } else {
                                    _cancelEditMode();
                                  }
                                } else {
                                  _enterEditMode();
                                }
                              },
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      // Share is only useful for existing dogs in view mode.
                      if (!_isEditMode && !widget.isNewDog)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4.0, vertical: 8.0),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              iconSize: 20,
                              icon: const Icon(Icons.share_outlined,
                                  color: Colors.black),
                              onPressed: () {
                                // TODO: Share
                              },
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      // Three-dots menu for own dog (Delete option). Hidden for
                      // a brand-new dog — there's nothing to delete yet.
                      if (isOwnDog && !_isEditMode && !widget.isNewDog)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4.0, vertical: 8.0),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black, size: 20),
                              padding: EdgeInsets.zero,
                              position: PopupMenuPosition.under,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              surfaceTintColor: Colors.white,
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  await _showDeleteConfirmation();
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          size: 20, color: AppColors.error),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Delete profile',
                                        style: AppTypography.bodyMedium()
                                            .copyWith(color: AppColors.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Removed Heart icon as per user request
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: _isEditMode
                          ? _buildPhotoEditor()
                          : Stack(
                              children: [
                                PageView.builder(
                                  controller: _pageController,
                                  onPageChanged: (index) => setState(
                                      () => _currentPhotoIndex = index),
                                  itemCount: photos.length,
                                  itemBuilder: (context, index) {
                                    return Image.network(
                                      photos[index],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[100],
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.pets,
                                                    size: 64,
                                                    color: Colors.grey[300]),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _displayName,
                                                  style: AppTypography.h3()
                                                      .copyWith(
                                                          color:
                                                              Colors.grey[400]),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_currentPhotoIndex + 1} / ${photos.length}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // 2. Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Section
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isEditMode) ...[
                                      TextField(
                                        controller: _editNameController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: const InputDecoration(
                                          labelText: 'Dog name',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildBreedAutocomplete(),
                                      const SizedBox(height: 8),
                                      // Age stepper (no keyboard)
                                      Row(
                                        children: [
                                          Text('Age',
                                              style: AppTypography.bodyMedium()
                                                  .copyWith(
                                                      color: Colors.grey[600])),
                                          const SizedBox(width: 16),
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey[300]!),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove,
                                                      size: 20),
                                                  onPressed: _editAge > 0
                                                      ? () => setState(
                                                          () => _editAge--)
                                                      : null,
                                                  splashRadius: 20,
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 40,
                                                          minHeight: 40),
                                                ),
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 48),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '$_editAge yrs',
                                                    style: AppTypography.h3()
                                                        .copyWith(fontSize: 16),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.add,
                                                      size: 20),
                                                  onPressed: _editAge < 21
                                                      ? () => setState(
                                                          () => _editAge++)
                                                      : null,
                                                  splashRadius: 20,
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 40,
                                                          minHeight: 40),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      Text(
                                        _displayName,
                                        style: AppTypography.h1()
                                            .copyWith(fontSize: 32),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_displayBreed • $_displayAge years old',
                                        style: AppTypography.h3().copyWith(
                                            fontWeight: FontWeight.normal),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Distance badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.dog.distanceKm.toStringAsFixed(1)} km',
                                      style:
                                          AppTypography.labelSmall().copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 48),

                          // Human Section
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[200],
                                // Use CachedNetworkImageProvider for better error handling
                                backgroundImage: (!_ownerAvatarError &&
                                        ownerAvatarUrl != null &&
                                        ownerAvatarUrl.toString().isNotEmpty)
                                    ? CachedNetworkImageProvider(
                                        ownerAvatarUrl,
                                        errorListener: (e) {
                                          if (mounted && !_ownerAvatarError) {
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              if (mounted) {
                                                setState(() =>
                                                    _ownerAvatarError = true);
                                              }
                                            });
                                            debugPrint(
                                                'Error loading owner avatar: $e');
                                          }
                                        },
                                      )
                                    : NetworkImage(
                                        'https://i.pravatar.cc/150?u=${widget.dog.ownerId}'),
                                onBackgroundImageError:
                                    (exception, stackTrace) {
                                  if (mounted && !_ownerAvatarError) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        setState(
                                            () => _ownerAvatarError = true);
                                      }
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('My human $ownerName',
                                      style: AppTypography.h3()
                                          .copyWith(fontSize: 16)),
                                  if (_ownerProfile != null &&
                                      _ownerProfile!['relationship_status'] !=
                                          null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        _ownerProfile!['relationship_status'],
                                        style:
                                            AppTypography.labelSmall().copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  Text('$_displayAge years walking together',
                                      style: AppTypography.bodySmall()
                                          .copyWith(color: Colors.grey[600])),
                                ],
                              ),
                            ],
                          ),

                          const Divider(height: 48),

                          // About Section
                          Text('About $_displayName',
                              style: AppTypography.h2()),
                          const SizedBox(height: 16),
                          if (_isEditMode)
                            TextField(
                              controller: _editBioController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Write a short bio',
                              ),
                            )
                          else if (_displayBio.isNotEmpty)
                            Text(
                              _displayBio,
                              style: AppTypography.bodyLarge()
                                  .copyWith(color: Colors.grey[800]),
                            )
                          else if (isOwnDog)
                            // Crimson ! badge for missing bio — only shown to
                            // the dog's owner so other users don't see a
                            // "missing field" alert about someone else's dog.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC143C)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFDC143C)
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 18, color: Color(0xFFDC143C)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Add a bio to help others find $_displayName',
                                      style:
                                          AppTypography.bodyMedium().copyWith(
                                        color: const Color(0xFFDC143C),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const SizedBox.shrink(),

                          const Divider(height: 48),

                          // Details Grid
                          Text('Details', style: AppTypography.h2()),
                          const SizedBox(height: 16),

                          // Size — editable in-place
                          if (_isEditMode)
                            _buildEditableDetailRow(
                              Icons.straighten,
                              'Size',
                              Wrap(
                                spacing: 8,
                                children: ['Small', 'Medium', 'Large']
                                    .map(
                                      (size) => ChoiceChip(
                                        label: Text(size),
                                        selected: _editSize == size,
                                        onSelected: (_) =>
                                            setState(() => _editSize = size),
                                      ),
                                    )
                                    .toList(),
                              ),
                            )
                          else
                            _buildDetailRow(
                                Icons.straighten, 'Size', _displaySize),

                          // Gender — editable in-place
                          if (_isEditMode)
                            _buildEditableDetailRow(
                              Icons.transgender,
                              'Gender',
                              Wrap(
                                spacing: 8,
                                children: ['Male', 'Female']
                                    .map(
                                      (gender) => ChoiceChip(
                                        label: Text(gender),
                                        selected: _editGender == gender,
                                        onSelected: (_) => setState(
                                            () => _editGender = gender),
                                      ),
                                    )
                                    .toList(),
                              ),
                            )
                          else
                            _buildDetailRow(
                                Icons.transgender, 'Gender', _displayGender),

                          // Save/Cancel buttons (after all editable fields)
                          if (_isEditMode) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _cancelEditMode,
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isSavingEdit
                                        ? null
                                        : _saveInlineDogEdits,
                                    child: _isSavingEdit
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Action Buttons (only show for other people's dogs)
                          if (_myDogId != null &&
                              _myDogId != widget.dog.id) ...[
                            Row(
                              children: [
                                // Add to Pack Button (Primary)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _onAddToPack,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : Icon(
                                            _isBarked
                                                ? Icons.check
                                                : Icons.group_add,
                                            color:
                                                _isBarked ? Colors.white : null,
                                          ),
                                    label: Text(_getAddButtonText()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isBarked
                                          ? (_friendshipStatus == 'accepted'
                                              ? Colors.green
                                              : Colors.grey)
                                          : null,
                                      foregroundColor:
                                          _isBarked ? Colors.white : null,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Message Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _onMessage,
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    label: const Text('Message'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Secondary Row: Bark + Playdate
                            Row(
                              children: [
                                // Bark Poke Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _onBarkPoke,
                                    icon: const Icon(Icons.pets,
                                        color: Colors.orange),
                                    label: const Text('Walk?'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      side: BorderSide(
                                          color: Colors.orange
                                              .withValues(alpha: 0.5)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Playdate Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _onSuggestPlaydate,
                                    icon: const Icon(Icons.calendar_today),
                                    label: const Text('Playdate'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Breed autocomplete (edit mode only) ----

  /// Autocomplete-backed breed field driven by [DogBreedService.searchBreeds].
  /// Keeps `_editBreedController` in sync so validation + save logic don't
  /// need to know about the autocomplete internals.
  Widget _buildBreedAutocomplete() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _editBreedController.text),
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return await DogBreedService.searchBreeds(textEditingValue.text);
      },
      onSelected: (String selection) {
        _editBreedController.text = selection;
        setState(() {});
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        // Sync the inner field's value back to our canonical controller.
        if (fieldController.text != _editBreedController.text) {
          if (fieldController.text.isEmpty &&
              _editBreedController.text.isNotEmpty) {
            fieldController.text = _editBreedController.text;
          }
        }
        fieldController.addListener(() {
          if (fieldController.text != _editBreedController.text) {
            _editBreedController.text = fieldController.text;
          }
        });
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Breed',
            suffixIcon: Icon(Icons.search),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width - 48,
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Photo editor (edit mode only) ----

  Widget _buildPhotoEditor() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main slot fills the whole flexibleSpace
        _buildMainSlot(),
        // Two extra-photo thumbnails stacked on the right side
        Positioned(
          top: 16,
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildExtraSlot(1),
              const SizedBox(height: 8),
              _buildExtraSlot(2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainSlot() {
    final slot = _editPhotoSlots[0];
    return GestureDetector(
      onTap: () => _onSlotTap(0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (slot.isEmpty)
            Container(
              color: Colors.grey[100],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 48, color: Colors.grey[500]),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add main photo',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (slot.isPicked)
            Image.memory(slot.image!.bytes, fit: BoxFit.cover)
          else
            Image.network(
              slot.url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[100],
                child: Center(
                    child: Icon(Icons.pets, size: 64, color: Colors.grey[300])),
              ),
            ),
          // Edit affordance when filled (keeps the large slot tappable)
          if (slot.isFilled)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Edit main photo',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExtraSlot(int index) {
    final slot = _editPhotoSlots[index];
    return GestureDetector(
      onTap: () => _onSlotTap(index),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _extraSlotContent(slot),
        ),
      ),
    );
  }

  Widget _extraSlotContent(_PhotoSlot slot) {
    if (slot.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child:
            Icon(Icons.add_a_photo_outlined, color: Colors.grey[600], size: 22),
      );
    }
    if (slot.isPicked) {
      return Image.memory(slot.image!.bytes, fit: BoxFit.cover);
    }
    return Image.network(
      slot.url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey[200],
        child: Icon(Icons.broken_image, size: 20, color: Colors.grey[500]),
      ),
    );
  }

  Future<void> _onSlotTap(int index) async {
    final slot = _editPhotoSlots[index];
    if (slot.isEmpty) {
      final img = await context.showImagePicker();
      if (!mounted || img == null) return;
      setState(() {
        // Pack to the first empty slot so filled entries stay contiguous.
        final target = _firstEmptyIndex() ?? index;
        _editPhotoSlots[target] = _PhotoSlot.picked(img);
      });
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (index != 0)
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Make main photo'),
                onTap: () => Navigator.pop(ctx, 'make_main'),
              ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Replace'),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Remove', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    switch (choice) {
      case 'make_main':
        setState(() {
          final tmp = _editPhotoSlots[0];
          _editPhotoSlots[0] = _editPhotoSlots[index];
          _editPhotoSlots[index] = tmp;
        });
        break;
      case 'replace':
        final img = await context.showImagePicker();
        if (!mounted || img == null) return;
        setState(() {
          _editPhotoSlots[index] = _PhotoSlot.picked(img);
        });
        break;
      case 'remove':
        setState(() {
          // Shift everything after `index` one position left, drop last.
          final newSlots = [..._editPhotoSlots];
          for (var i = index; i < _kMaxPhotos - 1; i++) {
            newSlots[i] = newSlots[i + 1];
          }
          newSlots[_kMaxPhotos - 1] = _PhotoSlot.empty();
          _editPhotoSlots = newSlots;
        });
        break;
    }
  }

  int? _firstEmptyIndex() {
    for (var i = 0; i < _editPhotoSlots.length; i++) {
      if (_editPhotoSlots[i].isEmpty) return i;
    }
    return null;
  }

  String _getAddButtonText() {
    switch (_friendshipStatus) {
      case 'pending':
        return 'Request Sent';
      case 'accepted':
        return 'In Pack';
      case 'declined':
        return 'Try Again';
      default:
        return 'Add to Pack';
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.h3().copyWith(fontSize: 16)),
                Text(value,
                    style: AppTypography.bodyMedium()
                        .copyWith(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDetailRow(IconData icon, String label, Widget editor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.h3().copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                editor,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single photo slot in the dog edit photo grid. A slot is either empty,
/// already persisted as a remote URL, or freshly picked locally.
class _PhotoSlot {
  final String? url;
  final SelectedImage? image;

  _PhotoSlot._(this.url, this.image);

  factory _PhotoSlot.empty() => _PhotoSlot._(null, null);
  factory _PhotoSlot.existing(String url) => _PhotoSlot._(url, null);
  factory _PhotoSlot.picked(SelectedImage image) => _PhotoSlot._(null, image);

  bool get isEmpty => url == null && image == null;
  bool get isFilled => !isEmpty;
  bool get isExisting => url != null;
  bool get isPicked => image != null;
}
