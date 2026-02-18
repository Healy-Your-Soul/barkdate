class CheckIn {
  final String id;
  final String userId;
  final String dogId;
  final String parkId;
  final String parkName;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final String status; // 'active', 'completed'
  final bool isFutureCheckin;
  final DateTime? scheduledFor;
  final double? latitude;
  final double? longitude;

  const CheckIn({
    required this.id,
    required this.userId,
    required this.dogId,
    required this.parkId,
    required this.parkName,
    required this.checkedInAt,
    this.checkedOutAt,
    required this.status,
    required this.isFutureCheckin,
    this.scheduledFor,
    this.latitude,
    this.longitude,
  });

  CheckIn copyWith({
    String? id,
    String? userId,
    String? dogId,
    String? parkId,
    String? parkName,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,
    String? status,
    bool? isFutureCheckin,
    DateTime? scheduledFor,
    double? latitude,
    double? longitude,
  }) =>
      CheckIn(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        dogId: dogId ?? this.dogId,
        parkId: parkId ?? this.parkId,
        parkName: parkName ?? this.parkName,
        checkedInAt: checkedInAt ?? this.checkedInAt,
        checkedOutAt: checkedOutAt ?? this.checkedOutAt,
        status: status ?? this.status,
        isFutureCheckin: isFutureCheckin ?? this.isFutureCheckin,
        scheduledFor: scheduledFor ?? this.scheduledFor,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dogId: json['dog_id'] as String,
      parkId: json['park_id'] as String,
      parkName: json['park_name'] as String? ?? 'Unknown Park',
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      checkedOutAt: json['checked_out_at'] != null
          ? DateTime.parse(json['checked_out_at'] as String)
          : null,
      status: json['status'] as String,
      isFutureCheckin: json['is_future_checkin'] as bool? ?? false,
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.parse(json['scheduled_for'] as String)
          : null,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'dog_id': dogId,
      'park_id': parkId,
      'park_name': parkName,
      'checked_in_at': checkedInAt.toIso8601String(),
      'checked_out_at': checkedOutAt?.toIso8601String(),
      'status': status,
      'is_future_checkin': isFutureCheckin,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isScheduled => isFutureCheckin && scheduledFor != null;

  Duration? get duration {
    if (checkedOutAt != null) {
      return checkedOutAt!.difference(checkedInAt);
    }
    return null;
  }

  String get formattedDuration {
    final duration = this.duration;
    if (duration == null) return 'Still active';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedCheckInTime {
    final now = DateTime.now();
    final difference = now.difference(checkedInAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String get formattedScheduledTime {
    if (scheduledFor == null) return '';

    final now = DateTime.now();
    final difference = scheduledFor!.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inMinutes < 60) {
      return 'In ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'In ${difference.inHours}h';
    } else {
      return 'In ${difference.inDays}d';
    }
  }
}
