import 'package:flutter/material.dart';
import 'dart:async';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/widgets/playdate_response_bottom_sheet.dart';
import 'package:barkdate/widgets/playdate_action_popup.dart';

class PlaydatesScreen extends StatefulWidget {
  final int? initialTabIndex; // 0=Requests, 1=Upcoming, 2=Past
  final String? highlightPlaydateId;

  const PlaydatesScreen({Key? key, this.initialTabIndex, this.highlightPlaydateId}) : super(key: key);

  @override
  State<PlaydatesScreen> createState() => _PlaydatesScreenState();
}

class _PlaydatesScreenState extends State<PlaydatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _upcomingPlaydates = [];
  List<Map<String, dynamic>> _pastPlaydates = [];
  List<Map<String, dynamic>> _pendingRequests = []; // Incoming requests (where user is invitee)
  List<Map<String, dynamic>> _sentRequests = []; // Outgoing requests (where user is requester)
  bool _isLoading = true;
  StreamSubscription? _subPlaydatesOrganizer;
  StreamSubscription? _subPlaydatesParticipant;
  StreamSubscription? _subRequests;
  StreamSubscription? _subParticipants;
  final ScrollController _upcomingController = ScrollController();
  final Map<String, GlobalKey> _playdateKeys = {};
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialTabIndex != null && widget.initialTabIndex! >= 0 && widget.initialTabIndex! < 3) {
      _tabController.index = widget.initialTabIndex!;
    }
    _highlightId = widget.highlightPlaydateId;
    _loadPlaydates();
    _initRealtime();
  }

  Future<void> _loadPlaydates() async {
    try {
      setState(() => _isLoading = true);
      
      final user = SupabaseAuth.currentUser;
      if (user == null) {
        debugPrint('=== NO USER, LOADING SAMPLE DATA ===');
        _loadSampleDataWithRequests();
        return;
      }

      debugPrint('=== LOADING PLAYDATES FOR USER: ${user.id} ===');

  // Aggregated loading (multi-owner) – legacy direct queries removed
      
  // Multi-owner aware aggregated query (participants pivot)
  debugPrint('=== GETTING AGGREGATED PLAYDATES (multi-owner) ===');
  final aggregated = await PlaydateQueryService.getUserPlaydatesAggregated(user.id);
  final upcoming = aggregated['upcoming'] ?? [];
  final past = aggregated['past'] ?? [];
  debugPrint('=== FOUND ${upcoming.length} UPCOMING / ${past.length} PAST (AGGREGATED) ===');

      // Get both incoming and outgoing requests
      debugPrint('=== GETTING INCOMING REQUESTS (Chen is invitee) ===');
      final incomingRequests = await PlaydateRequestService.getPendingRequests(user.id);
      debugPrint('=== RECEIVED ${incomingRequests.length} INCOMING REQUESTS ===');
      
      debugPrint('=== GETTING SENT REQUESTS (Chen is requester) ===');
      final sentRequests = await PlaydateRequestService.getSentRequests(user.id);
      debugPrint('=== RECEIVED ${sentRequests.length} SENT REQUESTS ===');

      if (mounted) {
        setState(() {
          _upcomingPlaydates = List<Map<String, dynamic>>.from(upcoming);
          _pastPlaydates = List<Map<String, dynamic>>.from(past);
          _pendingRequests = incomingRequests; // Incoming requests for response
          _sentRequests = sentRequests; // Sent requests for tracking
          _isLoading = false;
        });
      }

      final totalRequests = _pendingRequests.length + _sentRequests.length;
      final totalPlaydates = _upcomingPlaydates.length + _pastPlaydates.length;
      debugPrint('=== FINAL STATE: $totalRequests total requests, $totalPlaydates total playdates ===');
      
      // No fallback to sample data - always use real Supabase data
      _tryScrollToHighlight();
    } catch (e) {
      debugPrint('Error loading playdates: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading playdates: $e')),
        );
      }
    }
  }

  void _loadSampleDataWithRequests() {
    debugPrint('=== LOADING ENHANCED SAMPLE DATA ===');
    final now = DateTime.now();
    
    final samplePending = [
      {
        'id': 'sample-incoming-1',
        'playdate': {
          'id': 'sample-playdate-1',
          'location': 'Dolores Park',
          'scheduled_at': now.add(const Duration(days: 2)).toIso8601String(),
          'description': 'Let\'s meet for a fun playdate!',
        },
        'requester': {'name': 'Alex Johnson'},
        'invitee_dog': {'name': 'Buddy', 'breed': 'Golden Retriever'},
        'status': 'pending',
        'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      }
    ];
    
    final sampleSent = [
      {
        'id': 'sample-sent-1',
        'playdate': {
          'id': 'sample-playdate-2',
          'location': 'Mission Bay Park',
          'scheduled_at': now.add(const Duration(days: 3)).toIso8601String(),
          'description': 'Looking forward to meeting!',
        },
        'invitee': {'name': 'Sarah Wilson'},
        'invitee_dog': {'name': 'Luna', 'breed': 'Border Collie'},
        'status': 'pending',
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
      }
    ];

    // Add sample upcoming playdates (confirmed ones)
    final sampleUpcoming = [
      {
        'id': 'sample-upcoming-1',
        'title': 'Dog Park Meetup',
        'location': 'Golden Gate Park',
        'scheduled_at': now.add(const Duration(days: 1)).toIso8601String(),
        'description': 'Excited to meet up!',
        'status': 'confirmed',
        'organizer_id': 'other-user-id',
        'participant_id': 'current-user-id',
        'organizer': {'name': 'Emma Davis', 'avatar_url': null},
        'participant': {'name': 'Chen', 'avatar_url': null},
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 'sample-upcoming-2',
        'title': 'Beach Playdate',
        'location': 'Crissy Field',
        'scheduled_at': now.add(const Duration(days: 4)).toIso8601String(),
        'description': 'Beach fun with the pups!',
        'status': 'confirmed',
        'organizer_id': 'current-user-id',
        'participant_id': 'other-user-id-2',
        'organizer': {'name': 'Chen', 'avatar_url': null},
        'participant': {'name': 'Mike Johnson', 'avatar_url': null},
        'created_at': now.subtract(const Duration(hours: 6)).toIso8601String(),
      }
    ];
    
    setState(() {
      _upcomingPlaydates = sampleUpcoming;
      _pastPlaydates = [];
      _pendingRequests = samplePending; // Incoming requests
      _sentRequests = sampleSent; // Sent requests
      _isLoading = false;
    });
    
    debugPrint('=== SAMPLE DATA LOADED: ${_pendingRequests.length} incoming + ${_sentRequests.length} sent ===');
  }

  void _initRealtime() {
    final user = SupabaseAuth.currentUser;
    if (user == null) return;

    // Listen for changes to both incoming and outgoing requests
  // Listen to requests involving user both as requester & invitee
  // Supabase Dart client stream doesn't support .or; subscribe twice
  final requesterStream = SupabaseConfig.client
    .from('playdate_requests')
    .stream(primaryKey: ['id'])
    .eq('requester_id', user.id)
    .listen((_) { if (mounted) _loadPlaydates(); });
  final inviteeStream = SupabaseConfig.client
    .from('playdate_requests')
    .stream(primaryKey: ['id'])
    .eq('invitee_id', user.id)
    .listen((_) { if (mounted) _loadPlaydates(); });
  // Store one subscription handle; others tracked separately
  _subRequests = requesterStream;
  _subParticipants = inviteeStream;

  // Listen to participant changes for live updates (join/leave)
  _subParticipants = SupabaseConfig.client
    .from('playdate_participants')
    .stream(primaryKey: ['id'])
    .listen((_) { if (mounted) _loadPlaydates(); });
  }

  void _tryScrollToHighlight() {
    if (_highlightId == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _playdateKeys[_highlightId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(key!.currentContext!);
      }
    });
  }

  @override
  void dispose() {
    _subPlaydatesOrganizer?.cancel();
    _subPlaydatesParticipant?.cancel();
    _subRequests?.cancel();
    _subParticipants?.cancel();
    _tabController.dispose();
    _upcomingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalRequests = _pendingRequests.length + _sentRequests.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Playdates ($totalRequests pending)'),
        backgroundColor: Theme.of(context).primaryColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Requests ($totalRequests)'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
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
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalRequests = _pendingRequests.length + _sentRequests.length;
    if (totalRequests == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text('No pending requests', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Incoming and sent requests will appear here', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadPlaydates(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Create a single combined list
    List<Widget> allWidgets = [];
    
    // Add incoming requests section if any
    if (_pendingRequests.isNotEmpty) {
      allWidgets.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Incoming Requests (${_pendingRequests.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
      );
      
      for (var request in _pendingRequests) {
        allWidgets.add(_buildIncomingRequestCard(request));
      }
    }
    
    // Add sent requests section if any
    if (_sentRequests.isNotEmpty) {
      allWidgets.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sent Requests (${_sentRequests.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
      );
      
      for (var request in _sentRequests) {
        allWidgets.add(_buildSentRequestCard(request));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadPlaydates,
      child: ListView(children: allWidgets),
    );
  }

  Widget _buildIncomingRequestCard(Map<String, dynamic> request) {
    final playdate = request['playdate'];
    final requester = request['requester'];
    final inviteeDog = request['invitee_dog'];
    final status = request['status'] ?? 'pending';
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.pets, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Playdate Invitation!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'From: ${requester?['name'] ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (inviteeDog != null)
                        Text(
                          'For: ${inviteeDog['name']} (${inviteeDog['breed'] ?? 'Mixed'})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: status == 'accepted' && playdate != null 
                      ? () => _showPlaydatePopup(playdate)
                      : null,
                    child: Text(
                      status == 'accepted' ? 'SET' : status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (playdate != null) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Text(playdate['location'] ?? 'No location'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Text(_formatDateTime(playdate['scheduled_at'])),
                ],
              ),
              if (playdate['description'] != null) ...[
                const SizedBox(height: 8),
                Text(playdate['description']),
              ],
            ],
            const SizedBox(height: 12),
            if (status == 'pending') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _respondToRequest(request, 'declined'),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _showResponseBottomSheet(request),
                    child: const Text('Suggest Changes'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _respondToRequest(request, 'accepted'),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSentRequestCard(Map<String, dynamic> request) {
    final playdate = request['playdate'];
    final invitee = request['invitee'];
    final inviteeDog = request['invitee_dog'];
    final status = request['status'] ?? 'pending';
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(inviteeDog?['name']?.substring(0, 1) ?? '?'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sent to ${inviteeDog?['name'] ?? 'Unknown Dog'}!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Owner: ${invitee?['name'] ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (inviteeDog?['breed'] != null)
                        Text(
                          inviteeDog['breed'],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: status == 'accepted' && playdate != null 
                      ? () => _showPlaydatePopup(playdate)
                      : null,
                    child: Text(
                      status == 'accepted' ? 'SET' : status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (playdate != null) ...[
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Text(playdate['location'] ?? 'No location'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Text(_formatDateTime(playdate['scheduled_at'])),
                ],
              ),
              if (playdate['description'] != null) ...[
                const SizedBox(height: 8),
                Text(playdate['description']),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'pending') ...[
                  TextButton(
                    onPressed: () => _cancelRequest(request['id']),
                    child: const Text('Cancel'),
                  ),
                ] else if (status == 'declined') ...[
                  TextButton(
                    onPressed: () => _resendRequest(request),
                    child: const Text('Send New Request'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'No date';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = dateTime.difference(now).inDays;
      
      if (difference == 0) {
        return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference == 1) {
        return 'Tomorrow ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildUpcomingTab() {
    debugPrint('=== BUILDING UPCOMING TAB WITH ${_upcomingPlaydates.length} PLAYDATES ===');
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_upcomingPlaydates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text('No upcoming playdates', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Confirmed playdates will appear here', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadPlaydates(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaydates,
      child: ListView.builder(
        controller: _upcomingController,
        itemCount: _upcomingPlaydates.length,
        itemBuilder: (context, index) {
          final playdate = _upcomingPlaydates[index];
          _playdateKeys[playdate['id']] = GlobalKey();
          return Container(
            key: playdate['id'] == _highlightId ? _playdateKeys[playdate['id']] : null,
            child: Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.pets, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playdate['title'] ?? 'Playdate',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (playdate['organizer'] != null || playdate['participant'] != null)
                                Text(
                                  'With: ${_getOtherPartyName(playdate)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: ElevatedButton(
                            onPressed: () {
                              debugPrint('=== SET BUTTON CLICKED FOR PLAYDATE: ${playdate['id']} ===');
                              debugPrint('=== PLAYDATE DATA: $playdate ===');
                              _showPlaydatePopup(playdate);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'EDIT',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Theme.of(context).hintColor),
                        const SizedBox(width: 4),
                        Text(playdate['location'] ?? 'Location TBD'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Theme.of(context).hintColor),
                        const SizedBox(width: 4),
                        Text(_formatDateTime(playdate['scheduled_at'])),
                      ],
                    ),
                    if (playdate['description'] != null) ...[
                      const SizedBox(height: 8),
                      Text(playdate['description']),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPastTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pastPlaydates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text('No past playdates', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Completed playdates will appear here', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadPlaydates(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaydates,
      child: ListView.builder(
        itemCount: _pastPlaydates.length,
        itemBuilder: (context, index) {
          final playdate = _pastPlaydates[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(playdate['location'] ?? 'Unknown location'),
              subtitle: Text(_formatDateTime(playdate['scheduled_at'])),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to playdate recap
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _respondToRequest(Map<String, dynamic> request, String response) async {
    try {
      final requestId = request['id'] as String?;
      final userId = SupabaseConfig.auth.currentUser?.id;
      
      if (requestId == null || userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to respond right now')),
        );
        return;
      }

      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: requestId,
        userId: userId,
        response: response,
        message: response == 'accepted' 
          ? 'Looking forward to the playdate!' 
          : 'Thanks for the invitation, but we can\'t make it this time.',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response == 'accepted' 
                ? 'Playdate accepted! 🎉' 
                : 'Request declined'),
              backgroundColor: response == 'accepted' ? Colors.green : Colors.grey,
            ),
          );
          _loadPlaydates(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send response. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showResponseBottomSheet(Map<String, dynamic> request) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaydateResponseBottomSheet(
        request: request,
        onResponseSent: () => _loadPlaydates(),
      ),
    );
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await PlaydateRequestService.cancelRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled')),
        );
        _loadPlaydates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling request: $e')),
        );
      }
    }
  }

  Future<void> _resendRequest(Map<String, dynamic> originalRequest) async {
    // Navigate back to create new playdate request
    Navigator.of(context).pop(); // Return to main playdates screen
    // The user can then send a new request
  }

  String _getOtherPartyName(Map<String, dynamic> playdate) {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    if (playdate['organizer_id'] == currentUserId) {
      return playdate['participant']?['name'] ?? 'Unknown';
    } else {
      return playdate['organizer']?['name'] ?? 'Unknown';
    }
  }

  void _showPlaydatePopup(Map<String, dynamic> playdate) {
    debugPrint('=== _showPlaydatePopup CALLED ===');
    debugPrint('=== Playdate data: $playdate ===');
    try {
      PlaydateActionPopup.show(
        context,
        playdate: playdate,
        onChat: () {
          debugPrint('=== CHAT BUTTON PRESSED ===');
          Navigator.of(context).pop();
          // TODO: Navigate to chat screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat feature coming soon!')),
          );
        },
        onReschedule: () {
          debugPrint('=== RESCHEDULE BUTTON PRESSED ===');
          Navigator.of(context).pop();
          _showRescheduleDialog(playdate);
        },
        onCancel: () {
          debugPrint('=== CANCEL BUTTON PRESSED ===');
          Navigator.of(context).pop();
          _showCancelConfirmation(playdate);
        },
      );
    } catch (e) {
      debugPrint('=== ERROR SHOWING POPUP: $e ===');
      // Fallback - show simple dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Playdate Options'),
          content: Text('Playdate: ${playdate['title'] ?? 'Playdate'}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showCancelConfirmation(Map<String, dynamic> playdate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Playdate?'),
        content: const Text('This will notify the other party that the playdate has been cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Playdate'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelPlaydate(playdate);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Playdate'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRescheduleDialog(Map<String, dynamic> playdate) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final locationController = TextEditingController(text: playdate['location']);
    final descriptionController = TextEditingController(text: playdate['description'] ?? '');

    final currentScheduledAt = DateTime.parse(playdate['scheduled_at']);
    selectedDate = DateTime(currentScheduledAt.year, currentScheduledAt.month, currentScheduledAt.day);
    selectedTime = TimeOfDay.fromDateTime(currentScheduledAt);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reschedule Playdate'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date selection
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(selectedDate != null 
                    ? 'Date: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                    : 'Select Date'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                
                // Time selection
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(selectedTime != null 
                    ? 'Time: ${selectedTime!.format(context)}'
                    : 'Select Time'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Location
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedDate != null && selectedTime != null && locationController.text.isNotEmpty) {
                  final newDateTime = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                  
                  final success = await _reschedulePlaydate(
                    playdate['id'],
                    newDateTime,
                    locationController.text,
                    descriptionController.text.isEmpty ? null : descriptionController.text,
                  );
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Playdate rescheduled successfully! 📅'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadPlaydates();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to reschedule playdate'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                }
              },
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _reschedulePlaydate(String playdateId, DateTime newDateTime, String newLocation, String? newDescription) async {
    try {
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser == null) return false;

      final success = await PlaydateManagementService.reschedulePlaydate(
        playdateId: playdateId,
        updatedByUserId: currentUser.id,
        newScheduledAt: newDateTime,
        newLocation: newLocation,
        newDescription: newDescription,
      );

      return success;
    } catch (e) {
      debugPrint('Error rescheduling playdate: $e');
      return false;
    }
  }

  Future<void> _cancelPlaydate(Map<String, dynamic> playdate) async {
    try {
      // TODO: Implement cancel playdate logic
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playdate cancelled')),
      );
      _loadPlaydates();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling playdate: $e')),
      );
    }
  }
}
