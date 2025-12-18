import 'package:barkdate/features/playdates/presentation/screens/map_picker_screen.dart';
import 'package:barkdate/features/playdates/presentation/widgets/dog_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/widgets/location_picker_field.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/location_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CreatePlaydateScreen extends ConsumerStatefulWidget {
  final Dog? targetDog; // Initial dog if coming from profile

  const CreatePlaydateScreen({super.key, this.targetDog});

  @override
  ConsumerState<CreatePlaydateScreen> createState() => _CreatePlaydateScreenState();
}

class _CreatePlaydateScreenState extends ConsumerState<CreatePlaydateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _titleController = TextEditingController(); // Optional title
  final _descriptionController = TextEditingController(); // Optional message
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  bool _isSubmitting = false;
  bool _isLoadingLocation = false; // For map picker button loading state
  
  // State for new features
  PlaceAutocomplete? _selectedPlace; // Holds simple autocomplete data
  PlaceResult? _detailedPlace; // Holds detailed place with coords from Map Picker
  List<Dog> _invitedDogs = [];

  @override
  void initState() {
    super.initState();
    if (widget.targetDog != null) {
      _invitedDogs.add(widget.targetDog!);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
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

  void _removeDog(Dog dog) {
    setState(() {
      _invitedDogs.removeWhere((d) => d.id == dog.id);
    });
  }

  void _openMapPicker() async {
    // Show loading on the map button
    setState(() => _isLoadingLocation = true);
    
    try {
      // Pre-fetch location before opening map
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      
      setState(() => _isLoadingLocation = false);
      
      // Navigate with pre-fetched location
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
          _detailedPlace = result;
          _locationController.text = result.name;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        // Still open map with default location
        final result = await Navigator.of(context).push<PlaceResult>(
          MaterialPageRoute(builder: (context) => const MapPickerScreen()),
        );
        
        if (result != null && mounted) {
          setState(() {
            _detailedPlace = result;
            _locationController.text = result.name;
          });
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invitedDogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please invite at least one dog')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // 1. Determine Location Coordinates
      double? lat = _detailedPlace?.latitude;
      double? lng = _detailedPlace?.longitude;
      
      // If manually typed/selected via autocomplete without details, we try to get coords
      // simplified for now: just use empty coordinates if not from Map Picker or valid Place
      
      // 2. Prepare timestamp
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour, 
        _selectedTime.minute,
      );

      // 3. Create Playdate Transaction (RPC or manual inserts)
      // Since we modified migration, we'll do manual inserts for flexibility
      
      // A. Insert Playdate
      final playdateRes = await SupabaseConfig.client
          .from('playdates')
          .insert({
            'title': _titleController.text.isNotEmpty 
                ? _titleController.text 
                : 'Playdate with ${_invitedDogs.first.name}',
            'description': _descriptionController.text,
            'location': _locationController.text,
            'latitude': lat,
            'longitude': lng,
            'scheduled_at': scheduledAt.toIso8601String(),
            'organizer_id': user.id,
            'status': 'pending', 
            'max_dogs': _invitedDogs.length + 1, // Organizer + invites
          })
          .select()
          .single();
          
      final playdateId = playdateRes['id'];

      // B. Insert Organizer as Participant
      // We need to fetch ONE of the user's dogs to be the "host dog"
      // For simplicity, pick the first one
      final myDogsRes = await SupabaseConfig.client
          .from('dogs')
          .select('id, name')
          .eq('owner_id', user.id)
          .limit(1);
          
      if (myDogsRes.isEmpty) throw Exception('You need a dog profile to create a playdate!');
      final myDogId = myDogsRes[0]['id'];
      
      await SupabaseConfig.client.from('playdate_participants').insert({
        'playdate_id': playdateId,
        'user_id': user.id,
        'dog_id': myDogId,
        'is_organizer': true,
        'status': 'confirmed', // Organizer is auto-confirmed
      });

      // C. Create Requests for Invited Dogs
      for (final dog in _invitedDogs) {
        await SupabaseConfig.client.from('playdate_requests').insert({
          'playdate_id': playdateId,
          'requester_id': user.id,
          'requester_dog_id': myDogId, // New field from migration
          'invitee_id': dog.ownerId,
          'invitee_dog_id': dog.id,
          'status': 'pending',
          'message': _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Let\'s play!',
        });
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invites sent to ${_invitedDogs.length} dogs!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Error creating playdate: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().split(":").last.trim()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Schedule Playdate',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INVITED DOGS SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Inviting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    child: Text('No dogs invited yet. Tap "Add Dog" to start!'),
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
                            margin: const EdgeInsets.only(right: 12, top: 4),
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
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // DETAILS SECTION
              const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title (Optional)',
                  hintText: 'e.g., Park Fun Day',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Message (Optional)',
                  hintText: 'Add a note for the invitees...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              const SizedBox(height: 24),

              // DATE AND TIME
              const Text('When', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => _selectDate(context),
                      leading: const Icon(Icons.calendar_today_outlined, color: Colors.black),
                      title: const Text('Date'),
                      trailing: Text(
                        DateFormat('MMM d, y').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey[300]),
                    ListTile(
                      onTap: () => _selectTime(context),
                      leading: const Icon(Icons.access_time, color: Colors.black),
                      title: const Text('Time'),
                      trailing: Text(
                        _selectedTime.format(context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // LOCATION SECTION
              const Text('Where', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LocationPickerField(
                      controller: _locationController,
                      hintText: 'Search for a location...',
                      onPlaceSelected: (place) {
                        setState(() {
                          _selectedPlace = place;
                          // If picked from autocomplete, we don't have detailed coords yet
                          // Detailed place info would be fetched if submitting or if we added that call
                          _detailedPlace = null; // Clear manual pick
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
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
                    child: _isLoadingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _openMapPicker,
                            icon: Icon(Icons.map, color: Theme.of(context).primaryColor),
                            tooltip: 'Pick on Map',
                          ),
                  ),
                ],
              ),
              
              // Quick suggestions
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildQuickLocationChip('Nearest Park', Icons.park),
                    const SizedBox(width: 8),
                    _buildQuickLocationChip('My Favorites', Icons.favorite),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : Text(
                          'Send Invites (${_invitedDogs.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _locateNearestPark() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finding nearest park...')),
    );
    
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null && mounted) {
        final places = await PlacesService.searchDogFriendlyPlaces(
          latitude: pos.latitude,
          longitude: pos.longitude,
          radius: 3000,
          primaryTypes: ['park', 'dog_park'],
        );
        
        if (places.places.isNotEmpty && mounted) {
          final nearest = places.places.first;
          setState(() {
            _detailedPlace = nearest; // Store in _detailedPlace (PlaceResult type)
            _selectedPlace = null; // Clear autocomplete selection
            _locationController.text = nearest.name;
          });
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No parks found nearby')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error finding park: $e');
    }
  }

  Widget _buildQuickLocationChip(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: Colors.grey.shade700),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide.none,
      onPressed: () {
      if (label == 'Nearest Park') {
        _locateNearestPark();
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coming soon!')),
        );
      }
    },
    );
  }
}
