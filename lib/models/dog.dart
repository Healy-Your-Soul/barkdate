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
}