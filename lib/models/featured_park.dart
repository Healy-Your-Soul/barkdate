class FeaturedPark {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final List<String> amenities;
  final String? address;
  final double? rating;
  final List<String>? photoUrls;
  final bool isActive;
  final DateTime? createdAt;

  FeaturedPark({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.amenities,
    this.address,
    this.rating,
    this.photoUrls,
    this.isActive = true,
    this.createdAt,
  });

  factory FeaturedPark.fromJson(Map<String, dynamic> json) {
    return FeaturedPark(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      amenities: List<String>.from(json['amenities'] ?? []),
      address: json['address'],
      rating: json['rating']?.toDouble(),
      photoUrls: json['photo_urls'] != null ? List<String>.from(json['photo_urls']) : null,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'amenities': amenities,
      'address': address,
      'rating': rating,
      'photo_urls': photoUrls,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
