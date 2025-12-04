import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlaydateDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> playdate;

  const PlaydateDetailsScreen({super.key, required this.playdate});

  @override
  Widget build(BuildContext context) {
    final scheduledAt = DateTime.parse(playdate['scheduled_at']);
    final formattedDate = DateFormat('EEEE, MMMM d, y').format(scheduledAt);
    final formattedTime = DateFormat('h:mm a').format(scheduledAt);
    final location = playdate['location'] ?? 'Unknown Location';
    final status = playdate['status'] ?? 'pending';
    final organizer = playdate['organizer'] as Map<String, dynamic>?;
    final participant = playdate['participant'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playdate Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Time and Location
            _buildInfoRow(context, Icons.calendar_today, 'Date', formattedDate),
            const SizedBox(height: 16),
            _buildInfoRow(context, Icons.access_time, 'Time', formattedTime),
            const SizedBox(height: 16),
            _buildInfoRow(context, Icons.location_on, 'Location', location),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Participants
            Text(
              'Participants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (organizer != null)
              _buildParticipantRow(context, 'Organizer', organizer),
            const SizedBox(height: 16),
            if (participant != null)
              _buildParticipantRow(context, 'Participant', participant),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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

  Widget _buildParticipantRow(BuildContext context, String role, Map<String, dynamic> user) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
