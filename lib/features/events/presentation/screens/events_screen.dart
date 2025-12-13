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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header matching Messages/Profile style
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Events',
                    style: AppTypography.h1().copyWith(fontSize: 32),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tune),
                        onPressed: () {
                          // TODO: Show filter dialog
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          context.push('/create-event');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilterTabs(
              tabs: const ['All', 'This Weekend', 'Nearby', 'Free'],
              selectedTab: _selectedFilter,
              onTabSelected: (tab) {
                setState(() => _selectedFilter = tab);
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: eventsAsync.when(
                data: (events) {
                  // Apply filter logic based on selected tab
                  List<Event> filteredEvents = events;
                  
                  switch (_selectedFilter) {
                    case 'This Weekend':
                      final now = DateTime.now();
                      final saturday = now.add(Duration(days: DateTime.saturday - now.weekday));
                      final weekendStart = DateTime(saturday.year, saturday.month, saturday.day);
                      final weekendEnd = weekendStart.add(const Duration(days: 2));
                      filteredEvents = events.where((e) =>
                        e.startTime.isAfter(weekendStart.subtract(const Duration(days: 1))) &&
                        e.startTime.isBefore(weekendEnd)
                      ).toList();
                      break;
                    case 'Nearby':
                      // For now, show events that have coordinates (would need user location for proper distance calc)
                      filteredEvents = events.where((e) => 
                        e.latitude != null && e.longitude != null
                      ).toList();
                      break;
                    case 'Free':
                      filteredEvents = events.where((e) => e.isFree).toList();
                      break;
                    case 'All':
                    default:
                      filteredEvents = events;
                  } 

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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
