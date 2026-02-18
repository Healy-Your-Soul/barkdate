import 'package:flutter/material.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/widgets/app_card.dart';

/// Enhanced playdate response bottom sheet with progressive disclosure
/// Inspired by FluffyChat invitations + Beacon multi-step flows
class PlaydateResponseBottomSheet extends StatefulWidget {
  final Map<String, dynamic> request; // renamed from playdateRequest
  final VoidCallback? onResponseSent;

  const PlaydateResponseBottomSheet({
    super.key,
    required this.request,
    this.onResponseSent,
  });

  // Backward compatibility getter
  Map<String, dynamic> get playdateRequest => request;

  @override
  State<PlaydateResponseBottomSheet> createState() =>
      _PlaydateResponseBottomSheetState();
}

class _PlaydateResponseBottomSheetState
    extends State<PlaydateResponseBottomSheet> with TickerProviderStateMixin {
  bool _isLoading = false;

  String _message = '';
  DateTime? _suggestedTime;
  String? _suggestedLocation;
  List<Dog> _selectedDogs = [];
  List<Dog> _availableDogs = [];

  final _messageController = TextEditingController();
  final _locationController = TextEditingController();

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserDogs();
    _initAnimations();
    _setupDefaultValues();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  void _setupDefaultValues() {
    final playdate = widget.playdateRequest['playdate'];
    if (playdate != null) {
      _locationController.text = playdate['location'] ?? '';
      if (playdate['scheduled_at'] != null) {
        _suggestedTime = DateTime.parse(playdate['scheduled_at']);
      }
    }
  }

  Future<void> _loadUserDogs() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      final dogData = await BarkDateUserService.getUserDogs(user.id);
      final dogs = dogData
          .map<Dog>((data) => Dog(
                id: data['id'] as String,
                name: data['name'] as String,
                breed: data['breed'] as String,
                age: data['age'] as int,
                size: data['size'] as String,
                gender: data['gender'] as String,
                bio: data['bio'] as String? ?? '',
                photos: List<String>.from(data['photo_urls'] ?? []),
                ownerId: data['user_id'] as String,
                ownerName: 'You',
                distanceKm: 0,
              ))
          .toList();

      setState(() {
        _availableDogs = dogs;
        if (dogs.isNotEmpty) {
          _selectedDogs = [dogs.first]; // Default to first dog
        }
      });
    } catch (e) {
      debugPrint('Error loading user dogs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playdate = widget.playdateRequest['playdate'];
    final requester = widget.playdateRequest['requester'];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Playdate Invitation',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'from ${requester?['name'] ?? 'Someone'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Playdate Details Card
              AppCard(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          playdate?['title'] ?? 'Playdate',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                        Icons.schedule, _formatDateTime(_suggestedTime)),
                    _buildDetailRow(Icons.location_on,
                        playdate?['location'] ?? 'Location TBD'),
                    if (playdate?['description'] != null)
                      _buildDetailRow(Icons.notes, playdate['description']),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quick Response Buttons
                      Text(
                        'Quick Response',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildResponseButton(
                              'Accept',
                              Icons.check_circle,
                              theme.colorScheme.primary,
                              () => _handleQuickResponse('accepted'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildResponseButton(
                              'Decline',
                              Icons.cancel,
                              theme.colorScheme.error,
                              () => _handleQuickResponse('declined'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Suggest Changes Section
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainer,
                        child: ExpansionTile(
                          title: Text(
                            'Suggest Changes',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          leading: Icon(
                            Icons.edit,
                            color: theme.colorScheme.secondary,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildTimeSection(theme),
                                  const SizedBox(height: 20),
                                  _buildLocationSection(theme),
                                  const SizedBox(height: 20),
                                  _buildDogSection(theme),
                                  const SizedBox(height: 20),
                                  _buildMessageSection(theme),
                                  const SizedBox(height: 24),
                                  AppButton(
                                    text: _isLoading
                                        ? 'Sending...'
                                        : 'Send Counter-Proposal',
                                    icon: Icons.send,
                                    isLoading: _isLoading,
                                    onPressed: _isLoading
                                        ? null
                                        : () => _handleCounterProposal(),
                                    customColor: theme.colorScheme.secondary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // Close GestureDetector
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildTimeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggest Different Time',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTimeSuggestionChip('Tomorrow 2 PM'),
            _buildTimeSuggestionChip('This Weekend'),
            _buildTimeSuggestionChip('Next Week'),
            _buildCustomTimeChip(),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggest Different Location',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            hintText: 'Enter location or select from map',
            suffixIcon: IconButton(
              icon: const Icon(Icons.map),
              onPressed: () {
                // TODO: Open map picker (coming soon)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Map picker coming soon!')),
                );
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) => _suggestedLocation = value,
        ),
      ],
    );
  }

  Widget _buildDogSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Dogs',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_availableDogs.isEmpty)
          const Text('Loading your dogs...')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableDogs
                .map((dog) => _buildDogSelectionChip(dog))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildMessageSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Message (Optional)',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          decoration: InputDecoration(
            hintText: 'Add a note with your counter-proposal...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
          onChanged: (value) => _message = value,
        ),
      ],
    );
  }

  Widget _buildTimeSuggestionChip(String text) {
    return FilterChip(
      label: Text(text),
      selected: false,
      onSelected: (selected) {
        // Handle time suggestion selection
        setState(() {
          // Set suggested time based on selection
        });
      },
    );
  }

  Widget _buildCustomTimeChip() {
    return ActionChip(
      label: const Text('Custom Time'),
      avatar: const Icon(Icons.schedule, size: 18),
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate:
              _suggestedTime ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );

        if (date != null && mounted) {
          final time = await showTimePicker(
            context: context,
            initialTime:
                TimeOfDay.fromDateTime(_suggestedTime ?? DateTime.now()),
          );

          if (time != null) {
            setState(() {
              _suggestedTime = DateTime(
                  date.year, date.month, date.day, time.hour, time.minute);
            });
          }
        }
      },
    );
  }

  Widget _buildDogSelectionChip(Dog dog) {
    final isSelected = _selectedDogs.any((d) => d.id == dog.id);
    return FilterChip(
      label: Text(dog.name),
      selected: isSelected,
      avatar: CircleAvatar(
        radius: 12,
        backgroundImage:
            dog.photos.isNotEmpty ? NetworkImage(dog.photos.first) : null,
        child: dog.photos.isEmpty ? const Icon(Icons.pets, size: 12) : null,
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDogs.add(dog);
          } else {
            _selectedDogs.removeWhere((d) => d.id == dog.id);
          }
        });
      },
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Time TBD';
    return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) return 'Today';
    if (date == today.add(const Duration(days: 1))) return 'Tomorrow';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Future<void> _handleQuickResponse(String response) async {
    setState(() => _isLoading = true);

    try {
      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: widget.playdateRequest['id'],
        userId: SupabaseConfig.auth.currentUser!.id,
        response: response,
        message: response == 'accepted'
            ? 'Excited for the playdate!'
            : 'Thanks for the invitation, but we can\'t make it this time.',
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onResponseSent?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response == 'accepted'
                ? 'Playdate accepted! 🎉'
                : 'Response sent'),
            backgroundColor: response == 'accepted'
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send response: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCounterProposal() async {
    setState(() => _isLoading = true);

    try {
      final counterProposal = <String, dynamic>{};

      if (_suggestedTime != null) {
        counterProposal['time'] = _suggestedTime!.toIso8601String();
      }

      if (_suggestedLocation != null && _suggestedLocation!.isNotEmpty) {
        counterProposal['location'] = _suggestedLocation;
      }

      if (_selectedDogs.isNotEmpty) {
        counterProposal['dogs'] = _selectedDogs.map((d) => d.id).toList();
      }

      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: widget.playdateRequest['id'],
        userId: SupabaseConfig.auth.currentUser!.id,
        response: 'counter_proposed',
        message: _message.isNotEmpty
            ? _message
            : 'I have some suggestions for the playdate!',
        counterProposal: counterProposal,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onResponseSent?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Counter-proposal sent! 💡'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send counter-proposal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _messageController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
