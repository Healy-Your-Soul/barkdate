import 'package:barkdate/supabase/supabase_config.dart';

enum DogAccessLevel { view, edit, manage }
enum DogShareMethod { link, qr, whatsapp }

class DogShareResult {
  final String shareCode;
  final String shareUrl;
  final String qrData;
  
  DogShareResult({required this.shareCode, required this.shareUrl, required this.qrData});
}

class DogShareAcceptResult {
  final bool success;
  final String message;
  final String? dogId;
  final DogAccessLevel? accessLevel;
  
  DogShareAcceptResult({
    required this.success,
    required this.message,
    this.dogId,
    this.accessLevel,
  });
}

class DogShare {
  final String id;
  final String dogId;
  final String ownerId;
  final String? sharedWithUserId;
  final String shareCode;
  final DogAccessLevel accessLevel;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final String? sharedWithUserName;
  final String? sharedWithUserAvatar;

  DogShare({
    required this.id,
    required this.dogId,
    required this.ownerId,
    this.sharedWithUserId,
    required this.shareCode,
    required this.accessLevel,
    this.expiresAt,
    this.acceptedAt,
    this.revokedAt,
    this.sharedWithUserName,
    this.sharedWithUserAvatar,
  });

  factory DogShare.fromJson(Map<String, dynamic> json) {
    return DogShare(
      id: json['id'],
      dogId: json['dog_id'],
      ownerId: json['owner_id'],
      sharedWithUserId: json['shared_with_user_id'],
      shareCode: json['share_code'],
      accessLevel: DogAccessLevel.values.byName(json['access_level']),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      revokedAt: json['revoked_at'] != null ? DateTime.parse(json['revoked_at']) : null,
      sharedWithUserName: json['users']?['name'],
      sharedWithUserAvatar: json['users']?['avatar_url'],
    );
  }
}

class SharedDog {
  final String dogId;
  final String dogName;
  final String dogBreed;
  final String? dogPhotoUrl;
  final DogAccessLevel accessLevel;
  final String ownerName;
  final DateTime? sharedAt;

  SharedDog({
    required this.dogId,
    required this.dogName,
    required this.dogBreed,
    this.dogPhotoUrl,
    required this.accessLevel,
    required this.ownerName,
    this.sharedAt,
  });

  factory SharedDog.fromJson(Map<String, dynamic> json) {
    return SharedDog(
      dogId: json['dog_id'],
      dogName: json['dog_name'],
      dogBreed: json['dog_breed'],
      dogPhotoUrl: json['dog_photo_url'],
      accessLevel: DogAccessLevel.values.byName(json['access_level']),
      ownerName: json['owner_name'],
      sharedAt: json['shared_at'] != null ? DateTime.parse(json['shared_at']) : null,
    );
  }
}

class DogSharingService {
  /// Create a new dog share
  static Future<DogShareResult> createShare({
    required String dogId,
    required String ownerId,
    required DogAccessLevel accessLevel,
    String? pinCode,
    DateTime? expiresAt,
    DogShareMethod sharedVia = DogShareMethod.link,
    String? notes,
  }) async {
    final response = await SupabaseConfig.client.rpc('create_dog_share', params: {
      'p_dog_id': dogId,
      'p_owner_id': ownerId,
      'p_access_level': accessLevel.name,
      'p_pin_code': pinCode,
      'p_expires_at': expiresAt?.toIso8601String(),
      'p_shared_via': sharedVia.name,
      'p_notes': notes,
    }).single();
    
    return DogShareResult(
      shareCode: response['share_code'],
      shareUrl: response['share_url'],
      qrData: response['qr_data'],
    );
  }
  
  /// Accept a dog share
  static Future<DogShareAcceptResult> acceptShare({
    required String shareCode,
    required String userId,
    String? pinCode,
  }) async {
    final response = await SupabaseConfig.client.rpc('accept_dog_share', params: {
      'p_share_code': shareCode,
      'p_user_id': userId,
      'p_pin_code': pinCode,
    }).single();
    
    return DogShareAcceptResult(
      success: response['success'],
      message: response['message'],
      dogId: response['dog_id'],
      accessLevel: response['access_level'] != null 
        ? DogAccessLevel.values.byName(response['access_level'])
        : null,
    );
  }
  
  /// Get all shares for a dog (owner view)
  static Future<List<DogShare>> getDogShares(String dogId) async {
    final response = await SupabaseConfig.client
      .from('dog_shares')
      .select('*, users!shared_with_user_id(name, avatar_url)')
      .eq('dog_id', dogId)
      .filter('revoked_at', 'is', null)
      .order('created_at', ascending: false);
    
    return (response as List).map((e) => DogShare.fromJson(e)).toList();
  }
  
  /// Get all dogs shared with user
  static Future<List<SharedDog>> getSharedDogs(String userId) async {
    final response = await SupabaseConfig.client
      .rpc('get_shared_dogs', params: {'p_user_id': userId});
    
    return (response as List).map((e) => SharedDog.fromJson(e)).toList();
  }
  
  /// Revoke a share
  static Future<bool> revokeShare({
    required String shareId,
    required String ownerId,
  }) async {
    return await SupabaseConfig.client.rpc('revoke_dog_share', params: {
      'p_share_id': shareId,
      'p_owner_id': ownerId,
    });
  }
}