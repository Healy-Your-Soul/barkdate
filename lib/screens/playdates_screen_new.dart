import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/playdate.dart';
import '../models/enhanced_dog.dart';
import '../services/playdate_service.dart';
import '../services/auth_service.dart';

class PlaydatesScreen extends StatefulWidget {
  const PlaydatesScreen({Key? key}) : super(key: key);

  @override
  State<PlaydatesScreen> createState() => _PlaydatesScreenState();
}

class _PlaydatesScreenState extends State<PlaydatesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  List<PlaydateRequest> _requests = [];
  List<Playdate> _upcomingPlaydates = [];
  List<Playdate> _pastPlaydates = [];
  List<EnhancedDog> _userDogs = [];
  
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      _currentUserId = AuthService.getCurrentUserId();
      if (_currentUserId == null) return;

      await _loadData();
    } catch (e) {
      print('Error initializing playdate data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadData() async {
    if (_currentUserId == null) return;

    final results = await Future.wait([
      PlaydateService.getUserPlaydateRequests(_currentUserId!),
      PlaydateService.getUserPlaydates(_currentUserId!),
      PlaydateService.getUserDogs(_currentUserId!),
    ]);

    final requests = results[0] as List<PlaydateRequest>;
    final playdates = results[1] as List<Playdate>;
    final dogs = results[2] as List<EnhancedDog>;

    // Separate upcoming and past playdates
    final now = DateTime.now();
    final upcoming = <Playdate>[];
    final past = <Playdate>[];

    for (final playdate in playdates) {
      if (playdate.scheduledAt.isAfter(now) && 
          (playdate.status == PlaydateStatus.pending || 
           playdate.status == PlaydateStatus.confirmed)) {
        upcoming.add(playdate);
      } else {
        past.add(playdate);
      }
    }

    if (mounted) {
      setState(() {
        _requests = requests;
        _upcomingPlaydates = upcoming;
        _pastPlaydates = past;
        _userDogs = dogs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playdates'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.inbox),
              text: 'Requests (${_requests.where((r) => r.isPending).length})',
            ),
            Tab(
              icon: const Icon(Icons.schedule),
              text: 'Upcoming (${_upcomingPlaydates.length})',
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: 'Past (${_pastPlaydates.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(),
          _buildUpcomingTab(),
          _buildPastTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaydateDialog,
        child: const Icon(Icons.add),
        tooltip: 'Create Playdate',
      ),
    );
  }

  Widget _buildRequestsTab() {
    final pendingRequests = _requests.where((r) => r.isPending).toList();
    
    if (pendingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Playdate invitations will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pendingRequests.length,
        itemBuilder: (context, index) {
          final request = pendingRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildUpcomingTab() {
    if (_upcomingPlaydates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No upcoming playdates',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create one to get started!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreatePlaydateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Playdate'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _upcomingPlaydates.length,
        itemBuilder: (context, index) {
          final playdate = _upcomingPlaydates[index];
          return _buildPlaydateCard(playdate, isUpcoming: true);
        },
      ),
    );
  }

  Widget _buildPastTab() {
    if (_pastPlaydates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No past playdates',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Your playdate history will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pastPlaydates.length,
        itemBuilder: (context, index) {
          final playdate = _pastPlaydates[index];
          return _buildPlaydateCard(playdate, isUpcoming: false);
        },
      ),
    );
  }

  Widget _buildRequestCard(PlaydateRequest request) {
    final isIncoming = request.inviteeId == _currentUserId;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: isIncoming 
                      ? (request.requesterAvatarUrl != null 
                          ? NetworkImage(request.requesterAvatarUrl!) 
                          : null)
                      : (request.inviteeAvatarUrl != null 
                          ? NetworkImage(request.inviteeAvatarUrl!) 
                          : null),
                  child: (isIncoming 
                      ? request.requesterAvatarUrl == null 
                      : request.inviteeAvatarUrl == null)
                      ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncoming 
                            ? '${request.requesterName} invited you'
                            : 'You invited ${request.inviteeName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${request.dogName} for "${request.playdateTitle}"',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.message?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(request.message!),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  request.playdateLocation ?? 'Location TBD',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                if (request.playdateScheduledAt != null)
                  Text(
                    DateFormat('MMM d, h:mm a').format(request.playdateScheduledAt!),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
            if (isIncoming && request.isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respondToRequest(request, PlaydateRequestStatus.declined),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respondToRequest(request, PlaydateRequestStatus.accepted),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaydateCard(Playdate playdate, {required bool isUpcoming}) {
    final isOrganizer = playdate.userIsOrganizer(_currentUserId ?? '');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPlaydateDetails(playdate),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playdate.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              playdate.status.icon,
                              size: 16,
                              color: playdate.status.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              playdate.status.displayName,
                              style: TextStyle(
                                color: playdate.status.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isOrganizer)
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      playdate.location,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    playdate.formattedDateTime,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    isUpcoming ? playdate.timeDisplay : 'Completed',
                    style: TextStyle(
                      color: isUpcoming ? Colors.blue : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${playdate.participants.length}/${playdate.maxDogs} dogs',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      playdate.participantsDisplay,
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (isUpcoming && isOrganizer && playdate.canEdit) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _reschedulePlaydate(playdate),
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text('Reschedule'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _cancelPlaydate(playdate),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePlaydateDialog() {
    showDialog(
      context: context,
      builder: (context) => CreatePlaydateDialog(
        userDogs: _userDogs,
        onPlaydateCreated: () {
          _loadData();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showPlaydateDetails(Playdate playdate) {
    showDialog(
      context: context,
      builder: (context) => PlaydateDetailsDialog(
        playdate: playdate,
        currentUserId: _currentUserId!,
        onPlaydateUpdated: _loadData,
      ),
    );
  }

  Future<void> _respondToRequest(PlaydateRequest request, PlaydateRequestStatus response) async {
    final success = await PlaydateService.respondToPlaydateRequest(request.id, response);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == PlaydateRequestStatus.accepted 
                  ? 'Playdate request accepted!' 
                  : 'Playdate request declined',
            ),
          ),
        );
      }
    }
  }

  Future<void> _reschedulePlaydate(Playdate playdate) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: playdate.scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate == null) return;

    final newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(playdate.scheduledAt),
    );

    if (newTime == null) return;

    final newDateTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTime.hour,
      newTime.minute,
    );

    final success = await PlaydateService.reschedulePlaydate(playdate.id, newDateTime);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playdate rescheduled successfully')),
        );
      }
    }
  }

  Future<void> _cancelPlaydate(Playdate playdate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Playdate'),
        content: const Text('Are you sure you want to cancel this playdate? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Playdate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await PlaydateService.updatePlaydateStatus(playdate.id, PlaydateStatus.cancelled);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playdate cancelled')),
          );
        }
      }
    }
  }
}

