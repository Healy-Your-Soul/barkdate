import 'package:flutter/material.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/widgets/app_card.dart';

/// Modal for creating playdate requests
/// Allows user to select date/time, location, and send invitation message
class PlaydateRequestModal extends StatefulWidget {
  final Dog targetDog;
  final String targetUserId;

  const PlaydateRequestModal({
    super.key,
    required this.targetDog,
    required this.targetUserId,
  });

  @override
  State<PlaydateRequestModal> createState() => _PlaydateRequestModalState();
}

class _PlaydateRequestModalState extends State<PlaydateRequestModal> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _messageController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0); // 2 PM default
  int _durationMinutes = 60;
  bool _isLoading = false;
  
  Dog? _myDog;
  List<String> _suggestedLocations = [
    'Central Park',
    'Riverside Dog Park',
    'Greenfield Park',
    'Downtown Dog Run',
    'Pine Valley Trails',
  ];

  @override
  void initState() {
    super.initState();
    _loadMyDog();
    _titleController.text = 'Playdate at the park';
    _locationController.text = _suggestedLocations.first;
    _messageController.text = 'Hi! Would love to arrange a playdate between our pups! 🐕';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _messageController.dispose();
    super.dispose();
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
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

  String _formatDateTime() {
    final date = _selectedDate;
    final time = _selectedTime;
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final timeStr = time.format(context);
    return '$dateStr at $timeStr';
  }

  Future<void> _sendPlaydateRequest() async {
    if (_myDog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load your dog profile')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty || _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final playdateId = await PlaydateRequestService.createPlaydateRequest(
        organizerId: userId,
        organizerDogId: _myDog!.id,
        inviteeId: widget.targetUserId,
        inviteeDogId: widget.targetDog.id,
        title: _titleController.text.trim(),
        location: _locationController.text.trim(),
        scheduledAt: _combinedDateTime,
        description: 'Playdate between ${_myDog!.name} and ${widget.targetDog.name}',
        message: _messageController.text.trim(),
        durationMinutes: _durationMinutes,
      );

      if (mounted) {
        if (playdateId != null) {
          Navigator.pop(context, true); // Return success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Playdate request sent to ${widget.targetDog.ownerName}! 🎉'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send playdate request. Please check permissions and network.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending playdate request: $e');
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: widget.targetDog.photos.isNotEmpty 
                        ? NetworkImage(widget.targetDog.photos.first)
                        : null,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: widget.targetDog.photos.isEmpty
                        ? Icon(
                            Icons.pets,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite ${widget.targetDog.name}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          'Plan a playdate',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Playdate Title',
                        hintText: 'e.g., Morning walk at the park',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.title),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date and Time selection
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedTime.format(context),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Duration selection
                    Text(
                      'Duration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [30, 60, 90, 120].map((minutes) {
                        final isSelected = _durationMinutes == minutes;
                        return ChoiceChip(
                          label: Text('${minutes}min'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _durationMinutes = minutes);
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Location field with suggestions
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'Where should you meet?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Location suggestions
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _suggestedLocations.map((location) {
                        return ActionChip(
                          label: Text(
                            location,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            _locationController.text = location;
                          },
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Message field
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Message (Optional)',
                        hintText: 'Add a personal message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.message),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Summary card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Playdate Summary',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDateTime(),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_durationMinutes}min at ${_locationController.text}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Cancel',
                      type: AppButtonType.outline,
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      text: _isLoading ? 'Sending...' : 'Send Invitation',
                      icon: Icons.send,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _sendPlaydateRequest,
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
}
