import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Comprehensive Playdate models with all states and user flows

enum PlaydateStatus {
  pending('pending'),
  confirmed('confirmed'), 
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  expired('expired');

  const PlaydateStatus(this.value);
  final String value;

  static PlaydateStatus fromString(String value) {
    return PlaydateStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PlaydateStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case PlaydateStatus.pending:
        return 'Pending';
      case PlaydateStatus.confirmed:
        return 'Confirmed';
      case PlaydateStatus.inProgress:
        return 'In Progress';
      case PlaydateStatus.completed:
        return 'Completed';
      case PlaydateStatus.cancelled:
        return 'Cancelled';
      case PlaydateStatus.expired:
        return 'Expired';
    }
  }

  Color get color {
    switch (this) {
      case PlaydateStatus.pending:
        return Colors.orange;
      case PlaydateStatus.confirmed:
        return Colors.green;
      case PlaydateStatus.inProgress:
        return Colors.blue;
      case PlaydateStatus.completed:
        return Colors.grey;
      case PlaydateStatus.cancelled:
        return Colors.red;
      case PlaydateStatus.expired:
        return Colors.grey.shade600;
    }
  }

  IconData get icon {
    switch (this) {
      case PlaydateStatus.pending:
        return Icons.hourglass_empty;
      case PlaydateStatus.confirmed:
        return Icons.check_circle;
      case PlaydateStatus.inProgress:
        return Icons.play_circle;
      case PlaydateStatus.completed:
        return Icons.task_alt;
      case PlaydateStatus.cancelled:
        return Icons.cancel;
      case PlaydateStatus.expired:
        return Icons.schedule;
    }
  }
}

enum AgePreference {
  puppy('puppy'),
  young('young'), 
  adult('adult'),
  senior('senior'),
  any('any');

  const AgePreference(this.value);
  final String value;

  String get displayName {
    switch (this) {
      case AgePreference.puppy:
        return 'Puppy (0-1 year)';
      case AgePreference.young:
        return 'Young (1-3 years)';
      case AgePreference.adult:
        return 'Adult (3-7 years)';
      case AgePreference.senior:
        return 'Senior (7+ years)';
      case AgePreference.any:
        return 'Any Age';
    }
  }
}

enum SizePreference {
  small('small'),
  medium('medium'),
  large('large'),
  any('any');

  const SizePreference(this.value);
  final String value;

  String get displayName {
    switch (this) {
      case SizePreference.small:
        return 'Small (under 25 lbs)';
      case SizePreference.medium:
        return 'Medium (25-60 lbs)';
      case SizePreference.large:
        return 'Large (60+ lbs)';
      case SizePreference.any:
        return 'Any Size';
    }
  }
}

class PlaydateParticipant {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String dogId;
  final String dogName;
  final String? dogPhotoUrl;
  final DateTime joinedAt;
  final bool isOrganizer;

  const PlaydateParticipant({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.dogId,
    required this.dogName,
    this.dogPhotoUrl,
    required this.joinedAt,
    this.isOrganizer = false,
  });

  factory PlaydateParticipant.fromJson(Map<String, dynamic> json) {
    return PlaydateParticipant(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? json['user']?['name'] ?? '',
      userAvatarUrl: json['user_avatar_url'] ?? json['user']?['avatar_url'],
      dogId: json['dog_id'] ?? '',
      dogName: json['dog_name'] ?? json['dog']?['name'] ?? '',
      dogPhotoUrl: json['dog_photo_url'] ?? json['dog']?['main_photo_url'],
      joinedAt: DateTime.parse(json['joined_at'] ?? DateTime.now().toIso8601String()),
      isOrganizer: json['is_organizer'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar_url': userAvatarUrl,
      'dog_id': dogId,
      'dog_name': dogName,
      'dog_photo_url': dogPhotoUrl,
      'joined_at': joinedAt.toIso8601String(),
      'is_organizer': isOrganizer,
    };
  }
}

class Playdate {
  final String id;
  final String title;
  final String? description;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime scheduledAt;
  final int durationMinutes;
  final int maxDogs;
  final PlaydateStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Participants (many-to-many)
  final List<PlaydateParticipant> participants;
  
  // Organizer info (for easy access)
  final String organizerId;
  final String organizerName;
  final String? organizerAvatarUrl;

  const Playdate({
    required this.id,
    required this.title,
    this.description,
    required this.location,
    this.latitude,
    this.longitude,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.maxDogs = 2,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.participants = const [],
    required this.organizerId,
    required this.organizerName,
    this.organizerAvatarUrl,
  });

  // Helper getters
  PlaydateParticipant? get organizer => participants.where((p) => p.isOrganizer).firstOrNull;
  
  List<PlaydateParticipant> get nonOrganizerParticipants => participants.where((p) => !p.isOrganizer).toList();
  
  bool get isFull => participants.length >= maxDogs;
  
  bool get isUpcoming => scheduledAt.isAfter(DateTime.now()) && status == PlaydateStatus.confirmed;
  
  bool get isPast => scheduledAt.isBefore(DateTime.now()) || status == PlaydateStatus.completed;
  
  bool get canJoin => !isFull && status == PlaydateStatus.pending;
  
  bool get canEdit => status == PlaydateStatus.pending || status == PlaydateStatus.confirmed;
  
  bool userIsParticipant(String userId) => participants.any((p) => p.userId == userId);
  
  bool userIsOrganizer(String userId) => organizerId == userId;
  
  String get participantsDisplay {
    if (participants.isEmpty) return 'No participants';
    if (participants.length == 1) return participants.first.userName;
    return '${participants.first.userName} +${participants.length - 1} others';
  }

