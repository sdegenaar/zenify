import '../logic/zen_mutation.dart';
import '../core/zen_query_cache.dart';

/// Optimistic mutation helpers for common patterns.
///
/// These helpers eliminate boilerplate for standard optimistic update scenarios.
///
/// Example:
/// ```dart
/// // Before: 15+ lines
/// final createPost = ZenMutation<Post, Post>(
///   mutationKey: 'create_post',
///   mutationFn: (post) => api.createPost(post),
///   onMutate: (post) async {
///     ZenQueryCache.instance.setQueryData<List<Post>>(
///       'feed',
///       (old) => [post, ...(old ?? [])],
///     );
///     return old;
///   },
///   onError: (err, post, old) {
///     if (old != null) {
///       ZenQueryCache.instance.setQueryData('feed', (_) => old);
///     }
///   },
/// );
///
/// // After: 3 lines
/// final createPost = OptimisticMutation.listAdd<Post>(
///   queryKey: 'feed',
///   mutationKey: 'create_post',
///   mutationFn: (post) => api.createPost(post),
/// );
/// ```
class OptimisticMutation {
  /// Create a mutation that optimistically adds an item to a list.
  ///
  /// Automatically:
  /// - Adds item to list immediately (optimistic update)
  /// - Rolls back on error
  /// - Supports offline queueing
  ///
  /// Example:
  /// ```dart
  /// final createPost = OptimisticMutation.listAdd<Post>(
  ///   queryKey: 'posts',
  ///   mutationKey: 'create_post',
  ///   mutationFn: (post) => api.createPost(post),
  /// );
  ///
  /// // Use it
  /// createPost.mutate(newPost);
  /// ```
  static ZenMutation<TData, TData> listAdd<TData>({
    required Object queryKey,
    required String mutationKey,
    required Future<TData> Function(TData item) mutationFn,
    bool addToStart = true,
    void Function(TData data, TData item, Object? context)? onSuccess,
    void Function(Object error, TData item)? onError,
  }) {
    return ZenMutation<TData, TData>(
      mutationKey: mutationKey,
      mutationFn: mutationFn,
      onMutate: (item) async {
        // Save old list for rollback
        final oldList =
            ZenQueryCache.instance.getCachedData<List<TData>>(queryKey);

        // Optimistically add to list
        ZenQueryCache.instance.setQueryData<List<TData>>(
          queryKey,
          (old) {
            final list = old ?? <TData>[];
            return addToStart ? [item, ...list] : [...list, item];
          },
        );

        return oldList; // Return for rollback
      },
      onSuccess: (data, item, context) => onSuccess?.call(data, item, context),
      onError: (err, item, context) {
        // Rollback on error
        if (context != null) {
          ZenQueryCache.instance.setQueryData<List<TData>>(
            queryKey,
            (_) => context as List<TData>,
          );
        }
        onError?.call(err, item);
      },
    );
  }

  /// Create a mutation that optimistically removes an item from a list.
  ///
  /// Automatically:
  /// - Removes item from list immediately (optimistic update)
  /// - Rolls back on error
  /// - Supports offline queueing
  ///
  /// Example:
  /// ```dart
  /// final deletePost = OptimisticMutation.listRemove<Post>(
  ///   queryKey: 'posts',
  ///   mutationKey: 'delete_post',
  ///   mutationFn: (post) => api.deletePost(post.id),
  ///   where: (item, toRemove) => item.id == toRemove.id,
  /// );
  /// ```
  static ZenMutation<void, TData> listRemove<TData>({
    required Object queryKey,
    required String mutationKey,
    required Future<void> Function(TData item) mutationFn,
    required bool Function(TData item, TData toRemove) where,
    void Function(TData item, Object? context)? onSuccess,
    void Function(Object error, TData item)? onError,
  }) {
    return ZenMutation<void, TData>(
      mutationKey: mutationKey,
      mutationFn: mutationFn,
      onMutate: (item) async {
        // Save old list for rollback
        final oldList =
            ZenQueryCache.instance.getCachedData<List<TData>>(queryKey);

        // Optimistically remove from list
        ZenQueryCache.instance.setQueryData<List<TData>>(
          queryKey,
          (old) => old?.where((i) => !where(i, item)).toList() ?? [],
        );

        return oldList; // Return for rollback
      },
      onSuccess: (_, item, context) => onSuccess?.call(item, context),
      onError: (err, item, context) {
        // Rollback on error
        if (context != null) {
          ZenQueryCache.instance.setQueryData<List<TData>>(
            queryKey,
            (_) => context as List<TData>,
          );
        }
        onError?.call(err, item);
      },
    );
  }

