class Dog {
  final String id;
  final String name;
  final String breed;
  final int age;
  final String size;
  final String gender;
  final String bio;
  final List<String> photos;
  final String ownerId;
  final String ownerName;
  final double distanceKm;
  final bool isMatched;

  const Dog({
    required this.id,
    required this.name,
    required this.breed,
    required this.age,
    required this.size,
    required this.gender,
    required this.bio,
    required this.photos,
    required this.ownerId,
    required this.ownerName,
    required this.distanceKm,
    this.isMatched = false,
  });

  Dog copyWith({
    String? id,
    String? name,
    String? breed,
    int? age,
    String? size,
    String? gender,
    String? bio,
    List<String>? photos,
    String? ownerId,
    String? ownerName,
    double? distanceKm,
    bool? isMatched,
  }) => Dog(
    id: id ?? this.id,
    name: name ?? this.name,
    breed: breed ?? this.breed,
    age: age ?? this.age,
    size: size ?? this.size,
    gender: gender ?? this.gender,
    bio: bio ?? this.bio,
    photos: photos ?? this.photos,
    ownerId: ownerId ?? this.ownerId,
    ownerName: ownerName ?? this.ownerName,
    distanceKm: distanceKm ?? this.distanceKm,
    isMatched: isMatched ?? this.isMatched,
  );

  factory Dog.fromJson(Map<String, dynamic> json) {
    return Dog(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      breed: json['breed'] ?? '',
      age: json['age']?.toInt() ?? 0,
      size: json['size'] ?? '',
      gender: json['gender'] ?? '',
      bio: json['bio'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      ownerId: json['owner_id'] ?? '',
      ownerName: json['owner_name'] ?? '',
      distanceKm: json['distance_km']?.toDouble() ?? 0.0,
      isMatched: json['is_matched'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'age': age,
      'size': size,
      'gender': gender,
      'bio': bio,
      'photos': photos,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'distance_km': distanceKm,
      'is_matched': isMatched,
    };
  }
}