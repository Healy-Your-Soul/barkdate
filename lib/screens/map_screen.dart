import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isCheckedIn = false;
  
  final List<ParkLocation> _parkLocations = [
    ParkLocation(
      name: 'Central Park',
      address: '123 Park Avenue',
      activeDogs: 8,
      distance: 0.5,
    ),
    ParkLocation(
      name: 'Riverside Dog Park',
      address: '456 River Street',
      activeDogs: 12,
      distance: 1.2,
    ),
    ParkLocation(
      name: 'Sunset Beach Park',
      address: '789 Beach Road',
      activeDogs: 5,
      distance: 2.1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dog Parks',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.my_location,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Map placeholder (simplified)
          Container(
            height: 300,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Interactive Map',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Showing nearby dog parks',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Map pins
                Positioned(
                  top: 50,
                  left: 80,
                  child: _buildMapPin(context, _parkLocations[0]),
                ),
                Positioned(
                  top: 120,
                  right: 60,
                  child: _buildMapPin(context, _parkLocations[1]),
                ),
                Positioned(
                  bottom: 80,
                  left: 60,
                  child: _buildMapPin(context, _parkLocations[2]),
                ),
              ],
            ),
          ),
          
          // Check-in button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _toggleCheckIn,
              icon: Icon(
                _isCheckedIn ? Icons.check_circle : Icons.location_on,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                _isCheckedIn ? 'Checked In at Central Park' : 'Check In at Current Location',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCheckedIn 
                  ? Theme.of(context).colorScheme.tertiary
                  : Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Park locations list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _parkLocations.length,
              itemBuilder: (context, index) {
                final park = _parkLocations[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.park,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      park.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          park.address,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.pets,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${park.activeDogs} dogs active',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${park.distance.toStringAsFixed(1)} miles',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onTap: () => _showParkDetails(park),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPin(BuildContext context, ParkLocation park) {
    return GestureDetector(
      onTap: () => _showParkDetails(park),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimary,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.pets,
          size: 16,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  void _toggleCheckIn() {
    setState(() => _isCheckedIn = !_isCheckedIn);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isCheckedIn 
            ? 'Checked in! Other dog owners can see you\'re here 🏞️'
            : 'Checked out! See you next time 👋',
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showParkDetails(ParkLocation park) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              park.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              park.address,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.pets,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${park.activeDogs} dogs currently active',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to this park
                },
                child: const Text('Get Directions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParkLocation {
  final String name;
  final String address;
  final int activeDogs;
  final double distance;

  ParkLocation({
    required this.name,
    required this.address,
    required this.activeDogs,
    required this.distance,
  });
}