  /// Create a mutation that optimistically updates an item in a list.
  ///
  /// Automatically:
  /// - Updates item in list immediately (optimistic update)
  /// - Rolls back on error
  /// - Supports offline queueing
  ///
  /// Example:
  /// ```dart
  /// final updatePost = OptimisticMutation.listUpdate<Post>(
  ///   queryKey: 'posts',
  ///   mutationKey: 'update_post',
  ///   mutationFn: (post) => api.updatePost(post),
  ///   where: (item, updated) => item.id == updated.id,
  /// );
  /// ```
  static ZenMutation<TData, TData> listUpdate<TData>({
    required Object queryKey,
    required String mutationKey,
    required Future<TData> Function(TData item) mutationFn,
    required bool Function(TData item, TData updated) where,
    void Function(TData data, TData item, Object? context)? onSuccess,
    void Function(Object error, TData item)? onError,
  }) {
    return ZenMutation<TData, TData>(
      mutationKey: mutationKey,
      mutationFn: mutationFn,
      onMutate: (item) async {
        // Save old list for rollback
        final oldList =
            ZenQueryCache.instance.getCachedData<List<TData>>(queryKey);

        // Optimistically update in list
        ZenQueryCache.instance.setQueryData<List<TData>>(
          queryKey,
          (old) => old?.map((i) => where(i, item) ? item : i).toList() ?? [],
        );

        return oldList; // Return for rollback
      },
      onSuccess: (data, item, context) => onSuccess?.call(data, item, context),
      onError: (err, item, context) {
        // Rollback on error
        if (context != null) {
          ZenQueryCache.instance.setQueryData<List<TData>>(
            queryKey,
            (_) => context as List<TData>,
          );
        }
        onError?.call(err, item);
      },
    );
  }

  /// Create a mutation that optimistically updates a single value.
  ///
  /// Automatically:
  /// - Updates value immediately (optimistic update)
  /// - Rolls back on error
  /// - Supports offline queueing
  ///
  /// Example:
  /// ```dart
  /// final updateUser = OptimisticMutation.update<User>(
  ///   queryKey: 'current_user',
  ///   mutationKey: 'update_user',
  ///   mutationFn: (user) => api.updateUser(user),
  /// );
  /// ```
  static ZenMutation<TData, TData> update<TData>({
    required Object queryKey,
    required String mutationKey,
    required Future<TData> Function(TData value) mutationFn,
    void Function(TData data, TData value, Object? context)? onSuccess,
    void Function(Object error, TData value)? onError,
  }) {
    return ZenMutation<TData, TData>(
      mutationKey: mutationKey,
      mutationFn: mutationFn,
      onMutate: (value) async {
        // Save old value for rollback
        final oldValue = ZenQueryCache.instance.getCachedData<TData>(queryKey);

        // Optimistically update value
        ZenQueryCache.instance.setQueryData<TData>(
          queryKey,
          (_) => value,
        );

        return oldValue; // Return for rollback
      },
      onSuccess: (data, value, context) =>
          onSuccess?.call(data, value, context),
      onError: (err, value, context) {
        // Rollback on error
        if (context != null) {
          ZenQueryCache.instance.setQueryData<TData>(
            queryKey,
            (_) => context as TData,
          );
        }
        onError?.call(err, value);
      },
    );
  }

  /// Create a mutation that optimistically adds/creates a single value.
  ///
  /// Alias for `update` - both create and update use the same pattern
  /// for single values (set the value in cache).
  ///
  /// Automatically:
  /// - Sets value immediately (optimistic update)
  /// - Rolls back on error
  /// - Supports offline queueing
  ///
  /// Example:
  /// ```dart
  /// final createUser = OptimisticMutation.add<User>(
  ///   queryKey: 'current_user',
  ///   mutationKey: 'create_user',
  ///   mutationFn: (user) => api.createUser(user),
  /// );
  /// ```
  static ZenMutation<TData, TData> add<TData>({
    required Object queryKey,
    required String mutationKey,
    required Future<TData> Function(TData value) mutationFn,
    void Function(TData data, TData value, Object? context)? onSuccess,
    void Function(Object error, TData value)? onError,
  }) {
    // Delegate to update - same implementation
    return update<TData>(
      queryKey: queryKey,
      mutationKey: mutationKey,
      mutationFn: mutationFn,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  /// Create a mutation that optimistically removes/deletes a single value.
  ///
  /// Automatically:
  /// - Clears value from cache immediately (optimistic update)
  /// - Rolls back on error
  /// - Supports offline queueing
  ///
  /// Example:
  /// ```dart
  /// final logout = OptimisticMutation.remove(
  ///   queryKey: 'current_user',
  ///   mutationKey: 'logout',
  ///   mutationFn: () => api.logout(),
  /// );
  /// ```
  static ZenMutation<void, void> remove({
    required Object queryKey,
    required String mutationKey,
    required Future<void> Function() mutationFn,
    void Function(Object? context)? onSuccess,
    void Function(Object error)? onError,
  }) {
    return ZenMutation<void, void>(
      mutationKey: mutationKey,
      mutationFn: (_) => mutationFn(),
      onMutate: (_) async {
        // Save old value for rollback
        final oldValue = ZenQueryCache.instance.getCachedData(queryKey);

        // Optimistically remove value (invalidate query)
        ZenQueryCache.instance.removeQuery(queryKey);

        return oldValue; // Return for rollback
      },
      onSuccess: (_, __, context) => onSuccess?.call(context),
      onError: (err, _, context) {
        // Rollback on error
        if (context != null) {
          ZenQueryCache.instance.setQueryData(
            queryKey,
            (_) => context,
          );
        }
        onError?.call(err);
      },
    );
  }
}
