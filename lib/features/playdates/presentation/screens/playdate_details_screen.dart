import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/playdate_service.dart';
import 'package:barkdate/models/playdate.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';

class PlaydateDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> playdate;

  const PlaydateDetailsScreen({super.key, required this.playdate});

  @override
  ConsumerState<PlaydateDetailsScreen> createState() =>
      _PlaydateDetailsScreenState();
}

class _PlaydateDetailsScreenState extends ConsumerState<PlaydateDetailsScreen> {
  bool _isLoading = false;
  bool _showSuggestChanges = false;
  late Map<String, dynamic> _playdate;
  List<Map<String, dynamic>> _invitedDogs = []; // Invited dogs with status
  Map<String, dynamic>? _organizerDog; // Organizer's dog

  // Controllers for suggesting changes
  final _locationController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _suggestedDateTime;

  @override
  void initState() {
    super.initState();
    _playdate = widget.playdate;
    _locationController.text = _playdate['location'] ?? '';

    // Parse existing date
    final scheduledAtStr = _playdate['scheduled_at'] ?? _playdate['date_time'];
    if (scheduledAtStr != null) {
      _suggestedDateTime = DateTime.tryParse(scheduledAtStr);
    }

    // Fetch dogs with their status
    _fetchPlaydateDogs();
  }

