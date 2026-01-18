import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:zenify/zenify.dart';

import 'api.dart';

class FeedController extends ZenController {
  // Query to fetch posts
  late final ZenQuery<List<Post>> postsQuery;

  // Mutation to create a post
  late final ZenMutation<Post, Post> createPostMutation;
  late final ZenMutation<void, Map<String, dynamic>> likeMutation;
  late final ZenMutation<void, Map<String, dynamic>> deleteMutation;

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

    createPostMutation = ZenMutation(
      mutationKey: 'create_post', // Required for offline queueing
      mutationFn: (post) => MockApi.createPost(post),
      onMutate: (newPost) async {
        // Optimistic Update!
        // We manually update the cache to show the new post immediately
        ZenQueryCache.instance.setQueryData<List<Post>>(
          'feed',
          (old) => [newPost, ...(old ?? [])],
        );
        return null; // context
      },
      onSettled: (_, _, _, _) {
        // Refetch to reflect server state (ids, timestamps)
        postsQuery.refetch();
      },
    );

    likeMutation = ZenMutation(
      mutationKey: 'like_post',
      mutationFn: (vars) => MockApi.likePost(vars['id'], vars['isLiked']),
      onMutate: (vars) async {
        final id = vars['id'] as String;
        final isLiked = vars['isLiked'] as bool;

        ZenQueryCache.instance.setQueryData<List<Post>>(
          'feed',
          (old) =>
              old
                  ?.map((p) => p.id == id ? p.copyWith(isLiked: isLiked) : p)
                  .toList() ??
              [],
        );
        return null;
      },
    );

    deleteMutation = ZenMutation(
      mutationKey: 'delete_post',
      mutationFn: (vars) => MockApi.deletePost(vars['id'] as String),
      onMutate: (vars) async {
        final id = vars['id'] as String;
        ZenQueryCache.instance.setQueryData<List<Post>>(
          'feed',
          (old) => old?.where((p) => p.id != id).toList() ?? [],
        );
        return null;
      },
      onError: (e, vars, context) {
        // Rollback logic could go here
        // For now we just invalidate to be safe
        postsQuery.invalidate();
      },
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
    likeMutation.mutate({'id': post.id, 'isLiked': !post.isLiked});
  }

  void deletePost(Post post) {
    deleteMutation.mutate({'id': post.id});
  }
}
