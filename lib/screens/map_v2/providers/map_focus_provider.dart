import 'package:flutter_riverpod/legacy.dart';

class MapFocusRequest {
  final double latitude;
  final double longitude;
  final String? parkId;
  final String? parkName;

  const MapFocusRequest({
    required this.latitude,
    required this.longitude,
    this.parkId,
    this.parkName,
  });
}

final mapFocusRequestProvider = StateProvider<MapFocusRequest?>((ref) => null);