  Future<void> _fetchPlaydateDogs() async {
    final playdateId = _playdate['playdate_id'] ?? _playdate['id'];
    if (playdateId == null) return;

    try {
      // Fetch invited dogs from playdate_requests
      final requests = await SupabaseConfig.client
          .from('playdate_requests')
          .select(
              '*, invitee_dog:dogs!playdate_requests_invitee_dog_id_fkey(id, name, main_photo_url), requester_dog:dogs!playdate_requests_requester_dog_id_fkey(id, name, main_photo_url)')
          .eq('playdate_id', playdateId);

      // Fetch organizer's dog from playdate_participants
      final participants = await SupabaseConfig.client
          .from('playdate_participants')
          .select('*, dog:dogs(id, name, main_photo_url)')
          .eq('playdate_id', playdateId)
          .eq('is_organizer', true)
          .limit(1);

      if (mounted) {
        setState(() {
          _invitedDogs = List<Map<String, dynamic>>.from(requests);
          if (participants.isNotEmpty) {
            _organizerDog = participants[0]['dog'] as Map<String, dynamic>?;
          }
          // Fallback: get requester dog from first request
          if (_organizerDog == null && requests.isNotEmpty) {
            _organizerDog =
                requests[0]['requester_dog'] as Map<String, dynamic>?;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching playdate dogs: $e');
    }
  }

  List<Widget> _buildOrganizerDogCards() {
    if (_organizerDog == null) return [];

    final dogName = _organizerDog!['name'] ?? 'Organizer';
    final dogPhoto = _organizerDog!['main_photo_url'] as String?;

    return [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: _buildDogStatusCard(dogName, dogPhoto, 'confirmed',
            isOrganizer: true),
      ),
    ];
  }

  @override
  void dispose() {
    _locationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _currentUserId => SupabaseConfig.auth.currentUser?.id ?? '';

  String get _status =>
      (_playdate['status'] ?? 'pending').toString().toLowerCase();

  bool get _isPending => _status == 'pending';

  bool get _isCurrentUserInvitee {
    final inviteeId = _playdate['invitee_id'];
    return inviteeId != null && inviteeId == _currentUserId;
  }

  bool get _isCurrentUserOrganizer {
    final organizerId = _playdate['organizer_id'] ?? _playdate['requester_id'];
    return organizerId != null && organizerId == _currentUserId;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _suggestedDateTime ?? now.add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_suggestedDateTime ?? now),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _suggestedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _respondToPlaydate(bool accept) async {
    final requestId = _playdate['request_id'] ?? _playdate['id'];
    if (requestId == null) {
      _showError('Unable to respond - missing request ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = accept
          ? PlaydateRequestStatus.accepted
          : PlaydateRequestStatus.declined;

      final success = await PlaydateService.respondToPlaydateRequest(
        requestId,
        response,
      );

      if (success && mounted) {
        // Refresh the playdates list in feed
        ref.invalidate(userPlaydatesProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(accept ? 'Playdate accepted! 🎉' : 'Playdate declined'),
            backgroundColor: accept ? Colors.green : Colors.grey,
          ),
        );
        setState(() {
          _playdate = {
            ..._playdate,
            'status': accept ? 'confirmed' : 'declined'
          };
        });
      } else if (mounted) {
        _showError('Failed to respond. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitSuggestedChanges() async {
    final requestId = _playdate['request_id'] ?? _playdate['id'];
    final playdateId = _playdate['playdate_id'] ?? _playdate['id'];

    if (requestId == null || playdateId == null) {
      _showError('Unable to suggest changes - missing IDs');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await PlaydateService.counterProposePlaydate(
        requestId: requestId,
        playdateId: playdateId,
        newScheduledAt: _suggestedDateTime,
        newLocation: _locationController.text.trim(),
        message: _messageController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes suggested! Waiting for response...'),
            backgroundColor: Colors.blue,
          ),
        );
        setState(() {
          _playdate = {..._playdate, 'status': 'counter_proposed'};
          _showSuggestChanges = false;
        });
      } else if (mounted) {
        _showError('Failed to suggest changes. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelPlaydate() async {
    final playdateId = _playdate['playdate_id'] ?? _playdate['id'];
    if (playdateId == null) {
      _showError('Unable to cancel - missing playdate ID');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Playdate'),
        content: const Text('Are you sure you want to cancel this playdate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await PlaydateService.updatePlaydateStatus(
        playdateId,
        PlaydateStatus.cancelled,
      );

      if (success && mounted) {
        // Refresh the playdates list in feed
        ref.invalidate(userPlaydatesProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playdate cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _playdate = {..._playdate, 'status': 'cancelled'};
        });
      } else if (mounted) {
        _showError('Failed to cancel. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduledAtStr = _playdate['scheduled_at'] ?? _playdate['date_time'];
    final scheduledAt = scheduledAtStr != null
        ? DateTime.tryParse(scheduledAtStr) ?? DateTime.now()
        : DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(scheduledAt);
    final formattedTime = DateFormat('h:mm a').format(scheduledAt);
    final location = _playdate['location'] ?? 'Unknown Location';
    final organizer = _playdate['organizer'] as Map<String, dynamic>?;
    final participant = _playdate['participant'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Playdate Details'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtle Status Chip (inline instead of big banner)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(_status),
                            color: _getStatusColor(_status),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusDisplayName(_status),
                            style: TextStyle(
                              color: _getStatusColor(_status),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Time and Location
                    _buildInfoRow(
                        context, Icons.calendar_today, 'Date', formattedDate),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        context, Icons.access_time, 'Time', formattedTime),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        context, Icons.location_on, 'Location', location),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Dogs Section with better layout
                    Text(
                      'Dogs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // All dogs in a nice horizontal scroll
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Organizer's dog first (from participants with is_organizer = true)
                          ..._buildOrganizerDogCards(),

                          // Then invited dogs
                          ..._invitedDogs.map((request) {
                            final dog =
                                request['invitee_dog'] as Map<String, dynamic>?;
                            final status =
                                (request['status'] as String? ?? 'pending')
                                    .toLowerCase();
                            final dogName = dog?['name'] ?? 'Unknown';
                            final dogPhoto = dog?['main_photo_url'] as String?;

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: _buildDogStatusCard(
                                  dogName, dogPhoto, status,
                                  isOrganizer: false),
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    // Action Buttons for Pending Playdates
                    if (_isPending) ...[
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),
                      if (_isCurrentUserInvitee) ...[
                        Text(
                          'Respond to Invitation',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        // Accept/Decline Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _respondToPlaydate(false),
                                icon: const Icon(Icons.close),
                                label: const Text('Decline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _respondToPlaydate(true),
                                icon: const Icon(Icons.check),
                                label: const Text('Accept'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Suggest Changes Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() =>
                                _showSuggestChanges = !_showSuggestChanges),
                            icon: Icon(_showSuggestChanges
                                ? Icons.expand_less
                                : Icons.edit_calendar),
                            label: Text(_showSuggestChanges
                                ? 'Hide'
                                : 'Suggest Different Time/Place'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),

                        // Suggest Changes Form
                        if (_showSuggestChanges) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suggest Changes',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                ),
                                const SizedBox(height: 16),

                                // Date/Time Picker
                                InkWell(
                                  onTap: _pickDateTime,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Suggested Date & Time',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      _suggestedDateTime != null
                                          ? DateFormat('MMM d, y \'at\' h:mm a')
                                              .format(_suggestedDateTime!)
                                          : 'Tap to select',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Location Field
                                TextField(
                                  controller: _locationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Suggested Location',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.location_on),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Message Field
                                TextField(
                                  controller: _messageController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Message (optional)',
                                    hintText:
                                        'e.g., "How about Saturday instead?"',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.message),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _submitSuggestedChanges,
                                    icon: const Icon(Icons.send),
                                    label: const Text('Send Suggestion'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else if (_isCurrentUserOrganizer) ...[
                        Text(
                          'Manage Playdate',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _cancelPlaydate,
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel Playdate'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ), // Close GestureDetector
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantRow(
      BuildContext context, String role, Map<String, dynamic> user) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: user['avatar_url'] != null
              ? NetworkImage(user['avatar_url'])
              : null,
          child: user['avatar_url'] == null ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['name'] ?? 'Unknown',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              role,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return 'CONFIRMED';
      case 'pending':
        return 'PENDING';
      case 'cancelled':
        return 'CANCELLED';
      case 'declined':
        return 'DECLINED';
      case 'counter_proposed':
        return 'CHANGES SUGGESTED';
      default:
        return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'declined':
        return Colors.red;
      case 'counter_proposed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'cancelled':
      case 'declined':
        return Icons.cancel;
      case 'counter_proposed':
        return Icons.edit_calendar;
      default:
        return Icons.help;
    }
  }

  Widget _buildDogStatusCard(String dogName, String? photoUrl, String status,
      {bool isOrganizer = false}) {
    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;

    if (isOrganizer) {
      // Organizer gets a special star badge - green since they're confirmed
      statusColor = Colors.green;
      statusIcon = Icons.star;
    } else {
      switch (status) {
        case 'accepted':
        case 'confirmed':
          statusColor = Colors.green;
          statusIcon = Icons.check;
          break;
        case 'declined':
        case 'cancelled':
          statusColor = Colors.red;
          statusIcon = Icons.close;
          break;
        default: // pending
          statusColor = Colors.orange;
          statusIcon = Icons.help_outline;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dog Avatar with Status Badge
        Stack(
          children: [
            // Dog Photo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                border: isOrganizer
                    ? Border.all(color: Colors.green, width: 3)
                    : null,
                image: photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl == null
                  ? const Icon(Icons.pets, size: 32, color: Colors.grey)
                  : null,
            ),
            // Status Badge
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  statusIcon,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Dog Name and Role
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Text(
                dogName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isOrganizer)
                Text(
                  'Organizer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
