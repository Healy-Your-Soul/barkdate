import 'package:flutter/material.dart';

class FilterSheet extends StatefulWidget {
  final Function(FilterOptions) onApplyFilters;
  final FilterOptions? currentFilters;

  const FilterSheet({
    super.key,
    required this.onApplyFilters,
    this.currentFilters,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late FilterOptions _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters ?? FilterOptions();
  }

  void _resetFilters() {
    setState(() {
      _filters = FilterOptions();
    });
  }

  void _applyFilters() {
    widget.onApplyFilters(_filters);
    Navigator.pop(context);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filters.breeds.isNotEmpty) count++;
    if (_filters.sizes.isNotEmpty) count++;
    if (_filters.genders.isNotEmpty) count++;
    if (_filters.energyLevels.isNotEmpty) count++;
    if (_filters.minAge > 0 || _filters.maxAge < 20) count++;
    if (_filters.maxDistance < 50) count++;
    if (_filters.availableForPlaydates) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar and header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (_activeFilterCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _resetFilters,
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Filter content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance
                  _buildSectionHeader('Distance'),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Maximum distance',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${_filters.maxDistance.round()} km',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _filters.maxDistance,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        onChanged: (value) {
                          setState(() => _filters.maxDistance = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Age Range
                  _buildSectionHeader('Age'),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Age range',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${_filters.minAge} - ${_filters.maxAge} years',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: RangeValues(_filters.minAge.toDouble(), _filters.maxAge.toDouble()),
                        min: 0,
                        max: 20,
                        divisions: 20,
                        onChanged: (values) {
                          setState(() {
                            _filters.minAge = values.start.round();
                            _filters.maxAge = values.end.round();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Size
                  _buildSectionHeader('Size'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['Small', 'Medium', 'Large'].map((size) {
                      final isSelected = _filters.sizes.contains(size);
                      return FilterChip(
                        label: Text(size),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _filters.sizes.add(size);
                            } else {
                              _filters.sizes.remove(size);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Gender
                  _buildSectionHeader('Gender'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['Male', 'Female'].map((gender) {
                      final isSelected = _filters.genders.contains(gender);
                      return FilterChip(
                        label: Text(gender),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _filters.genders.add(gender);
                            } else {
                              _filters.genders.remove(gender);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Energy Level
                  _buildSectionHeader('Energy Level'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['Low', 'Medium', 'High'].map((energy) {
                      final isSelected = _filters.energyLevels.contains(energy);
                      return FilterChip(
                        label: Text(energy),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _filters.energyLevels.add(energy);
                            } else {
                              _filters.energyLevels.remove(energy);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Breed
                  _buildSectionHeader('Breed'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_filters.breeds.isEmpty)
                          Text(
                            'Any breed',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _filters.breeds.map((breed) {
                              return Chip(
                                label: Text(breed),
                                onDeleted: () {
                                  setState(() => _filters.breeds.remove(breed));
                                },
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            _showBreedSelector();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add breed'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Availability
                  _buildSectionHeader('Availability'),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Available for playdates'),
                    subtitle: const Text('Only show dogs available for meetups'),
                    value: _filters.availableForPlaydates,
                    onChanged: (value) {
                      setState(() => _filters.availableForPlaydates = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          
          // Apply button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Apply Filters${_activeFilterCount > 0 ? ' ($_activeFilterCount)' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showBreedSelector() {
    final popularBreeds = [
      'Golden Retriever', 'Labrador', 'German Shepherd', 'Bulldog', 'Poodle',
      'Beagle', 'Rottweiler', 'Yorkshire Terrier', 'Dachshund', 'Siberian Husky',
      'Boston Terrier', 'Pomeranian', 'Australian Shepherd', 'Shih Tzu', 'Boxer',
      'Border Collie', 'Chihuahua', 'French Bulldog', 'Cocker Spaniel', 'Pit Bull',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Select Breeds',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: ListView.builder(
                itemCount: popularBreeds.length,
                itemBuilder: (context, index) {
                  final breed = popularBreeds[index];
                  final isSelected = _filters.breeds.contains(breed);
                  
                  return CheckboxListTile(
                    title: Text(breed),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _filters.breeds.add(breed);
                        } else {
                          _filters.breeds.remove(breed);
                        }
                      });
                      Navigator.pop(context);
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterOptions {
  double maxDistance;
  int minAge;
  int maxAge;
  Set<String> sizes;
  Set<String> genders;
  Set<String> breeds;
  Set<String> energyLevels;
  bool availableForPlaydates;

  FilterOptions({
    this.maxDistance = 25.0,
    this.minAge = 0,
    this.maxAge = 20,
    Set<String>? sizes,
    Set<String>? genders,
    Set<String>? breeds,
    Set<String>? energyLevels,
    this.availableForPlaydates = false,
  })  : sizes = sizes ?? <String>{},
        genders = genders ?? <String>{},
        breeds = breeds ?? <String>{},
        energyLevels = energyLevels ?? <String>{};

  FilterOptions copyWith({
    double? maxDistance,
    int? minAge,
    int? maxAge,
    Set<String>? sizes,
    Set<String>? genders,
    Set<String>? breeds,
    Set<String>? energyLevels,
    bool? availableForPlaydates,
  }) {
    return FilterOptions(
      maxDistance: maxDistance ?? this.maxDistance,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      sizes: sizes ?? Set.from(this.sizes),
      genders: genders ?? Set.from(this.genders),
      breeds: breeds ?? Set.from(this.breeds),
      energyLevels: energyLevels ?? Set.from(this.energyLevels),
      availableForPlaydates: availableForPlaydates ?? this.availableForPlaydates,
    );
  }
}
