import 'package:zenify/zenify.dart';

// --- Data Models & Mock API ---

class Post {
  final String id;
  final String title;
  final String body;
  final bool isLiked;

  Post({
    required this.id,
    required this.title,
    required this.body,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'isLiked': isLiked,
  };

  Post copyWith({String? title, String? body, bool? isLiked}) {
    return Post(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class MockApi {
  // Simulate server database
  static final List<Post> _db = [
    Post(
      id: '1',
      title: 'Welcome to Zenify',
      body: 'This data is from the server.',
    ),
    Post(id: '2', title: 'Offline Mode', body: 'Try turning off your WiFi!'),
  ];

  static Future<List<Post>> getPosts() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.of(_db);
  }

  static Future<Post> createPost(Post post) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    _db.insert(0, post);
    ZenLogger.logInfo('SERVER: Created post ${post.title}');
    return post;
  }

  static Future<void> likePost(String id, bool isLiked) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.indexWhere((p) => p.id == id);
    if (index != -1) {
      _db[index] = _db[index].copyWith(isLiked: isLiked);
      ZenLogger.logInfo('SERVER: ${isLiked ? "Liked" : "Unliked"} post $id');
    }
  }

  static Future<void> deletePost(String id) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _db.removeWhere((p) => p.id == id);
    ZenLogger.logInfo('SERVER: Deleted post $id');
  }
}
