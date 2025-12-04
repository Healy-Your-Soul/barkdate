import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/features/events/presentation/providers/event_provider.dart';
import 'package:barkdate/features/events/presentation/screens/event_details_screen.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/core/presentation/widgets/cute_empty_state.dart';
import 'package:barkdate/design_system/app_typography.dart';

import 'package:barkdate/core/presentation/widgets/filter_tabs.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(nearbyEventsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Events',
          style: AppTypography.h1().copyWith(fontSize: 28),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black), // Filter icon
            onPressed: () {
              // TODO: Show filter dialog
            },
          ),
        ],
      ),
      body: Column(
        children: [
          FilterTabs(
            tabs: const ['All', 'This Weekend', 'Nearby', 'Free'],
            selectedTab: _selectedFilter,
            onTabSelected: (tab) {
              setState(() => _selectedFilter = tab);
            },
          ),
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                // Filter logic (placeholder for now)
                final filteredEvents = events; 

                if (filteredEvents.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CuteEmptyState(
                        icon: Icons.event_busy,
                        title: 'No upcoming events',
                        message: 'There are no events happening nearby right now. Check back later or adjust your filters.',
                        actionLabel: 'Adjust Filters',
                        onAction: () {
                          // TODO: Show filter dialog
                        },
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return EventCard(event: event);
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
}

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/event-details', extra: event);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
                image: const DecorationImage(
                  image: NetworkImage('https://via.placeholder.com/400x200'), // Placeholder
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border, size: 20),
                    ),
                  ),
                  if (event.categoryIcon.isNotEmpty)
                    Center(
                      child: Text(
                        event.categoryIcon,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  event.title,
                  style: AppTypography.h3().copyWith(fontSize: 18),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.black),
                    const SizedBox(width: 4),
                    Text('4.8', style: AppTypography.bodySmall().copyWith(fontWeight: FontWeight.bold)),
                    Text(' (24)', style: AppTypography.bodySmall().copyWith(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Details
            Text(
              '${event.formattedDate} · ${event.category}',
              style: AppTypography.bodyMedium().copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Location details unavailable', // TODO: Fetch place name
              style: AppTypography.bodyMedium().copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            
            // Price/Action
            RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium().copyWith(color: Colors.black),
                children: [
                  TextSpan(
                    text: 'Free', 
                    style: AppTypography.h3().copyWith(fontSize: 16),
                  ),
                  const TextSpan(text: ' entry'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
