import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// State representing the current map viewport
class MapViewportState {
  final LatLng center;
  final double zoom;
  final LatLngBounds? bounds;
  final bool isMoving;

  const MapViewportState({
    required this.center,
    required this.zoom,
    this.bounds,
    this.isMoving = false,
  });

  MapViewportState copyWith({
    LatLng? center,
    double? zoom,
    LatLngBounds? bounds,
    bool? isMoving,
  }) {
    return MapViewportState(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      bounds: bounds ?? this.bounds,
      isMoving: isMoving ?? this.isMoving,
    );
  }

  /// Get bounding box coordinates
  BoundingBox? get boundingBox {
    if (bounds == null) return null;
    return BoundingBox(
      south: bounds!.southwest.latitude,
      west: bounds!.southwest.longitude,
      north: bounds!.northeast.latitude,
      east: bounds!.northeast.longitude,
    );
  }
}

/// Bounding box for queries
class BoundingBox {
  final double south;
  final double west;
  final double north;
  final double east;

  const BoundingBox({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  @override
  String toString() => 'BBox(S:$south,W:$west,N:$north,E:$east)';
}

/// Controller for map viewport state
class MapViewportController extends StateNotifier<MapViewportState> {
  GoogleMapController? _mapController;

  MapViewportController()
      : super(MapViewportState(
          center: const LatLng(-31.9505, 115.8605), // Default: Perth
          zoom: 13.0,
        ));

  void attachMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  void updateCamera(LatLng center, double zoom) {
    state = state.copyWith(center: center, zoom: zoom);
  }

  void updateBounds(LatLngBounds bounds) {
    state = state.copyWith(bounds: bounds);
  }

  void setMoving(bool isMoving) {
    state = state.copyWith(isMoving: isMoving);
  }

  /// Move camera to a specific location
  Future<void> moveTo(LatLng location, {double? zoom}) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, zoom ?? state.zoom),
      );
    }
  }

  /// Recenter on user location
  Future<void> recenter(LatLng userLocation) async {
    await moveTo(userLocation, zoom: 14.0);
  }
}

/// Provider for map viewport state
final mapViewportProvider =
    StateNotifierProvider<MapViewportController, MapViewportState>((ref) {
  return MapViewportController();
});