  // Time helpers
  String get timeDisplay {
    final now = DateTime.now();
    final difference = scheduledAt.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes';
    } else if (difference.inMinutes < 0) {
      return 'Past';
    } else {
      return 'Now';
    }
  }

  String get formattedDateTime {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(scheduledAt)} at ${timeFormat.format(scheduledAt)}';
  }

  factory Playdate.fromJson(Map<String, dynamic> json) {
    // Parse participants
    final participantsList = <PlaydateParticipant>[];
    if (json['participants'] != null) {
      final participantsData = json['participants'] as List;
      participantsList.addAll(participantsData.map((p) => PlaydateParticipant.fromJson(p)));
    }

    // Find organizer for easy access
    final organizer = participantsList.where((p) => p.isOrganizer).firstOrNull;

    return Playdate(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      location: json['location'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      scheduledAt: DateTime.parse(json['scheduled_at'] ?? DateTime.now().toIso8601String()),
      durationMinutes: json['duration_minutes']?.toInt() ?? 60,
      maxDogs: json['max_dogs']?.toInt() ?? 2,
      status: PlaydateStatus.fromString(json['status'] ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      participants: participantsList,
      organizerId: organizer?.userId ?? json['organizer_id'] ?? '',
      organizerName: organizer?.userName ?? json['organizer_name'] ?? '',
      organizerAvatarUrl: organizer?.userAvatarUrl ?? json['organizer_avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'max_dogs': maxDogs,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'organizer_id': organizerId,
      'organizer_name': organizerName,
      'organizer_avatar_url': organizerAvatarUrl,
    };
  }

  Playdate copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? scheduledAt,
    int? durationMinutes,
    int? maxDogs,
    PlaydateStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PlaydateParticipant>? participants,
    String? organizerId,
    String? organizerName,
    String? organizerAvatarUrl,
  }) {
    return Playdate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      maxDogs: maxDogs ?? this.maxDogs,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participants: participants ?? this.participants,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerAvatarUrl: organizerAvatarUrl ?? this.organizerAvatarUrl,
    );
  }
}

// Request models for playdate invitations
enum PlaydateRequestStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  counterProposed('counter_proposed'),
  expired('expired');

  const PlaydateRequestStatus(this.value);
  final String value;

  static PlaydateRequestStatus fromString(String value) {
    return PlaydateRequestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PlaydateRequestStatus.pending,
    );
  }
}

class PlaydateRequest {
  final String id;
  final String playdateId;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatarUrl;
  final String inviteeId;
  final String inviteeName;
  final String? inviteeAvatarUrl;
  final String dogId;
  final String dogName;
  final String? dogPhotoUrl;
  final String? message;
  final PlaydateRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  
  // Associated playdate info
  final String? playdateTitle;
  final String? playdateLocation;
  final DateTime? playdateScheduledAt;

  const PlaydateRequest({
    required this.id,
    required this.playdateId,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatarUrl,
    required this.inviteeId,
    required this.inviteeName,
    this.inviteeAvatarUrl,
    required this.dogId,
    required this.dogName,
    this.dogPhotoUrl,
    this.message,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.playdateTitle,
    this.playdateLocation,
    this.playdateScheduledAt,
  });

  bool get isPending => status == PlaydateRequestStatus.pending;
  bool get isAccepted => status == PlaydateRequestStatus.accepted;
  bool get isDeclined => status == PlaydateRequestStatus.declined;
  bool get isExpired => status == PlaydateRequestStatus.expired;

  factory PlaydateRequest.fromJson(Map<String, dynamic> json) {
    return PlaydateRequest(
      id: json['id'] ?? '',
      playdateId: json['playdate_id'] ?? '',
      requesterId: json['requester_id'] ?? '',
      requesterName: json['requester_name'] ?? json['requester']?['name'] ?? '',
      requesterAvatarUrl: json['requester_avatar_url'] ?? json['requester']?['avatar_url'],
      inviteeId: json['invitee_id'] ?? '',
      inviteeName: json['invitee_name'] ?? json['invitee']?['name'] ?? '',
      inviteeAvatarUrl: json['invitee_avatar_url'] ?? json['invitee']?['avatar_url'],
      dogId: json['dog_id'] ?? '',
      dogName: json['dog_name'] ?? json['dog']?['name'] ?? '',
      dogPhotoUrl: json['dog_photo_url'] ?? json['dog']?['main_photo_url'],
      message: json['message'],
      status: PlaydateRequestStatus.fromString(json['status'] ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at']) : null,
      playdateTitle: json['playdate_title'] ?? json['playdate']?['title'],
      playdateLocation: json['playdate_location'] ?? json['playdate']?['location'],
      playdateScheduledAt: json['playdate_scheduled_at'] != null || json['playdate']?['scheduled_at'] != null
          ? DateTime.parse(json['playdate_scheduled_at'] ?? json['playdate']['scheduled_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playdate_id': playdateId,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_avatar_url': requesterAvatarUrl,
      'invitee_id': inviteeId,
      'invitee_name': inviteeName,
      'invitee_avatar_url': inviteeAvatarUrl,
      'dog_id': dogId,
      'dog_name': dogName,
      'dog_photo_url': dogPhotoUrl,
      'message': message,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'playdate_title': playdateTitle,
      'playdate_location': playdateLocation,
      'playdate_scheduled_at': playdateScheduledAt?.toIso8601String(),
    };
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final bool isEarned;
  final DateTime? earnedDate;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    this.isEarned = false,
    this.earnedDate,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? iconName,
    bool? isEarned,
    DateTime? earnedDate,
  }) => Achievement(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    iconName: iconName ?? this.iconName,
    isEarned: isEarned ?? this.isEarned,
    earnedDate: earnedDate ?? this.earnedDate,
  );
}