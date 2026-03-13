import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart'
    hide DogFriendshipService;
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/dog_friendship_service.dart';

class SendWalkSheet extends ConsumerStatefulWidget {
  final Dog targetDog;

  const SendWalkSheet({
    super.key,
    required this.targetDog,
  });

  @override
  ConsumerState<SendWalkSheet> createState() => _SendWalkSheetState();
}

class _SendWalkSheetState extends ConsumerState<SendWalkSheet> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _locationController = TextEditingController();

  // Pack selection
  final Set<String> _selectedAdditionalDogIds = {};
  bool _isLoading = false;
  Dog? _myDog;
  List<Dog> _packMembers = [];
  bool _packLoading = true;

  @override
  void initState() {
    super.initState();
    final inOneHour = DateTime.now().add(const Duration(hours: 1));
    _selectedTime = TimeOfDay(hour: inOneHour.hour, minute: 0);
    _selectedDate = DateTime(inOneHour.year, inOneHour.month, inOneHour.day);
    _loadMyDog();
    _loadPackMembers();
  }

  Future<void> _loadMyDog() async {
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      final dogsData = await BarkDateUserService.getUserDogs(userId);
      if (dogsData.isNotEmpty && mounted) {
        setState(() {
          final dogData = dogsData.first;
          _myDog = Dog(
            id: dogData['id'],
            name: dogData['name'],
            breed: dogData['breed'],
            age: dogData['age'],
            size: dogData['size'],
            gender: dogData['gender'],
            bio: dogData['bio'] ?? '',
            photos: List<String>.from(dogData['photo_urls'] ?? []),
            ownerId: userId,
            ownerName: '',
            distanceKm: 0,
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading my dog: $e');
    }
  }

  Future<void> _loadPackMembers() async {
    try {
      if (_myDog == null) {
        // Wait briefly for _loadMyDog to finish
        await Future.delayed(const Duration(milliseconds: 500));
      }
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) return;

      final dogsData = await BarkDateUserService.getUserDogs(userId);
      if (dogsData.isEmpty) return;
      final myDogId = dogsData.first['id'] as String;

      final friends = await DogFriendshipService.getFriends(myDogId);
      final dogs = <Dog>[];
      for (final f in friends) {
        final friendDogMap = f['friend_dog']['id'] == myDogId
            ? f['dog'] as Map<String, dynamic>
            : f['friend_dog'] as Map<String, dynamic>;

        final photosRaw = friendDogMap['photo_urls'] ?? friendDogMap['photos'] ?? [];
        final photos = (photosRaw as List).map((e) => e.toString()).toList();
        if (photos.isEmpty && friendDogMap['main_photo_url'] != null) {
          photos.add(friendDogMap['main_photo_url']);
        }

        dogs.add(Dog(
          id: friendDogMap['id'] ?? '',
          name: friendDogMap['name'] ?? 'Unknown',
          breed: friendDogMap['breed'] ?? 'Unknown',
          age: (friendDogMap['age'] as num?)?.toInt() ?? 0,
          size: friendDogMap['size'] ?? 'medium',
          gender: friendDogMap['gender'] ?? 'unknown',
          bio: friendDogMap['bio'] ?? '',
          photos: photos,
          ownerId: friendDogMap['user_id'] ?? '',
          ownerName: '',
          distanceKm: 0,
        ));
      }

      if (mounted) {
        setState(() {
          _packMembers = dogs;
          _packLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pack members: $e');
      if (mounted) setState(() => _packLoading = false);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDate() {
    final today = DateTime.now();
    if (_selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day) {
      return 'Today';
    }
    return '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _sendWalkRequest() async {
    if (_myDog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load your dog profile')),
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Create main request for target dog
      final playdateId = await PlaydateRequestService.createPlaydateRequest(
        organizerId: userId,
        organizerDogId: _myDog!.id,
        inviteeId: widget.targetDog.ownerId,
        inviteeDogId: widget.targetDog.id,
        title: 'Walk with ${_myDog!.name}',
        location: _locationController.text.trim(),
        scheduledAt: _combinedDateTime,
        description: 'Walk invitation from ${_myDog!.name}',
        message: 'Let\'s go for a walk! 🐕',
      );

      if (playdateId != null) {
        // Handle Pack Multi-select: If additional dogs are selected,
        // fetch their owner IDs (from Riverpod state) and send requests.
        if (_selectedAdditionalDogIds.isNotEmpty) {
          for (final dogId in _selectedAdditionalDogIds) {
            final packDog = _packMembers.firstWhere((d) => d.id == dogId);
            await SupabaseConfig.client.from('playdate_requests').insert({
              'playdate_id': playdateId,
              'requester_id': userId,
              'requester_dog_id': _myDog!.id,
              'invitee_id': packDog.ownerId,
              'invitee_dog_id': packDog.id,
              'status': 'pending',
              'message': 'Let\'s go for a walk! 🐕',
            });
          }
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Walk request sent! 🎉'),
            backgroundColor: const Color(0xFFE89E5F),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send walk request.')));
        }
      }
    } catch (e) {
      debugPrint('Error sending walk request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHandleBar(),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.targetDog.photos.isNotEmpty
                    ? NetworkImage(widget.targetDog.photos.first)
                    : null,
                child: widget.targetDog.photos.isEmpty
                    ? const Icon(Icons.pets, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Walk with ${widget.targetDog.name}?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('When',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: Color(0xFFE89E5F)),
                        const SizedBox(width: 8),
                        Text(_formatDate(),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 18, color: Color(0xFFE89E5F)),
                        const SizedBox(width: 8),
                        Text(_selectedTime.format(context),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Where',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'e.g. Central Park',
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Text('Add Pack Members',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildPackSelector(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _sendWalkRequest,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFFE89E5F), // App Brand Orange
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _selectedAdditionalDogIds.isEmpty
                        ? 'Send to ${widget.targetDog.name}'
                        : 'Send to Pack',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPackSelector() {
    if (_packLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availableDogs = _packMembers.where((d) => d.id != widget.targetDog.id).toList();
    if (availableDogs.isEmpty) {
      return const Text('No other pack members available.',
          style: TextStyle(color: Colors.grey));
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableDogs.length,
        itemBuilder: (context, index) {
          final friendDog = availableDogs[index];
          final isSelected = _selectedAdditionalDogIds.contains(friendDog.id);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedAdditionalDogIds.remove(friendDog.id);
                } else {
                  _selectedAdditionalDogIds.add(friendDog.id);
                }
              });
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: friendDog.photos.isNotEmpty
                            ? NetworkImage(friendDog.photos.first)
                            : null,
                        backgroundColor: Colors.grey[200],
                        child: friendDog.photos.isEmpty
                            ? const Icon(Icons.pets, color: Colors.grey)
                            : null,
                      ),
                      if (isSelected)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle,
                                color: Color(0xFFE89E5F), size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friendDog.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFFE89E5F) : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandleBar() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
