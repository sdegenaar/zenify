import 'dart:async';
import 'dart:math';
import 'package:zenify/zenify.dart';
import '../models/models.dart';

/// Mock API service that simulates network requests
/// Demonstrates realistic scenarios for ZenQuery features
class ApiService {
  static final Random _random = Random();

  // In-memory storage to simulate a backend
  static final List<User> _users = List.generate(
    10,
    (i) => User(
      id: i + 1,
      name: 'User ${i + 1}',
      email: 'user${i + 1}@example.com',
      avatar: 'https://i.pravatar.cc/150?u=${i + 1}',
      bio: 'This is the bio for User ${i + 1}',
    ),
  );

  static final List<Post> _posts = List.generate(
    100,
    (i) => Post(
      id: i + 1,
      userId: (i % 10) + 1,
      title: 'Post ${i + 1}',
      content:
          'This is the content of post ${i + 1}. Lorem ipsum dolor sit amet.',
      createdAt: DateTime.now().subtract(Duration(hours: i)),
      likes: _random.nextInt(100),
    ),
  );

  static final List<Comment> _comments = [];
  static int _nextCommentId = 1;

  // Simulate network delay
  static Future<void> _simulateNetworkDelay(
      {int minMs = 500, int maxMs = 1500}) {
    final delay = minMs + _random.nextInt(maxMs - minMs);
    return Future.delayed(Duration(milliseconds: delay));
  }

  // Simulate occasional network errors
  static void _maybeThrowError({double errorRate = 0.1}) {
    if (_random.nextDouble() < errorRate) {
      throw Exception('Network error: Request failed');
    }
  }

  // ========== User Endpoints ==========

  /// Get a single user by ID
  static Future<User> getUser(int id, {ZenCancelToken? cancelToken}) async {
    await _simulateNetworkDelay();

    // Check if cancelled
    if (cancelToken?.isCancelled ?? false) {
      throw ZenCancellationException('Request cancelled');
    }

    _maybeThrowError(errorRate: 0.05);

    final user = _users.firstWhere(
      (u) => u.id == id,
      orElse: () => throw Exception('User not found'),
    );

    return user;
  }

  /// Get all users (with optional search)
  static Future<List<User>> getUsers({String? search}) async {
    await _simulateNetworkDelay(minMs: 300, maxMs: 800);
    _maybeThrowError(errorRate: 0.05);

    if (search != null && search.isNotEmpty) {
      return _users
          .where((u) =>
              u.name.toLowerCase().contains(search.toLowerCase()) ||
              u.email.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }

    return List.from(_users);
  }

  /// Update a user
  static Future<User> updateUser(int id,
      {String? name, String? email, String? bio}) async {
    await _simulateNetworkDelay(minMs: 400, maxMs: 1000);
    _maybeThrowError(errorRate: 0.08);

    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) throw Exception('User not found');

    final user = _users[index];
    final updated = user.copyWith(
      name: name ?? user.name,
      email: email ?? user.email,
      bio: bio ?? user.bio,
    );

    _users[index] = updated;
    return updated;
  }

  // ========== Post Endpoints ==========

  /// Get posts with pagination
  static Future<PaginatedResponse<Post>> getPosts({
    int page = 1,
    int pageSize = 10,
    int? userId,
    ZenCancelToken? cancelToken,
  }) async {
    await _simulateNetworkDelay(minMs: 400, maxMs: 1200);

    if (cancelToken?.isCancelled ?? false) {
      throw ZenCancellationException('Request cancelled');
    }

    _maybeThrowError(errorRate: 0.05);

    var filteredPosts = _posts;
    if (userId != null) {
      filteredPosts = _posts.where((p) => p.userId == userId).toList();
    }

    final startIndex = (page - 1) * pageSize;
    final endIndex = min(startIndex + pageSize, filteredPosts.length);

    if (startIndex >= filteredPosts.length) {
      return PaginatedResponse(
        items: [],
        page: page,
        totalPages: (filteredPosts.length / pageSize).ceil(),
        totalItems: filteredPosts.length,
        hasMore: false,
      );
    }

    final items = filteredPosts.sublist(startIndex, endIndex);

    return PaginatedResponse(
      items: items,
      page: page,
      totalPages: (filteredPosts.length / pageSize).ceil(),
      totalItems: filteredPosts.length,
      hasMore: endIndex < filteredPosts.length,
    );
  }