// Dialog for creating new playdates
class CreatePlaydateDialog extends StatefulWidget {
  final List<EnhancedDog> userDogs;
  final VoidCallback onPlaydateCreated;

  const CreatePlaydateDialog({
    Key? key,
    required this.userDogs,
    required this.onPlaydateCreated,
  }) : super(key: key);

  @override
  State<CreatePlaydateDialog> createState() => _CreatePlaydateDialogState();
}

class _CreatePlaydateDialogState extends State<CreatePlaydateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  int _maxDogs = 2;
  EnhancedDog? _selectedDog;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Playdate'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EnhancedDog>(
                  value: _selectedDog,
                  decoration: const InputDecoration(labelText: 'Your Dog'),
                  items: widget.userDogs.map((dog) {
                    return DropdownMenuItem(
                      value: dog,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: dog.mainPhotoUrl != null
                                ? NetworkImage(dog.mainPhotoUrl!)
                                : null,
                            child: dog.mainPhotoUrl == null 
                                ? const Icon(Icons.pets, size: 16) 
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(dog.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (dog) => setState(() => _selectedDog = dog),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('Date'),
                        subtitle: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                        onTap: _selectDate,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('Time'),
                        subtitle: Text(_selectedTime.format(context)),
                        onTap: _selectTime,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Max Dogs: '),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _maxDogs,
                      items: [2, 3, 4, 5, 6].map((i) {
                        return DropdownMenuItem(value: i, child: Text('$i'));
                      }).toList(),
                      onChanged: (value) => setState(() => _maxDogs = value!),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createPlaydate,
          child: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _createPlaydate() async {
    if (!_formKey.currentState!.validate() || _selectedDog == null) return;

    setState(() => _isLoading = true);

    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return;

    final playdate = await PlaydateService.createPlaydate(
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      location: _locationController.text,
      scheduledAt: scheduledAt,
      maxDogs: _maxDogs,
      organizerId: currentUserId,
      organizerDogId: _selectedDog!.id,
    );

    setState(() => _isLoading = false);

    if (playdate != null) {
      widget.onPlaydateCreated();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create playdate')),
      );
    }
  }
}

// Dialog for showing playdate details
class PlaydateDetailsDialog extends StatelessWidget {
  final Playdate playdate;
  final String currentUserId;
  final VoidCallback onPlaydateUpdated;

  const PlaydateDetailsDialog({
    Key? key,
    required this.playdate,
    required this.currentUserId,
    required this.onPlaydateUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOrganizer = playdate.userIsOrganizer(currentUserId);
    final isParticipant = playdate.userIsParticipant(currentUserId);

    return AlertDialog(
      title: Text(playdate.title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (playdate.description?.isNotEmpty == true) ...[
                Text(playdate.description!),
                const SizedBox(height: 16),
              ],
              _buildDetailRow(Icons.location_on, 'Location', playdate.location),
              _buildDetailRow(Icons.access_time, 'Date & Time', playdate.formattedDateTime),
              _buildDetailRow(Icons.pets, 'Dogs', '${playdate.participants.length}/${playdate.maxDogs}'),
              _buildDetailRow(Icons.info, 'Status', playdate.status.displayName),
              const SizedBox(height: 16),
              const Text('Participants:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...playdate.participants.map((participant) => _buildParticipantTile(participant)),
              if (playdate.canJoin && !isParticipant && !isOrganizer) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinPlaydate(context),
                    child: const Text('Join Playdate'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(PlaydateParticipant participant) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: participant.userAvatarUrl != null
            ? NetworkImage(participant.userAvatarUrl!)
            : null,
        child: participant.userAvatarUrl == null 
            ? const Icon(Icons.person) 
            : null,
      ),
      title: Row(
        children: [
          Text(participant.userName),
          if (participant.isOrganizer) ...[
            const SizedBox(width: 4),
            const Icon(Icons.star, size: 16, color: Colors.amber),
          ],
        ],
      ),
      subtitle: Text('with ${participant.dogName}'),
      trailing: participant.dogPhotoUrl != null
          ? CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(participant.dogPhotoUrl!),
            )
          : const CircleAvatar(
              radius: 16,
              child: Icon(Icons.pets, size: 16),
            ),
    );
  }

  Future<void> _joinPlaydate(BuildContext context) async {
    // For now, just show that this would work with the enhanced dog model
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Join functionality would use enhanced dog selection here'),
      ),
    );
  }
}
