import 'package:flutter/material.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/playdate.dart';
import 'package:barkdate/screens/playdate_recap_screen.dart';

class PlaydatesScreen extends StatefulWidget {
  const PlaydatesScreen({super.key});

  @override
  State<PlaydatesScreen> createState() => _PlaydatesScreenState();
}

class _PlaydatesScreenState extends State<PlaydatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Playdates',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingPlaydates(),
          _buildPastPlaydates(),
        ],
      ),
    );
  }

  Widget _buildUpcomingPlaydates() {
    final upcomingPlaydates = SampleData.upcomingPlaydates
        .where((playdate) => playdate.dateTime.isAfter(DateTime.now()))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingPlaydates.length,
      itemBuilder: (context, index) {
        final playdate = upcomingPlaydates[index];
        return _buildPlaydateCard(context, playdate, isUpcoming: true);
      },
    );
  }

  Widget _buildPastPlaydates() {
    // Create some past playdates for demo
    final pastPlaydates = [
      Playdate(
        id: 'playdate_past_001',
        initiatorUserId: SampleData.currentUserId,
        invitedUserId: 'user_003',
        initiatorDogName: 'Luna',
        invitedDogName: 'Cooper',
        title: 'Forest Frolic',
        location: 'Pine Valley Park',
        dateTime: DateTime.now().subtract(const Duration(days: 5)),
        status: PlaydateStatus.completed,
        imageUrl: 'https://pixabay.com/get/g208d1816b6cb4944f4a367ccaf380d3b441bb87b2385977de3f3cd40dc600e3c6b44612734d7fa721d4755f0c555a0ad008d42641e24efdfbb11c32e4c17e9eb_1280.jpg',
      ),
      Playdate(
        id: 'playdate_past_002',
        initiatorUserId: 'user_005',
        invitedUserId: SampleData.currentUserId,
        initiatorDogName: 'Charlie',
        invitedDogName: 'Luna',
        title: 'Morning Walk',
        location: 'Downtown Park',
        dateTime: DateTime.now().subtract(const Duration(days: 12)),
        status: PlaydateStatus.completed,
        imageUrl: 'https://pixabay.com/get/g2015a824e6d889ca561f4bce4cdba0a9c339fa06b7d81999f12a9f9ccead1edc36cae8745b6575da796b3e853ae364d5feaf001a315562b325770472ae3cf403_1280.jpg',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pastPlaydates.length,
      itemBuilder: (context, index) {
        final playdate = pastPlaydates[index];
        return _buildPlaydateCard(context, playdate, isUpcoming: false);
      },
    );
  }

  Widget _buildPlaydateCard(BuildContext context, Playdate playdate, {required bool isUpcoming}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Image header
          if (playdate.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  playdate.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.park,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        playdate.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    _buildStatusChip(context, playdate.status),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  '${playdate.initiatorDogName} & ${playdate.invitedDogName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        playdate.location,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatPlaydateTime(playdate.dateTime, isUpcoming),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                
                if (isUpcoming && playdate.status == PlaydateStatus.pending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handlePlaydateAction(playdate, PlaydateStatus.declined),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handlePlaydateAction(playdate, PlaydateStatus.accepted),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ] else if (isUpcoming) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.directions),
                      label: const Text('Get Directions'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlaydateRecapScreen(playdate: playdate)),
                        );
                      },
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Write a Recap'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, PlaydateStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case PlaydateStatus.pending:
        backgroundColor = Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2);
        textColor = Theme.of(context).colorScheme.tertiary;
        label = 'Pending';
        break;
      case PlaydateStatus.accepted:
        backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
        textColor = Theme.of(context).colorScheme.primary;
        label = 'Accepted';
        break;
      case PlaydateStatus.completed:
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green.shade700;
        label = 'Completed';
        break;
      case PlaydateStatus.declined:
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red.shade700;
        label = 'Declined';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatPlaydateTime(DateTime dateTime, bool isUpcoming) {
    if (isUpcoming) {
      final now = DateTime.now();
      final difference = dateTime.difference(now);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} days from now';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours from now';
      } else {
        return 'Very soon!';
      }
    } else {
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else {
        return 'Recently';
      }
    }
  }

  void _handlePlaydateAction(Playdate playdate, PlaydateStatus newStatus) {
    setState(() {
      // In a real app, this would update the backend
      // For now, just show a snackbar
    });

    final message = newStatus == PlaydateStatus.accepted
        ? 'Playdate accepted! 🎉'
        : 'Playdate declined';
        
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}