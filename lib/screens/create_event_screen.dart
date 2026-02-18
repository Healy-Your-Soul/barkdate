import 'package:barkdate/screens/dog_friend_selector_dialog.dart';
import 'package:barkdate/features/playdates/presentation/screens/map_picker_screen.dart';
import 'package:barkdate/features/playdates/presentation/widgets/dog_search_sheet.dart';
import 'package:barkdate/services/auth_service.dart';
import 'package:barkdate/services/event_service.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/selected_image.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/location_service.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/widgets/event_image_uploader.dart';
import 'package:barkdate/widgets/location_picker_field.dart';
import 'package:barkdate/models/dog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  static const int _maxPhotoCount = 5;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  String _selectedCategory = 'social';
  int _maxParticipants = 10;
  double? _price;
  bool _requiresRegistration = true;
  bool _isLoading = false;
  String _visibility = 'public'; // 'public', 'friends', 'invite_only'
  bool _isFree = true;

  final List<String> _selectedAgeGroups = [];
  final List<String> _selectedSizes = [];

  final List<SelectedImage> _selectedImages = [];
  bool _uploadingPhotos = false;
  int _uploadProgressCurrent = 0;
  int _uploadProgressTotal = 0;

  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedPlaceName;

  final List<String> _invitedDogIds = [];
  final Map<String, DogFriendOption> _friendOptionLookup = {};
  bool _loadingFriends = false;
  bool _isLoadingMapLocation = false; // For map picker button loading
  List<Dog> _invitedDogs = []; // For invite-only with DogSearchSheet

  final List<Map<String, dynamic>> _categories = [
    {'id': 'birthday', 'name': 'Birthday Party', 'icon': '🎂'},
    {'id': 'training', 'name': 'Training Class', 'icon': '🎓'},
    {'id': 'social', 'name': 'Social Meetup', 'icon': '🐕'},
    {'id': 'professional', 'name': 'Professional Service', 'icon': '🏥'},
  ];

  final List<String> _ageGroups = ['puppy', 'adult', 'senior'];
  final List<String> _sizes = ['small', 'medium', 'large', 'extra large'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Create Event',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventImageUploader(
                  images: _selectedImages,
                  onAddPressed: _pickEventImages,
                  onRemovePressed: _removeEventImage,
                  maxImages: _maxPhotoCount,
                  isUploading: _uploadingPhotos,
                  uploadCurrent: _uploadProgressCurrent,
                  uploadTotal: _uploadProgressTotal,
                ),

                const SizedBox(height: 24),

                // Event title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    hintText: 'e.g., Puppy Playtime at Central Park',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an event title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Category selection
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category['id'];
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(category['icon']),
                          const SizedBox(width: 4),
                          Text(category['name']),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category['id'];
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Tell everyone what this event is about...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an event description';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // DATE AND TIME - Playdate style
                const Text('When',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: _selectDate,
                        leading: const Icon(Icons.calendar_today_outlined,
                            color: Colors.black),
                        title: const Text('Date'),
                        trailing: Text(
                          _selectedDate != null
                              ? DateFormat('MMM d, y').format(_selectedDate!)
                              : 'Select date',
                          style: TextStyle(
                              fontWeight: _selectedDate != null
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey[300]),
                      ListTile(
                        onTap: _selectStartTime,
                        leading:
                            const Icon(Icons.access_time, color: Colors.black),
                        title: const Text('Start Time'),
                        trailing: Text(
                          _selectedStartTime?.format(context) ?? 'Select time',
                          style: TextStyle(
                              fontWeight: _selectedStartTime != null
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey[300]),
                      ListTile(
                        onTap: _selectEndTime,
                        leading: const Icon(Icons.access_time_filled,
                            color: Colors.black),
                        title: const Text('End Time'),
                        trailing: Text(
                          _selectedEndTime?.format(context) ?? 'Select time',
                          style: TextStyle(
                              fontWeight: _selectedEndTime != null
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // LOCATION - Playdate style
                const Text('Where',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LocationPickerField(
                        controller: _locationController,
                        hintText: 'Search for a location...',
                        onPlaceSelected: (place) async {
                          final details =
                              await PlacesService.getPlaceDetailsByPlaceId(
                                  place.placeId);
                          if (details != null) {
                            final geometry =
                                details['geometry'] as Map<String, dynamic>?;
                            final location =
                                geometry?['location'] as Map<String, dynamic>?;
                            if (location != null && mounted) {
                              setState(() {
                                _selectedLatitude =
                                    (location['lat'] as num?)?.toDouble();
                                _selectedLongitude =
                                    (location['lng'] as num?)?.toDouble();
                                _selectedPlaceName =
                                    place.structuredFormatting.mainText;
                              });
                            }
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please select a location';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isLoadingMapLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              onPressed: _openMapPicker,
                              icon: Icon(Icons.map,
                                  color: Theme.of(context).primaryColor),
                              tooltip: 'Pick on Map',
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Max participants
                Text(
                  'Max Participants',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _maxParticipants.toDouble(),
                  min: 2,
                  max: 50,
                  divisions: 48,
                  label: '$_maxParticipants dogs',
                  onChanged: (value) {
                    setState(() {
                      _maxParticipants = value.round();
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Price
                // Price
                CheckboxListTile(
                  title: const Text('This event is free'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _isFree,
                  onChanged: (value) {
                    setState(() {
                      _isFree = value ?? false;
                      if (_isFree) {
                        _price = 0;
                        _priceController.clear();
                      }
                    });
                  },
                ),

                if (!_isFree) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      _price = double.tryParse(value);
                    },
                    validator: (value) {
                      if (!_isFree && (value == null || value.isEmpty)) {
                        return 'Please enter a price';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 16),

                Text(
                  'Visibility',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.public, size: 18),
                      label: const Text('Public'),
                      selected: _visibility == 'public',
                      onSelected: (selected) {
                        if (selected) setState(() => _visibility = 'public');
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.group, size: 18),
                      label: const Text('Friends Only'),
                      selected: _visibility == 'friends',
                      onSelected: (selected) {
                        if (selected) setState(() => _visibility = 'friends');
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('Invite only'),
                      selected: _visibility == 'invite_only',
                      onSelected: (selected) {
                        if (selected)
                          setState(() => _visibility = 'invite_only');
                      },
                    ),
                  ],
                ),
                if (_visibility != 'public') ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _visibility == 'friends'
                          ? 'Visible to your dog friends and their owners.'
                          : 'Only invited dog friends will see this event.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // INVITED DOGS SECTION - Playdate style
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Inviting',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _openDogSearch,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Dog'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_invitedDogs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text(
                            'No dogs invited yet. Tap "Add Dog" to start!'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _invitedDogs.length,
                        itemBuilder: (context, index) {
                          final dog = _invitedDogs[index];
                          return Stack(
                            children: [
                              Container(
                                margin:
                                    const EdgeInsets.only(right: 12, top: 4),
                                width: 64,
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: dog.photos.isNotEmpty
                                          ? NetworkImage(dog.photos.first)
                                          : null,
                                      child: dog.photos.isEmpty
                                          ? const Icon(Icons.pets)
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dog.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  onTap: () => _removeDog(dog),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],

                const SizedBox(height: 16),

                // Target audience
                Text(
                  'Target Audience',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Age Groups',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: _ageGroups.map((age) {
                    final isSelected = _selectedAgeGroups.contains(age);
                    return FilterChip(
                      label: Text(age.capitalize()),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedAgeGroups.add(age);
                          } else {
                            _selectedAgeGroups.remove(age);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                Text(
                  'Sizes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: _sizes.map((size) {
                    final isSelected = _selectedSizes.contains(size);
                    return FilterChip(
                      label: Text(size.capitalize()),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSizes.add(size);
                          } else {
                            _selectedSizes.remove(size);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Registration requirement
                SwitchListTile.adaptive(
                  title: const Text('Requires Registration'),
                  subtitle: const Text('Participants must register to attend'),
                  value: _requiresRegistration,
                  onChanged: (value) {
                    setState(() {
                      _requiresRegistration = value;
                    });
                  },
                ),

                const SizedBox(height: 32),

                // Create button - Playdate style
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Event',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ), // Close GestureDetector
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedStartTime = time;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ??
          TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1),
    );
    if (time != null) {
      setState(() {
        _selectedEndTime = time;
      });
    }
  }

  Future<void> _pickEventImages() async {
    if (_uploadingPhotos) return;
    final remaining = _maxPhotoCount - _selectedImages.length;
    if (remaining <= 0) return;

    final images = await PhotoUploadService.showMultiImagePickerDialog(
      context,
      maxImages: remaining,
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeEventImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Open DogSearchSheet for invite-only events (playdate style)
  void _openDogSearch() async {
    final result = await showModalBottomSheet<List<Dog>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DogSearchSheet(
        excludedDogIds: _invitedDogs.map((d) => d.id).toList(),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _invitedDogs.addAll(result);
      });
    }
  }

  /// Remove a dog from the invite list
  void _removeDog(Dog dog) {
    setState(() {
      _invitedDogs.removeWhere((d) => d.id == dog.id);
    });
  }

  /// Pre-fetch location and open map picker (playdate style)
  Future<void> _openMapPicker() async {
    setState(() => _isLoadingMapLocation = true);

    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;

      setState(() => _isLoadingMapLocation = false);

      final result = await Navigator.of(context).push<PlaceResult>(
        MaterialPageRoute(
          builder: (context) => MapPickerScreen(
            initialLocation: position != null
                ? LatLng(position.latitude, position.longitude)
                : null,
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _selectedLatitude = result.latitude;
          _selectedLongitude = result.longitude;
          _selectedPlaceName = result.name;
          _locationController.text = result.name;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoadingMapLocation = false);
        // Still open map with default location
        final result = await Navigator.of(context).push<PlaceResult>(
          MaterialPageRoute(builder: (context) => const MapPickerScreen()),
        );

        if (result != null && mounted) {
          setState(() {
            _selectedLatitude = result.latitude;
            _selectedLongitude = result.longitude;
            _selectedPlaceName = result.name;
            _locationController.text = result.name;
          });
        }
      }
    }
  }

  Future<void> _inviteDogFriends() async {
    if (_loadingFriends) return;

    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to invite friends.')),
      );
      return;
    }

    setState(() => _loadingFriends = true);

    try {
      List<DogFriendOption> options;
      if (_friendOptionLookup.isEmpty) {
        options = await _fetchDogFriendOptions(userId);
      } else {
        options = _friendOptionLookup.values.toList()
          ..sort((a, b) =>
              a.dogName.toLowerCase().compareTo(b.dogName.toLowerCase()));
      }

      if (!mounted) return;
      setState(() => _loadingFriends = false);

      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add some dog friends first to send invitations.'),
          ),
        );
        return;
      }

      final selected = await showDialog<List<String>>(
        context: context,
        builder: (context) => DogFriendSelectorDialog(
          options: options,
          initialSelection: _invitedDogIds.toSet(),
        ),
      );

      if (selected != null) {
        setState(() {
          _invitedDogIds
            ..clear()
            ..addAll(selected);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFriends = false);
      final message = e.toString().contains('dog profile')
          ? e.toString()
          : 'Could not load dog friends: ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<List<DogFriendOption>> _fetchDogFriendOptions(String userId) async {
    final dogs = await BarkDateUserService.getUserDogs(userId);
    if (dogs.isEmpty) {
      throw Exception('Add a dog profile to invite friends to events.');
    }

    final Map<String, DogFriendOption> lookup = {};
    for (final dog in dogs) {
      final dogId = dog['id'] as String?;
      if (dogId == null) continue;
      final friends = await DogFriendshipService.getDogFriends(dogId);
      for (final friend in friends) {
        final friendDog = friend['friend_dog'] as Map<String, dynamic>?;
        final friendDogId =
            (friendDog?['id'] ?? friend['friend_dog_id']) as String?;
        if (friendDogId == null || friendDogId == dogId) continue;

        final owner = friendDog?['user'] as Map<String, dynamic>? ?? {};

        lookup[friendDogId] = DogFriendOption(
          dogId: friendDogId,
          dogName: (friendDog?['name'] as String?) ?? 'Dog friend',
          dogBreed: friendDog?['breed'] as String?,
          ownerName: (owner['name'] as String?) ?? 'Dog owner',
          photoUrl: friendDog?['main_photo_url'] as String?,
        );
      }
    }

    final options = lookup.values.toList()
      ..sort(
          (a, b) => a.dogName.toLowerCase().compareTo(b.dogName.toLowerCase()));

    if (mounted) {
      _friendOptionLookup
        ..clear()
        ..addEntries(options.map((option) => MapEntry(option.dogId, option)));
    }

    return options;
  }

  Widget _buildInvitedDogChips() {
    if (_invitedDogIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _invitedDogIds.map((dogId) {
        final option = _friendOptionLookup[dogId];
        return InputChip(
          label: Text(option?.dogName ?? 'Invited pup'),
          avatar: option?.photoUrl != null && option!.photoUrl!.isNotEmpty
              ? CircleAvatar(backgroundImage: NetworkImage(option.photoUrl!))
              : const CircleAvatar(child: Icon(Icons.pets, size: 16)),
          onDeleted: () => _removeInvitedDog(dogId),
        );
      }).toList(),
    );
  }

  void _removeInvitedDog(String dogId) {
    setState(() {
      _invitedDogIds.remove(dogId);
    });
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start time')),
      );
      return;
    }

    if (_selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an end time')),
      );
      return;
    }

    if (_selectedEndTime!.hour < _selectedStartTime!.hour ||
        (_selectedEndTime!.hour == _selectedStartTime!.hour &&
            _selectedEndTime!.minute <= _selectedStartTime!.minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    if (_visibility == 'invite_only' && _invitedDogIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Invite at least one dog or set the event to public.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );

      final endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );

      final currentUserId = AuthService.getCurrentUserId();
      List<String> photoUrls = [];

      if (_selectedImages.isNotEmpty) {
        if (currentUserId == null) {
          throw Exception('You must be logged in to upload event photos.');
        }

        setState(() {
          _uploadingPhotos = true;
          _uploadProgressCurrent = 0;
          _uploadProgressTotal = _selectedImages.length;
        });

        photoUrls = await PhotoUploadService.uploadEventPhotos(
          imageFiles: List.of(_selectedImages),
          userId: currentUserId,
          onProgress: (current, total) {
            if (!mounted) return;
            setState(() {
              _uploadProgressCurrent = current;
              _uploadProgressTotal = total;
            });
          },
        );
      }

      final event = await EventService.createEvent(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        category: _selectedCategory,
        maxParticipants: _maxParticipants,
        targetAgeGroups: _selectedAgeGroups,
        targetSizes: _selectedSizes,
        price: _price,
        requiresRegistration: _requiresRegistration,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        photoUrls: photoUrls,
        visibility: _visibility,
        invitedDogIds: List.of(_invitedDogIds),
      );

      if (event != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _invitedDogIds.isNotEmpty
                    ? 'Event created successfully and invitations sent! 🎉'
                    : 'Event created successfully! 🎉',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create event. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadingPhotos = false;
          _uploadProgressCurrent = 0;
          _uploadProgressTotal = 0;
        });
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
