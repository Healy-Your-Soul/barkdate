import 'package:barkdate/screens/dog_friend_selector_dialog.dart';
import 'package:barkdate/screens/map_location_picker_screen.dart';
import 'package:barkdate/services/auth_service.dart';
import 'package:barkdate/services/event_service.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/services/selected_image.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/widgets/event_image_uploader.dart';
import 'package:barkdate/widgets/location_picker_field.dart';
import 'package:flutter/material.dart';

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
  bool _isPublicEvent = true;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createEvent,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
              
              // Date and time selection
              Text(
                'Date & Time',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text(_selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date'),
                      leading: const Icon(Icons.calendar_today),
                      onTap: _selectDate,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListTile(
                      title: Text(_selectedStartTime != null
                          ? _selectedStartTime!.format(context)
                          : 'Start Time'),
                      leading: const Icon(Icons.access_time),
                      onTap: _selectStartTime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              ListTile(
                title: Text(_selectedEndTime != null
                    ? _selectedEndTime!.format(context)
                    : 'End Time'),
                leading: const Icon(Icons.access_time),
                onTap: _selectEndTime,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location with autocomplete
              LocationPickerField(
                controller: _locationController,
                hintText: 'Search for a location...',
                onPlaceSelected: (place) async {
                  // Try to get coordinates from place details
                  final details = await PlacesService.getPlaceDetailsByPlaceId(place.placeId);
                  if (details != null) {
                    final geometry = details['geometry'] as Map<String, dynamic>?;
                    final location = geometry?['location'] as Map<String, dynamic>?;
                    if (location != null && mounted) {
                      setState(() {
                        _selectedLatitude = (location['lat'] as num?)?.toDouble();
                        _selectedLongitude = (location['lng'] as num?)?.toDouble();
                        _selectedPlaceName = place.structuredFormatting.mainText;
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

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _openLocationPicker,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    _selectedLatitude == null
                        ? 'Pick location on map'
                        : 'Update map location',
                  ),
                ),
              ),

              if (_selectedLatitude != null && _selectedLongitude != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_selectedPlaceName ?? 'Custom location'} • '
                    '${_selectedLatitude!.toStringAsFixed(4)}, '
                    '${_selectedLongitude!.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (optional)',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        _price = double.tryParse(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Free Event'),
                      value: _price == null || _price == 0,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _price = null;
                            _priceController.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              
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
                    selected: _isPublicEvent,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _isPublicEvent = true);
                      }
                    },
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Invite only'),
                    selected: !_isPublicEvent,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _isPublicEvent = false);
                      }
                    },
                  ),
                ],
              ),
              if (!_isPublicEvent)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Only invited dog friends will see this event.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _loadingFriends ? null : _inviteDogFriends,
                icon: _loadingFriends
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add_outlined),
                label: Text(
                  _invitedDogIds.isEmpty
                      ? 'Invite dog friends'
                      : 'Inviting ${_invitedDogIds.length} dog friends',
                ),
              ),

              const SizedBox(height: 8),

              _buildInvitedDogChips(),

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
              
              // Create button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createEvent,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create Event'),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
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
      initialTime: _selectedEndTime ?? TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1),
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

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<MapLocationResult?>(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialLabel: _locationController.text.isNotEmpty
              ? _locationController.text
              : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result.latitude;
        _selectedLongitude = result.longitude;
        _selectedPlaceName = result.placeName;
        _locationController.text = result.address ??
            result.placeName ??
            '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
      });
    }
  }

  Future<void> _inviteDogFriends() async {
    if (_loadingFriends) return;

    final userId = AuthService.getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to invite friends.')),
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
          ..sort((a, b) => a.dogName.toLowerCase().compareTo(b.dogName.toLowerCase()));
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
        final friendDogId = (friendDog?['id'] ?? friend['friend_dog_id']) as String?;
        if (friendDogId == null || friendDogId == dogId) continue;

        final owner = friendDog?['user'] as Map<String, dynamic>?
            ?? {};

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
      ..sort((a, b) => a.dogName.toLowerCase().compareTo(b.dogName.toLowerCase()));

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

    if (!_isPublicEvent && _invitedDogIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite at least one dog or set the event to public.')),
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
        isPublic: _isPublicEvent,
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
