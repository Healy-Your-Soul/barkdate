import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:async';

class SimpleMapScreen extends StatefulWidget {
  const SimpleMapScreen({super.key});

  @override
  State<SimpleMapScreen> createState() => _SimpleMapScreenState();
}

class _SimpleMapScreenState extends State<SimpleMapScreen> {
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng? _currentLocation;
  bool _loading = true;
  bool _isCheckedIn = false;
  final Set<Marker> _markers = {};

  final List<ParkLocation> _parkLocations = [
    ParkLocation(
      id: '1',
      name: 'Central Park',
      address: '123 Park Avenue',
      activeDogs: 8,
      distance: 0.5,
      latitude: 40.7829,
      longitude: -73.9654,
    ),
    ParkLocation(
      id: '2',
      name: 'Riverside Dog Park',
      address: '456 River Street',
      activeDogs: 12,
      distance: 1.2,
      latitude: 40.7489,
      longitude: -73.9857,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    LocationData locationData = await _location.getLocation();
    if (locationData.latitude != null && locationData.longitude != null) {
      setState(() {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        _loading = false;
      });
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Add current location marker
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Add park markers
    for (final park in _parkLocations) {
      _markers.add(
        Marker(
          markerId: MarkerId(park.id),
          position: LatLng(park.latitude, park.longitude),
          infoWindow: InfoWindow(
            title: park.name,
            snippet: '${park.activeDogs} dogs • ${park.distance}km away',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showParkDetails(park),
        ),
      );
    }
  }

  void _showParkDetails(ParkLocation park) {
    showBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              park.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${park.activeDogs} dogs active • ${park.distance}km away'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _toggleCheckIn();
              },
              child: const Text('Check In Here'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCheckIn() {
    setState(() {
      _isCheckedIn = !_isCheckedIn;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_isCheckedIn ? 'Checked in successfully!' : 'Checked out'),
        backgroundColor: _isCheckedIn ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dog Parks'),
        actions: [
          // Admin button
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              // Navigate to admin screen when it's ready
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Admin features coming soon!')),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _currentLocation ?? const LatLng(37.7749, -122.4194),
                zoom: 14.0,
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                if (_currentLocation != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
                  );
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleCheckIn,
        backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
        icon: Icon(_isCheckedIn ? Icons.exit_to_app : Icons.location_on),
        label: Text(_isCheckedIn ? 'Check Out' : 'Check In'),
      ),
    );
  }
}

class ParkLocation {
  final String id;
  final String name;
  final String address;
  final int activeDogs;
  final double distance;
  final double latitude;
  final double longitude;

  ParkLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.activeDogs,
    required this.distance,
    required this.latitude,
    required this.longitude,
  });
}
