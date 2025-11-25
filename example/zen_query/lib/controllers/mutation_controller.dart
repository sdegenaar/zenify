import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class MutationController extends ZenController {
  late ZenQuery<Post> currentPostQuery;
  late final ZenMutation<Post, CreatePostRequest> createMutation;
  late final ZenMutation<Post, UpdatePostRequest> updateMutation;
  late final ZenMutation<void, int> deleteMutation;
  late final ZenMutation<Post, int> likeMutation;

  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final updateTitleController = TextEditingController();

  final currentPostId = 1.obs();

  @override
  void onInit() {
    super.onInit();

    // Query for current post
    currentPostQuery = ZenQuery<Post>(
      queryKey: 'post:${currentPostId.value}',
      fetcher: (token) =>
          ApiService.getPost(currentPostId.value, cancelToken: token),
      config: const ZenQueryConfig(
        staleTime: Duration(seconds: 30),
      ),
    );

    // Watch for post ID changes and update query
    ZenWorkers.ever(currentPostId, (id) {
      currentPostQuery.dispose();
      currentPostQuery = ZenQuery<Post>(
        queryKey: 'post:$id',
        fetcher: (token) => ApiService.getPost(id, cancelToken: token),
      );
      currentPostQuery.fetch();
      update();
    });

    // Create mutation
    createMutation = ZenMutation<Post, CreatePostRequest>(
      mutationFn: (request) => ApiService.createPost(request),
      onSuccess: (post, _, __) {
        titleController.clear();
        contentController.clear();
        // Switch to the newly created post
        currentPostId.value = post.id;
      },
      onError: (error, _, __) {
        debugPrint('Failed to create post: $error');
      },
    );

    // Update mutation with optimistic updates
    updateMutation = ZenMutation<Post, UpdatePostRequest>(
      mutationFn: (request) => ApiService.updatePost(request),
      onMutate: (request) {
        // Store old data for rollback
        final oldPost = currentPostQuery.data.value;

        // Optimistically update the UI
        if (oldPost != null) {
          currentPostQuery.setData(
            oldPost.copyWith(title: request.title ?? oldPost.title),
          );
        }

        return oldPost; // Return context for rollback
      },
      onSuccess: (updatedPost, _, __) {
        // Update with real server data
        currentPostQuery.setData(updatedPost);
        updateTitleController.clear();
      },
      onError: (error, _, context) {
        // Rollback on error
        if (context is Post) {
          currentPostQuery.setData(context);
        }
        debugPrint('Failed to update post: $error');
      },
    );

    // Delete mutation
    deleteMutation = ZenMutation<void, int>(
      mutationFn: (id) => ApiService.deletePost(id),
      onSuccess: (_, __, ___) {
        // Move to next post
        currentPostId.value = currentPostId.value + 1;
      },
      onError: (error, _, __) {
        debugPrint('Failed to delete post: $error');
      },
    );

    // Like mutation with optimistic updates
    likeMutation = ZenMutation<Post, int>(
      mutationFn: (id) => ApiService.likePost(id),
      onMutate: (id) {
        final oldPost = currentPostQuery.data.value;

        // Optimistically increment likes
        if (oldPost != null) {
          currentPostQuery.setData(
            oldPost.copyWith(likes: oldPost.likes + 1),
          );
        }

        return oldPost;
      },
      onSuccess: (updatedPost, _, __) {
        currentPostQuery.setData(updatedPost);
      },
      onError: (error, _, context) {
        // Rollback on error
        if (context is Post) {
          currentPostQuery.setData(context);
        }
      },
    );
  }

  void createPost() {
    if (titleController.text.isEmpty || contentController.text.isEmpty) {
      return;
    }

    createMutation.mutate(
      CreatePostRequest(
        title: titleController.text,
        content: contentController.text,
      ),
    );
  }

  void updatePost() {
    if (updateTitleController.text.isEmpty) return;

    final post = currentPostQuery.data.value;
    if (post == null) return;

    updateMutation.mutate(
      UpdatePostRequest(
        id: post.id,
        title: updateTitleController.text,
      ),
    );
  }

  void deletePost() {
    final post = currentPostQuery.data.value;
    if (post == null) return;

    deleteMutation.mutate(post.id);
  }

  void likePost() {
    final post = currentPostQuery.data.value;
    if (post == null) return;

    likeMutation.mutate(post.id);
  }

  @override
  void onClose() {
    currentPostQuery.dispose();
    createMutation.dispose();
    updateMutation.dispose();
    deleteMutation.dispose();
    likeMutation.dispose();
    titleController.dispose();
    contentController.dispose();
    updateTitleController.dispose();
    super.onClose();
  }
}
