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
  final String? ownerAvatarUrl;
  final double distanceKm;
  final bool isMatched;
  final bool? isFriend; // Tracks if this dog is in user's pack
  // Sprint 8: richer friendship state for card rendering.
  // null = no relationship, 'pending_sent' = I sent, 'pending_received' = they
  // sent, 'accepted' = in pack.
  final String? friendshipStatus;
  final String? friendshipId; // DB row id — needed to accept/decline inline
  final String? playdateStatus; // 'pending', 'confirmed', or null
  final String? currentPlaydateId;

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
    this.ownerAvatarUrl,
    required this.distanceKm,
    this.isMatched = false,
    this.isFriend,
    this.friendshipStatus,
    this.friendshipId,
    this.playdateStatus,
    this.currentPlaydateId,
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
    String? ownerAvatarUrl,
    double? distanceKm,
    bool? isMatched,
    bool? isFriend,
    String? friendshipStatus,
    String? friendshipId,
    String? playdateStatus,
    String? currentPlaydateId,
  }) =>
      Dog(
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
        ownerAvatarUrl: ownerAvatarUrl ?? this.ownerAvatarUrl,
        distanceKm: distanceKm ?? this.distanceKm,
        isMatched: isMatched ?? this.isMatched,
        isFriend: isFriend ?? this.isFriend,
        friendshipStatus: friendshipStatus ?? this.friendshipStatus,
        friendshipId: friendshipId ?? this.friendshipId,
        playdateStatus: playdateStatus ?? this.playdateStatus,
        currentPlaydateId: currentPlaydateId ?? this.currentPlaydateId,
      );

  factory Dog.fromJson(Map<String, dynamic> json) {
    // Handle photos mapping from various possible backend formats
    List<String> photoList = [];
    if (json['photos'] != null) {
      photoList = List<String>.from(json['photos']);
    } else if (json['photo_urls'] != null) {
      photoList = List<String>.from(json['photo_urls']);
    } else if (json['main_photo_url'] != null) {
      photoList.add(json['main_photo_url']);
      if (json['extra_photo_urls'] != null) {
        photoList.addAll(List<String>.from(json['extra_photo_urls']));
      }
    }

    // Handle owner data from various formats (RPC vs direct query)
    final ownerData = json['owner'] ?? json['users'];
    final ownerId =
        json['owner_id'] ?? json['user_id'] ?? ownerData?['id'] ?? '';
    final ownerName = json['owner_name'] ?? ownerData?['name'] ?? 'Unknown';
    final ownerAvatar = json['owner_avatar_url'] ?? ownerData?['avatar_url'];

    return Dog(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      breed: json['breed'] ?? '',
      age: json['age']?.toInt() ?? 0,
      size: json['size'] ?? '',
      gender: json['gender'] ?? '',
      bio: json['bio'] ?? '',
      photos: photoList,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerAvatarUrl: ownerAvatar,
      distanceKm: json['distance_km']?.toDouble() ?? 0.0,
      isMatched: json['is_matched'] ?? false,
      isFriend: json['is_friend'],
      friendshipStatus: json['friendship_status'] as String?,
      friendshipId: json['friendship_id'] as String?,
      playdateStatus: json['playdate_status'] as String?,
      currentPlaydateId: json['current_playdate_id'] as String?,
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
      'owner_avatar_url': ownerAvatarUrl,
      'distance_km': distanceKm,
      'is_matched': isMatched,
      'is_friend': isFriend,
      'friendship_status': friendshipStatus,
      'friendship_id': friendshipId,
      'playdate_status': playdateStatus,
      'current_playdate_id': currentPlaydateId,
    };
  }
}
