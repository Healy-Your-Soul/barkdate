class Event {
  final String id;
  final String title;
  final String description;
  final String organizerId;
  final String organizerType; // 'user' or 'professional'
  final String organizerName;
  final String organizerAvatarUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final double? latitude;
  final double? longitude;
  final String category; // 'birthday', 'training', 'social', 'professional'
  final int maxParticipants;
  final int currentParticipants;
  final List<String> targetAgeGroups; // 'puppy', 'adult', 'senior'
  final List<String> targetSizes; // 'small', 'medium', 'large'
  final String visibility; // 'public', 'friends', 'invite_only'
  final double? price;
  final List<String> photoUrls;
  final bool requiresRegistration;
  final String status; // 'upcoming', 'ongoing', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;
  // final bool isPublic; // Deprecated, use generic visibility

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.organizerId,
    required this.organizerType,
    required this.organizerName,
    required this.organizerAvatarUrl,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.latitude,
    this.longitude,
    required this.category,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.targetAgeGroups,
    required this.targetSizes,
    this.price,
    required this.photoUrls,
    required this.requiresRegistration,
    this.visibility = 'public',
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? organizerId,
    String? organizerType,
    String? organizerName,
    String? organizerAvatarUrl,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    double? latitude,
    double? longitude,
    String? category,
    int? maxParticipants,
    int? currentParticipants,
    List<String>? targetAgeGroups,
    List<String>? targetSizes,
    double? price,
    List<String>? photoUrls,
    bool? requiresRegistration,
    String? visibility,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Event(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        organizerId: organizerId ?? this.organizerId,
        organizerType: organizerType ?? this.organizerType,
        organizerName: organizerName ?? this.organizerName,
        organizerAvatarUrl: organizerAvatarUrl ?? this.organizerAvatarUrl,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        location: location ?? this.location,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        category: category ?? this.category,
        maxParticipants: maxParticipants ?? this.maxParticipants,
        currentParticipants: currentParticipants ?? this.currentParticipants,
        targetAgeGroups: targetAgeGroups ?? this.targetAgeGroups,
        targetSizes: targetSizes ?? this.targetSizes,
        price: price ?? this.price,
        photoUrls: photoUrls ?? this.photoUrls,
        requiresRegistration: requiresRegistration ?? this.requiresRegistration,
        visibility: visibility ?? this.visibility,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      organizerId: json['organizer_id'] as String,
      organizerType: json['organizer_type'] as String? ?? 'user',
      organizerName: json['organizer_name'] as String? ?? 'Unknown',
      organizerAvatarUrl: json['organizer_avatar_url'] as String? ?? '',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      location: json['location'] as String,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      category: json['category'] as String,
      maxParticipants: json['max_participants'] as int,
      currentParticipants: json['current_participants'] as int? ?? 0,
      targetAgeGroups: List<String>.from(json['target_age_groups'] ?? []),
      targetSizes: List<String>.from(json['target_sizes'] ?? []),
      price: json['price'] as double?,
      photoUrls: List<String>.from(json['photo_urls'] ?? []),
      requiresRegistration: json['requires_registration'] as bool? ?? true,
      visibility: json['visibility'] as String? ??
          (json['is_public'] == true ? 'public' : 'invite_only'),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'organizer_id': organizerId,
      'organizer_type': organizerType,
      'organizer_name': organizerName,
      'organizer_avatar_url': organizerAvatarUrl,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'target_age_groups': targetAgeGroups,
      'target_sizes': targetSizes,
      'price': price,
      'photo_urls': photoUrls,
      'requires_registration': requiresRegistration,
      'visibility': visibility,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isFree => price == null || price == 0;
  bool get isPublic => visibility == 'public';
  bool get isFull => currentParticipants >= maxParticipants;
  bool get isUpcoming => status == 'upcoming';
  bool get isOngoing => status == 'ongoing';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get formattedPrice {
    if (isFree) return 'Free';
    return '\$${price!.toStringAsFixed(2)}';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = startTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(startTime)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${_formatTime(startTime)}';
    } else if (difference.inDays < 7) {
      return '${_formatWeekday(startTime)} at ${_formatTime(startTime)}';
    } else {
      return '${_formatMonthDay(startTime)} at ${_formatTime(startTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatWeekday(DateTime dateTime) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dateTime.weekday - 1];
  }

  String _formatMonthDay(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }

  String get categoryIcon {
    switch (category.toLowerCase()) {
      case 'birthday':
        return '🎂';
      case 'training':
        return '🎓';
      case 'social':
        return '🐕';
      case 'professional':
        return '🏥';
      default:
        return '📅';
    }
  }

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'birthday':
        return 'Birthday Party';
      case 'training':
        return 'Training Class';
      case 'social':
        return 'Social Meetup';
      case 'professional':
        return 'Professional Service';
      default:
        return 'Event';
    }
  }
}
