class Post {
  final String id;
  final String userId;
  final String userName;
  final String userPhoto;
  final String dogName;
  final String? dogId;  // For navigating to dog profile
  final String content;
  final String? imageUrl;
  final List<String> hashtags;
  final DateTime timestamp;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;

  const Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.dogName,
    this.dogId,
    required this.content,
    this.imageUrl,
    this.hashtags = const [],
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isLiked = false,
  });

  Post copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhoto,
    String? dogName,
    String? dogId,
    String? content,
    String? imageUrl,
    List<String>? hashtags,
    DateTime? timestamp,
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
  }) => Post(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    userPhoto: userPhoto ?? this.userPhoto,
    dogName: dogName ?? this.dogName,
    dogId: dogId ?? this.dogId,
    content: content ?? this.content,
    imageUrl: imageUrl ?? this.imageUrl,
    hashtags: hashtags ?? this.hashtags,
    timestamp: timestamp ?? this.timestamp,
    likes: likes ?? this.likes,
    comments: comments ?? this.comments,
    shares: shares ?? this.shares,
    isLiked: isLiked ?? this.isLiked,
  );
}

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userPhoto;
  final String text;
  final DateTime timestamp;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.text,
    required this.timestamp,
  });
}