class Park {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final double distance; // in km
  final List<String> amenities;
  final String? imageUrl;

  const Park({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.distance,
    this.amenities = const [],
    this.imageUrl,
  });
}
