import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/feed/presentation/providers/feed_provider.dart';
import 'package:barkdate/design_system/app_typography.dart';

class FeedFilterSheet extends ConsumerStatefulWidget {
  const FeedFilterSheet({super.key});

  @override
  ConsumerState<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends ConsumerState<FeedFilterSheet> {
  late double _maxDistance;
  late RangeValues _ageRange;
  late List<String> _selectedSizes;
  late List<String> _selectedGenders;

  final List<String> _allSizes = ['Small', 'Medium', 'Large'];
  final List<String> _allGenders = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    final currentFilter = ref.read(feedFilterProvider);
    _maxDistance = currentFilter.maxDistance;
    _ageRange = RangeValues(currentFilter.minAge.toDouble(), currentFilter.maxAge.toDouble());
    _selectedSizes = List.from(currentFilter.sizes);
    _selectedGenders = List.from(currentFilter.genders);
  }

  void _applyFilters() {
    ref.read(feedFilterProvider.notifier).state = FeedFilter(
      maxDistance: _maxDistance,
      minAge: _ageRange.start.toInt(),
      maxAge: _ageRange.end.toInt(),
      sizes: _selectedSizes,
      genders: _selectedGenders,
    );
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _maxDistance = 50.0;
      _ageRange = const RangeValues(0, 20);
      _selectedSizes = [];
      _selectedGenders = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF4CAF50);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter Dogs', style: AppTypography.h2()),
              TextButton(
                onPressed: _resetFilters,
                child: Text(
                  'Reset',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Distance Slider
          Text('Maximum Distance', style: AppTypography.labelLarge()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxDistance,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: greenColor,
                  onChanged: (value) => setState(() => _maxDistance = value),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${_maxDistance.toInt()} km',
                  style: AppTypography.bodyMedium().copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Age Range
          Text('Age Range', style: AppTypography.labelLarge()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RangeSlider(
                  values: _ageRange,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: greenColor,
                  labels: RangeLabels(
                    '${_ageRange.start.toInt()}',
                    '${_ageRange.end.toInt()}',
                  ),
                  onChanged: (values) => setState(() => _ageRange = values),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${_ageRange.start.toInt()}-${_ageRange.end.toInt()} yrs',
                  style: AppTypography.bodySmall().copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Size Filter
          Text('Size', style: AppTypography.labelLarge()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allSizes.map((size) {
              final isSelected = _selectedSizes.contains(size);
              return FilterChip(
                label: Text(size),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSizes.add(size);
                    } else {
                      _selectedSizes.remove(size);
                    }
                  });
                },
                selectedColor: greenColor.withOpacity(0.2),
                checkmarkColor: greenColor,
                labelStyle: TextStyle(
                  color: isSelected ? greenColor : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Gender Filter
          Text('Gender', style: AppTypography.labelLarge()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allGenders.map((gender) {
              final isSelected = _selectedGenders.contains(gender);
              return FilterChip(
                label: Text(gender),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGenders.add(gender);
                    } else {
                      _selectedGenders.remove(gender);
                    }
                  });
                },
                selectedColor: greenColor.withOpacity(0.2),
                checkmarkColor: greenColor,
                labelStyle: TextStyle(
                  color: isSelected ? greenColor : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: greenColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Show the filter bottom sheet
void showFeedFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const FeedFilterSheet(),
  );
}
