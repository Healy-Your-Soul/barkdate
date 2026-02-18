import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/screens/map_v2/providers/map_filters_provider.dart';

class MapFilterChips extends ConsumerWidget {
  const MapFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(mapFiltersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: filters.category == 'all',
                  onSelected: (_) {
                    ref.read(mapFiltersProvider.notifier).setCategory('all');
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: const Text('Parks'),
                  selected: filters.category == 'park',
                  onSelected: (_) {
                    ref.read(mapFiltersProvider.notifier).setCategory('park');
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: const Text('Cafes'),
                  selected: filters.category == 'cafe',
                  onSelected: (_) {
                    ref.read(mapFiltersProvider.notifier).setCategory('cafe');
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: const Text('Stores'),
                  selected: filters.category == 'store',
                  onSelected: (_) {
                    ref.read(mapFiltersProvider.notifier).setCategory('store');
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Amenities',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Dog Water Bowls'),
              selected: filters.amenities.contains('Dog Water Bowls'),
              onSelected: (_) {
                ref
                    .read(mapFiltersProvider.notifier)
                    .toggleAmenity('Dog Water Bowls');
              },
            ),
            FilterChip(
              label: const Text('Shaded Areas'),
              selected: filters.amenities.contains('Shaded Areas'),
              onSelected: (_) {
                ref
                    .read(mapFiltersProvider.notifier)
                    .toggleAmenity('Shaded Areas');
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Show Events on Map',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: filters.showEvents,
              onChanged: (value) {
                ref.read(mapFiltersProvider.notifier).setShowEvents(value);
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}
