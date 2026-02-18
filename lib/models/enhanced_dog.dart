// Enhanced Dog model with many-to-many ownership support
import 'package:barkdate/models/dog.dart';

class DogOwner {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String ownershipType; // 'owner', 'co-owner', 'caretaker', 'walker'
  final List<String> permissions; // ['view', 'edit', 'playdates', 'share']
  final bool isPrimary;
  final DateTime addedAt;

  const DogOwner({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.ownershipType,
    required this.permissions,
    required this.isPrimary,
    required this.addedAt,
  });

  factory DogOwner.fromJson(Map<String, dynamic> json) {
    return DogOwner(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      avatarUrl: json['avatar_url'],
      ownershipType: json['ownership_type'] ?? 'owner',
      permissions: List<String>.from(json['permissions'] ?? ['view']),
      isPrimary: json['is_primary'] ?? false,
      addedAt:
          DateTime.parse(json['added_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'avatar_url': avatarUrl,
      'ownership_type': ownershipType,
      'permissions': permissions,
      'is_primary': isPrimary,
      'added_at': addedAt.toIso8601String(),
    };
  }
}

class EnhancedDog {
  final String id;
  final String name;
  final String breed;
  final int age;
  final String size;
  final String gender;
  final String bio;
  final String? mainPhotoUrl;
  final List<String> extraPhotoUrls;
  final List<String> temperament;
  final bool vaccinated;
  final bool neutered;
  final int? weightKg;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Many-to-many ownership
  final List<DogOwner> owners;

  // Backward compatibility
  final String primaryOwnerId;
  final String primaryOwnerName;

  const EnhancedDog({
    required this.id,
    required this.name,
    required this.breed,
    required this.age,
    required this.size,
    required this.gender,
    required this.bio,
    this.mainPhotoUrl,
    this.extraPhotoUrls = const [],
    this.temperament = const [],
    this.vaccinated = false,
    this.neutered = false,
    this.weightKg,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.owners = const [],
    required this.primaryOwnerId,
    required this.primaryOwnerName,
  });

  // Primary owner (for backward compatibility)
  DogOwner? get primaryOwner {
    try {
      return owners.firstWhere((o) => o.isPrimary);
    } catch (_) {
      return owners.isNotEmpty ? owners.first : null;
    }
  }

  // Ownership display for UI
  String get ownershipDisplay {
    if (owners.isEmpty) return 'No owners';
    if (owners.length == 1) return owners.first.userName;
    return '${owners.first.userName} +${owners.length - 1} others';
  }

  // Permission checking
  bool canPerform(String action, [String? userId]) {
    if (userId == null) return false;
    final userOwnership = owners.where((o) => o.userId == userId).firstOrNull;
    return userOwnership?.permissions.contains(action) ?? false;
  }

  // Get all photos (main + extra)
  List<String> get allPhotos {
    final photos = <String>[];
    if (mainPhotoUrl != null && mainPhotoUrl!.isNotEmpty) {
      photos.add(mainPhotoUrl!);
    }
    photos.addAll(extraPhotoUrls);
    return photos;
  }

  factory EnhancedDog.fromDatabase(Map<String, dynamic> json) {
    // Parse owners from the database query
    final ownersList = <DogOwner>[];
    if (json['owners'] != null) {
      final ownersData = json['owners'] as List;
      ownersList.addAll(ownersData.map((o) => DogOwner.fromJson(o)));
    }

    // Find primary owner for backward compatibility
    final primaryOwner = ownersList.isNotEmpty
        ? ownersList.firstWhere((o) => o.isPrimary,
            orElse: () => ownersList.first)
        : null;

    return EnhancedDog(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      breed: json['breed'] ?? '',
      age: json['age']?.toInt() ?? 0,
      size: json['size'] ?? '',
      gender: json['gender'] ?? '',
      bio: json['bio'] ?? '',
      mainPhotoUrl: json['main_photo_url'],
      extraPhotoUrls: List<String>.from(json['extra_photo_urls'] ?? []),
      temperament: List<String>.from(json['temperament'] ?? []),
      vaccinated: json['vaccinated'] ?? false,
      neutered: json['neutered'] ?? false,
      weightKg: json['weight_kg']?.toInt(),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
      owners: ownersList,
      primaryOwnerId: primaryOwner?.userId ?? '',
      primaryOwnerName: primaryOwner?.userName ?? '',
    );
  }

  // Convert back to old Dog model for backward compatibility
  Dog? toOldModel() {
    if (primaryOwnerId.isEmpty) return null;

    return Dog(
      id: id,
      name: name,
      breed: breed,
      age: age,
      size: size,
      gender: gender,
      bio: bio,
      photos: allPhotos,
      ownerId: primaryOwnerId,
      ownerName: primaryOwnerName,
      distanceKm: 0.0, // Default value
      isMatched: false, // Default value
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
      'main_photo_url': mainPhotoUrl,
      'extra_photo_urls': extraPhotoUrls,
      'temperament': temperament,
      'vaccinated': vaccinated,
      'neutered': neutered,
      'weight_kg': weightKg,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'owners': owners.map((o) => o.toJson()).toList(),
    };
  }
}