  /// Get a single post by ID
  static Future<Post> getPost(int id, {ZenCancelToken? cancelToken}) async {
    await _simulateNetworkDelay();

    if (cancelToken?.isCancelled ?? false) {
      throw ZenCancellationException('Request cancelled');
    }

    _maybeThrowError(errorRate: 0.05);

    final post = _posts.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Post not found'),
    );

    return post;
  }

  /// Create a new post
  static Future<Post> createPost(CreatePostRequest request) async {
    await _simulateNetworkDelay(minMs: 500, maxMs: 1500);
    _maybeThrowError(errorRate: 0.08);

    final newPost = Post(
      id: _posts.length + 1,
      userId: 1, // Current user
      title: request.title,
      content: request.content,
      createdAt: DateTime.now(),
      likes: 0,
    );

    _posts.insert(0, newPost); // Add to beginning
    return newPost;
  }

  /// Update a post
  static Future<Post> updatePost(UpdatePostRequest request) async {
    await _simulateNetworkDelay(minMs: 400, maxMs: 1000);
    _maybeThrowError(errorRate: 0.08);

    final index = _posts.indexWhere((p) => p.id == request.id);
    if (index == -1) throw Exception('Post not found');

    final post = _posts[index];
    final updated = post.copyWith(
      title: request.title ?? post.title,
      content: request.content ?? post.content,
    );

    _posts[index] = updated;
    return updated;
  }

  /// Delete a post
  static Future<void> deletePost(int id) async {
    await _simulateNetworkDelay(minMs: 300, maxMs: 800);
    _maybeThrowError(errorRate: 0.08);

    final index = _posts.indexWhere((p) => p.id == id);
    if (index == -1) throw Exception('Post not found');

    _posts.removeAt(index);
  }

  /// Like a post
  static Future<Post> likePost(int id) async {
    await _simulateNetworkDelay(minMs: 200, maxMs: 500);
    _maybeThrowError(errorRate: 0.05);

    final index = _posts.indexWhere((p) => p.id == id);
    if (index == -1) throw Exception('Post not found');

    final post = _posts[index];
    final updated = post.copyWith(likes: post.likes + 1);
    _posts[index] = updated;

    return updated;
  }

  // ========== Comment Endpoints ==========

  /// Get comments for a post
  static Future<List<Comment>> getComments(int postId) async {
    await _simulateNetworkDelay(minMs: 300, maxMs: 800);
    _maybeThrowError(errorRate: 0.05);

    return _comments.where((c) => c.postId == postId).toList();
  }

  /// Add a comment to a post
  static Future<Comment> addComment(
      int postId, String content, String author) async {
    await _simulateNetworkDelay(minMs: 400, maxMs: 1000);
    _maybeThrowError(errorRate: 0.08);

    final comment = Comment(
      id: _nextCommentId++,
      postId: postId,
      author: author,
      content: content,
      createdAt: DateTime.now(),
    );

    _comments.add(comment);
    return comment;
  }

  // ========== Stream Endpoints ==========

  /// Stream of real-time notifications
  static Stream<String> getNotificationStream() async* {
    await Future.delayed(const Duration(seconds: 1));

    final notifications = [
      'New follower: User 5',
      'User 3 liked your post',
      'New comment on your post',
      'User 7 shared your post',
      'New message from User 2',
    ];

    for (var i = 0; i < notifications.length; i++) {
      await Future.delayed(Duration(seconds: 3 + _random.nextInt(3)));
      yield notifications[i];
    }
  }

  /// Stream of live post updates
  static Stream<Post> getPostUpdatesStream(int postId) async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 5));

      try {
        final post = _posts.firstWhere((p) => p.id == postId);
        // Simulate random like
        if (_random.nextBool()) {
          final updated = post.copyWith(likes: post.likes + 1);
          final index = _posts.indexWhere((p) => p.id == postId);
          _posts[index] = updated;
          yield updated;
        }
      } catch (e) {
        // Post not found, stop streaming
        break;
      }
    }
  }

  /// Stream of active users count
  static Stream<int> getActiveUsersStream() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      yield 10 + _random.nextInt(90); // Random between 10-100
    }
  }
}
