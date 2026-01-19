import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:zenify/zenify.dart';

import 'api.dart';

class FeedController extends ZenController {
  // Query to fetch posts
  late final ZenQuery<List<Post>> postsQuery;

  // Mutation to create a post
  late final ZenMutation<Post, Post> createPostMutation;
  late final ZenMutation<Post, Post> likeMutation;
  late final ZenMutation<void, Post> deleteMutation;

  @override
  void onInit() {
    super.onInit();

    postsQuery = ZenQuery(
      queryKey: 'feed',
      fetcher: (_) => MockApi.getPosts(),
      config: ZenQueryConfig(
        persist: true, // Enable offline persistence
        networkMode: NetworkMode.offlineFirst, // Try cache, fail gracefully
        staleTime: const Duration(minutes: 5), // Keep data fresh for 5 mins
        toJson: (posts) => {'posts': posts.map((e) => e.toJson()).toList()},
        fromJson: (json) =>
            (json['posts'] as List).map((e) => Post.fromJson(e)).toList(),
      ),
    );

    // ✨ NEW: Using optimistic helpers (3 lines vs 15+)
    createPostMutation = ZenMutation.listPut<Post>(
      queryKey: 'feed',
      mutationFn: (post) => MockApi.createPost(post),
    );

    // ✨ NEW: Using optimistic helper for updates
    likeMutation = ZenMutation.listSet<Post>(
      queryKey: 'feed',
      mutationFn: (post) async {
        await MockApi.likePost(post.id, post.isLiked);
        return post; // Return the updated post
      },
      where: (item, updated) => item.id == updated.id,
    );

    // ✨ NEW: Using optimistic helper for deletes
    deleteMutation = ZenMutation.listRemove<Post>(
      queryKey: 'feed',
      mutationFn: (post) => MockApi.deletePost(post.id),
      where: (item, toRemove) => item.id == toRemove.id,
    );
  }

  void addPost(String title, BuildContext context) {
    if (title.isNotEmpty) {
      final newPost = Post(
        id: const Uuid().v4(),
        title: title,
        body: 'Posted at ${DateTime.now().toString()}',
      );
      createPostMutation.mutate(newPost);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post added (Optimistic)!')));
    }
  }

  void toggleLike(Post post) {
    // Pass the updated post object
    likeMutation.mutate(post.copyWith(isLiked: !post.isLiked));
  }

  void deletePost(Post post) {
    // Pass the post object to delete
    deleteMutation.mutate(post);
  }
}
