import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';
import 'package:barkdate/features/playdates/presentation/screens/playdate_details_screen.dart';
import 'package:intl/intl.dart';
import 'package:barkdate/core/presentation/widgets/cute_empty_state.dart';
import 'package:barkdate/design_system/app_typography.dart';

import 'package:barkdate/core/presentation/widgets/filter_tabs.dart';

class PlaydatesScreen extends ConsumerStatefulWidget {
  const PlaydatesScreen({super.key});

  @override
  ConsumerState<PlaydatesScreen> createState() => _PlaydatesScreenState();
}

class _PlaydatesScreenState extends ConsumerState<PlaydatesScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final playdatesAsync = ref.watch(userPlaydatesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Playdates',
          style: AppTypography.h1().copyWith(fontSize: 28),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              context.push('/create-playdate');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          FilterTabs(
            tabs: const ['All', 'Upcoming', 'Pending', 'Past'],
            selectedTab: _selectedFilter,
            onTabSelected: (tab) {
              setState(() => _selectedFilter = tab);
            },
          ),
          Expanded(
            child: playdatesAsync.when(
              data: (playdates) {
                // Filter logic
                final filteredPlaydates = playdates.where((playdate) {
                  if (_selectedFilter == 'All') return true;
                  final status = (playdate['status'] as String?)?.toLowerCase() ?? 'pending';
                  if (_selectedFilter == 'Pending') return status == 'pending';
                  if (_selectedFilter == 'Upcoming') return status == 'confirmed'; // Assuming upcoming = confirmed
                  // Add more logic as needed
                  return true;
                }).toList();

                if (filteredPlaydates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CuteEmptyState(
                        icon: Icons.calendar_today_outlined,
                        title: 'No playdates found',
                        message: 'Try changing your filter or schedule a new one!',
                        actionLabel: 'Schedule a Playdate',
                        onAction: () {
                          context.push('/create-playdate');
                        },
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredPlaydates.length,
                  separatorBuilder: (context, index) => const Divider(height: 32, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final playdate = filteredPlaydates[index];
                    return _buildPlaydateItem(context, playdate);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaydateItem(BuildContext context, Map<String, dynamic> playdate) {
    final scheduledAt = DateTime.parse(playdate['scheduled_at']);
    final formattedDate = DateFormat('MMM d').format(scheduledAt);
    final formattedTime = DateFormat('h:mm a').format(scheduledAt);
    final location = playdate['location'] ?? 'Unknown Location';
    final status = playdate['status'] ?? 'pending';

    return InkWell(
      onTap: () {
        context.push('/playdate-details', extra: playdate);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Box
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  formattedDate.split(' ')[0], // Month
                  style: AppTypography.bodySmall().copyWith(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                ),
                Text(
                  formattedDate.split(' ')[1], // Day
                  style: AppTypography.h3().copyWith(fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: AppTypography.h3().copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: AppTypography.bodyMedium().copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
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
}
