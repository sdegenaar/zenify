// Data Models for the ZenQuery Example

class User {
  final int id;
  final String name;
  final String email;
  final String avatar;
  final String bio;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.bio,
  });

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? avatar,
    String? bio,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'bio': bio,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatar: json['avatar'],
      bio: json['bio'],
    );
  }
}

class Post {
  final int id;
  final int userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final int likes;

  Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.likes,
  });

  Post copyWith({
    int? id,
    int? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    int? likes,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      likes: json['likes'],
    );
  }
}

class Comment {
  final int id;
  final int postId;
  final String author;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'author': author,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      postId: json['postId'],
      author: json['author'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

// Paginated response wrapper
class PaginatedResponse<T> {
  final List<T> items;
  final int page;
  final int totalPages;
  final int totalItems;
  final bool hasMore;

  PaginatedResponse({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.hasMore,
  });

  Map<String, dynamic> toJson() {
    return {
      'items': items,
      'page': page,
      'totalPages': totalPages,
      'totalItems': totalItems,
      'hasMore': hasMore,
    };
  }
}

class CreatePostRequest {
  final String title;
  final String content;

  CreatePostRequest({required this.title, required this.content});
}

class UpdatePostRequest {
  final int id;
  final String? title;
  final String? content;

  UpdatePostRequest({required this.id, this.title, this.content});
}
