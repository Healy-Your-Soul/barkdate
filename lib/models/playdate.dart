class Playdate {
  final String id;
  final String initiatorUserId;
  final String invitedUserId;
  final String initiatorDogName;
  final String invitedDogName;
  final String title;
  final String location;
  final DateTime dateTime;
  final PlaydateStatus status;
  final String? imageUrl;
  final String? notes;

  const Playdate({
    required this.id,
    required this.initiatorUserId,
    required this.invitedUserId,
    required this.initiatorDogName,
    required this.invitedDogName,
    required this.title,
    required this.location,
    required this.dateTime,
    required this.status,
    this.imageUrl,
    this.notes,
  });

  Playdate copyWith({
    String? id,
    String? initiatorUserId,
    String? invitedUserId,
    String? initiatorDogName,
    String? invitedDogName,
    String? title,
    String? location,
    DateTime? dateTime,
    PlaydateStatus? status,
    String? imageUrl,
    String? notes,
  }) => Playdate(
    id: id ?? this.id,
    initiatorUserId: initiatorUserId ?? this.initiatorUserId,
    invitedUserId: invitedUserId ?? this.invitedUserId,
    initiatorDogName: initiatorDogName ?? this.initiatorDogName,
    invitedDogName: invitedDogName ?? this.invitedDogName,
    title: title ?? this.title,
    location: location ?? this.location,
    dateTime: dateTime ?? this.dateTime,
    status: status ?? this.status,
    imageUrl: imageUrl ?? this.imageUrl,
    notes: notes ?? this.notes,
  );
}

enum PlaydateStatus { pending, accepted, declined, completed }

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