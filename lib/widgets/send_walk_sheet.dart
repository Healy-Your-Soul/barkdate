import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/features/playdates/presentation/screens/map_picker_screen.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart'
    hide DogFriendshipService;
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';
import 'package:barkdate/features/profile/presentation/providers/profile_provider.dart';
import 'package:barkdate/features/feed/presentation/providers/friend_activity_provider.dart';
import 'package:barkdate/services/conversation_service.dart';
import 'package:barkdate/core/router/app_routes.dart';

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
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  bool _isValidUuid(String value) => _uuidPattern.hasMatch(value);

  bool _isFutureWalk = false;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _locationController = TextEditingController();
  PlaceResult? _selectedPlace;

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

        final photosRaw =
            friendDogMap['photo_urls'] ?? friendDogMap['photos'] ?? [];
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

  Future<void> _selectLocation() async {
    final PlaceResult? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapPickerScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedPlace = result;
        _locationController.text = result.name;
      });
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
    if (!_isFutureWalk) {
      // For "Walk now", keep a small buffer so recipients can react.
      return DateTime.now().add(const Duration(minutes: 10));
    }

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
      if (!_isValidUuid(widget.targetDog.ownerId)) {
        throw Exception('Could not send invite: recipient account is invalid');
      }
      if (widget.targetDog.ownerId == userId) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can\'t send a walk invite to your own dog!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

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
        latitude: _selectedPlace?.latitude,
        longitude: _selectedPlace?.longitude,
      );

      if (playdateId != null) {
        // Handle Pack Multi-select: If additional dogs are selected,
        // fetch their owner IDs (from Riverpod state) and send requests.
        int additionalSent = 0;
        int additionalSkipped = 0;

        if (_selectedAdditionalDogIds.isNotEmpty) {
          for (final dogId in _selectedAdditionalDogIds) {
            final packDog = _packMembers.firstWhere((d) => d.id == dogId);

            if (!_isValidUuid(packDog.ownerId) || !_isValidUuid(packDog.id)) {
              additionalSkipped++;
              continue;
            }

            final success =
                await PlaydateRequestService.addInviteeToPlaydateRequest(
              playdateId: playdateId,
              requesterId: userId,
              requesterDogId: _myDog!.id,
              inviteeId: packDog.ownerId,
              inviteeDogId: packDog.id,
              organizerDogName: _myDog!.name,
              inviteeDogName: packDog.name,
              title: 'Walk with ${_myDog!.name}',
              location: _locationController.text.trim(),
              scheduledAt: _combinedDateTime,
              message: 'Let\'s go for a walk! 🐕',
            );

            if (success) {
              additionalSent++;
            } else {
              additionalSkipped++;
            }
          }
        }

        if (mounted) {
          ref.invalidate(userPlaydatesProvider);
          ref.invalidate(userStatsProvider);
          ref.invalidate(friendAlertsProvider);

          Navigator.pop(context, true);

          final hasPackSelection = _selectedAdditionalDogIds.isNotEmpty;
          final content = hasPackSelection
              ? (additionalSkipped > 0
                  ? 'Walk sent to ${widget.targetDog.name} + $additionalSent pack members. $additionalSkipped skipped.'
                  : 'Walk sent to ${widget.targetDog.name} + $additionalSent pack members! 🎉')
              : 'Walk request sent! 🎉';

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(content),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));

          // Navigate to the walk's group chat
          try {
            final conversation =
                await ConversationService.getPlaydateConversation(playdateId);
            if (conversation != null && mounted) {
              final nav = Navigator.of(context);
              ChatRoute(
                matchId: conversation['id'] as String,
                recipientId: widget.targetDog.ownerId,
                recipientName: widget.targetDog.ownerName,
                recipientAvatarUrl: widget.targetDog.ownerAvatarUrl ?? '',
              ).push(nav.context);
            }
          } catch (e) {
            debugPrint('Could not navigate to walk chat: $e');
          }
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isFutureWalk = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isFutureWalk
                            ? const Color(0xFFE89E5F)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Walk Now',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: !_isFutureWalk ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isFutureWalk = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isFutureWalk
                            ? const Color(0xFFE89E5F)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Schedule Future Walk',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _isFutureWalk ? Colors.white : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isFutureWalk) ...[
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
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE89E5F).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on,
                      color: Color(0xFFE89E5F), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Walk Now selected. We will send this as a near-immediate walk invite.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text('Where',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectLocation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFE89E5F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationController.text.isEmpty
                          ? 'Select a park or location'
                          : _locationController.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _locationController.text.isEmpty
                                ? Colors.grey
                                : Colors.black,
                          ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
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
              backgroundColor: const Color(0xFF4CAF50), // App Green
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

    final availableDogs =
        _packMembers.where((d) => d.id != widget.targetDog.id).toList();
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected ? const Color(0xFFE89E5F) : Colors.black87,
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
