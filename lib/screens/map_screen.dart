import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barkdate/services/park_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _myLocation;
  bool _loading = true;
  bool _isCheckedIn = false;
  String? _activeCheckinId;
  List<ParkLocation> _parkLocations = [];
  final Set<Marker> _markers = {};
  ParkLocation? _nearest;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Get location permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      // Fetch current location (best effort)
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
      } catch (_) {
        // fallback to last known or a default center
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos != null) _myLocation = LatLng(pos.latitude, pos.longitude);

      // Load parks from Supabase (seeded)
      final parks = await ParkService.getParksNearby(
        latitude: _myLocation?.latitude,
        longitude: _myLocation?.longitude,
      );
      _parkLocations = parks
          .map((p) => ParkLocation(
                id: p['id'] as String,
                name: p['name'] as String,
                address: (p['address'] as String?) ?? '',
                latitude: (p['latitude'] as num).toDouble(),
                longitude: (p['longitude'] as num).toDouble(),
              ))
          .toList();

      // Compute nearest
      _nearest = _computeNearest(_myLocation, _parkLocations);

      // Build markers
      _markers
        ..clear()
        ..addAll(_parkLocations.map((park) => Marker(
              markerId: MarkerId(park.id),
              position: LatLng(park.latitude, park.longitude),
              infoWindow: InfoWindow(title: park.name, snippet: park.address),
              onTap: () => _showParkDetails(park),
            )));

      // Check if user is already checked in
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        final active = await CheckinService.getActiveCheckin(user.id);
        if (active != null) {
          _isCheckedIn = true;
          _activeCheckinId = active['id'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Map init failed: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ParkLocation? _computeNearest(LatLng? me, List<ParkLocation> parks) {
    if (me == null || parks.isEmpty) return parks.isEmpty ? null : parks.first;
    double best = double.infinity;
    ParkLocation? nearest;
    for (final p in parks) {
      final d = Geolocator.distanceBetween(me.latitude, me.longitude, p.latitude, p.longitude);
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    return nearest;
  }

  Future<void> _centerOnMyLocation() async {
    if (_myLocation == null || _mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _myLocation!, zoom: 14),
    ));
  }

  Future<void> _toggleCheckIn() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to check in')),
      );
      return;
    }

    if (_isCheckedIn) {
      if (_activeCheckinId != null) {
        await CheckinService.checkOut(_activeCheckinId!);
        if (!mounted) return;
        setState(() {
          _isCheckedIn = false;
          _activeCheckinId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Checked out! See you next time 👋'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    final target = _nearest ?? (_parkLocations.isNotEmpty ? _parkLocations.first : null);
    if (target == null) return;

    // Get a dog for current user (first active)
    final dog = await SupabaseConfig.client
        .from('dogs')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    if (dog == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a dog profile first')),
      );
      return;
    }

    final res = await CheckinService.checkIn(
      userId: user.id,
      dogId: dog['id'] as String,
      parkId: target.id,
      latitude: _myLocation?.latitude,
      longitude: _myLocation?.longitude,
    );

    if (!mounted) return;
    setState(() {
      _isCheckedIn = true;
      _activeCheckinId = res['id'] as String?;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Checked in at ${target.name}! 🏞️'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dog Parks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnMyLocation,
            tooltip: 'My location',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Map Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _loading = true;
                          });
                          _initialize();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
              children: [
                SizedBox(
                  height: 300,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _myLocation ?? const LatLng(40.7829, -73.9654),
                      zoom: 12,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    markers: _markers,
                    onMapCreated: (c) => _mapController = c,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _toggleCheckIn,
                      icon: Icon(_isCheckedIn ? Icons.check_circle : Icons.location_on),
                      label: Text(_isCheckedIn
                          ? 'Checked In'
                          : 'Check In at ${_nearest?.name ?? 'Nearest Park'}'),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _parkLocations.length,
                    itemBuilder: (context, index) {
                      final park = _parkLocations[index];
                      return ListTile(
                        leading: const Icon(Icons.park),
                        title: Text(park.name),
                        subtitle: Text(park.address),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showParkDetails(park),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showParkDetails(ParkLocation park) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.park),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(park.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(park.address, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.directions),
                    onPressed: () {
                      final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${park.latitude},${park.longitude}');
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: CheckinService.streamActiveCheckinsForPark(park.id),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Row(
                    children: [
                      const Icon(Icons.pets),
                      const SizedBox(width: 8),
                      Text('$count dogs currently active'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class ParkLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  ParkLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}