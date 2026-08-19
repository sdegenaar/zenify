// lib/widgets/builders/zen_query_consumer.dart
//
// ZenQueryConsumer — declarative query fetch + build in a single widget.
//
// Designed for read-only, stateless data display where creating a dedicated
// controller is unnecessary boilerplate. For mutations, pagination, or shared
// state across multiple widgets, use ZenQueryBuilder with a ZenController.

import 'package:flutter/material.dart';
import '../../query/core/query_key.dart';
import '../../query/core/zen_query_cache.dart';
import '../../query/logic/zen_query.dart';
import '../../query/core/zen_query_config.dart';
import 'zen_query_builder.dart';

/// A self-contained widget that creates, fetches, and renders a [ZenQuery]
/// without requiring a separate controller or module.
///
/// Perfect for simple, stateless data-display use-cases — analogous to
/// `useQuery` in React/TanStack Query.
///
/// **Basic usage:**
/// ```dart
/// ZenQueryConsumer<User>(
///   queryKey: 'user:123',
///   fetcher: (_) => api.getUser(123),
///   data: (user) => UserCard(user),
/// )
/// ```
///
/// **With all state handlers:**
/// ```dart
/// ZenQueryConsumer<User>(
///   queryKey: 'user:123',
///   fetcher: (_) => api.getUser(123),
///   data: (user) => UserProfile(user),
///   loading: () => const CircularProgressIndicator(),
///   error: (err, retry) => ErrorView(err, onRetry: retry),
///   idle: () => const SizedBox.shrink(),
/// )
/// ```
///
/// **With config:**
/// ```dart
/// ZenQueryConsumer<List<Post>>(
///   queryKey: 'posts',
///   fetcher: (_) => api.getPosts(),
///   config: ZenQueryConfig(staleTime: Duration(minutes: 5)),
///   data: (posts) => PostList(posts),
/// )
/// ```
///
/// ### When to use ZenQueryConsumer vs ZenQueryBuilder
///
/// | Scenario | Use |
/// |---|---|
/// | Simple data display, no shared state | `ZenQueryConsumer` |
/// | Query shared across multiple widgets | `ZenQueryBuilder` + controller |
/// | Mutations + queries together | `ZenQueryBuilder` + controller |
/// | Pagination / infinite scroll | `ZenQueryBuilder` + controller |
///
/// ### Lifecycle
///
/// The internal [ZenQuery] is created once when the widget mounts and disposed
/// when the widget is removed from the tree. If [queryKey] changes, the old
/// query is disposed and a new one is created.
///
/// ### queryKey is the dependency declaration
///
/// If your [fetcher] captures a variable (e.g., a user ID or filter), include
/// that variable in the [queryKey]. Changes to the [fetcher] closure reference
/// alone do **not** trigger a rebuild — Dart closures change reference on
/// every parent build, so using fetcher identity would cause infinite loops.
///
/// ```dart
/// // ✅ Correct — key changes when userId changes, query rebuilds
/// ZenQueryConsumer<User>(
///   queryKey: 'user:$userId',
///   fetcher: (_) => api.getUser(userId),
///   data: (user) => UserCard(user),
/// )
///
/// // ❌ Wrong — static key, fetcher silently keeps old userId
/// ZenQueryConsumer<User>(
///   queryKey: 'current-user',  // never changes
///   fetcher: (_) => api.getUser(userId),  // stale closure
///   data: (user) => UserCard(user),
/// )
/// ```
class ZenQueryConsumer<T> extends StatefulWidget {
  /// Unique key for caching and deduplication. Matches the same key in other
  /// [ZenQueryConsumer] or [ZenQueryBuilder] widgets to share cached data.
  final Object queryKey;

  /// The async function that fetches data.
  final ZenQueryFetcher<T> fetcher;

  /// Builder for the success state. Required.
  final Widget Function(T data) data;

  /// Builder for the loading state.
  /// Defaults to a centered [CircularProgressIndicator].
  final Widget Function()? loading;

  /// Builder for the error state with a retry callback.
  /// Defaults to the built-in [ZenQueryBuilder] error UI.
  final Widget Function(Object error, VoidCallback retry)? error;

  /// Builder for the idle state (before the first fetch).
  /// Defaults to [SizedBox.shrink].
  final Widget Function()? idle;

  /// Query configuration — stale time, caching, retry policy etc.
  final ZenQueryConfig<T>? config;

  /// Initial data shown before the first fetch completes.
  final T? initialData;

  /// Whether to automatically fetch when the widget mounts. Defaults to true.
  final bool autoFetch;

  /// Whether to show stale data while a background refetch is in progress.
  /// Defaults to true.
  final bool showStaleData;

  /// If true, keeps showing the data from the previous query instance
  /// (if available) while the new query is loading.
  ///
  /// Useful for pagination to prevent "flash of loading" when key changes.
  final bool keepPreviousData;

  const ZenQueryConsumer({
    super.key,
    required this.queryKey,
    required this.fetcher,
    required this.data,
    this.loading,
    this.error,
    this.idle,
    this.config,
    this.initialData,
    this.autoFetch = true,
    this.showStaleData = true,
    this.keepPreviousData = false,
  });

  @override
  State<ZenQueryConsumer<T>> createState() => _ZenQueryConsumerState<T>();
}

class _ZenQueryConsumerState<T> extends State<ZenQueryConsumer<T>> {
  late ZenQuery<T> _query;
  late String _normalizedKey;

  /// Global reference count per normalized query key for consumer-managed queries.
  static final Map<String, int> _consumerRefCounts = {};

  /// Set of queries created internally by ZenQueryConsumer instances.
  /// Ensures we only auto-dispose queries created by consumers, and not
  /// externally owned queries registered by controllers or services.
  static final Set<ZenQuery> _consumerCreatedQueries = {};

  @override
  void initState() {
    super.initState();
    _normalizedKey = QueryKey.normalize(widget.queryKey);
    _query = _acquireQuery();
  }

  @override
  void didUpdateWidget(ZenQueryConsumer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = QueryKey.normalize(widget.queryKey);
    if (newKey != _normalizedKey) {
      final oldKey = _normalizedKey;
      final oldQuery = _query;
      _normalizedKey = newKey;
      _query = _acquireQuery();
      _releaseQuery(oldKey, oldQuery);
    }
  }

  ZenQuery<T> _acquireQuery() {
    final existing = ZenQueryCache.instance.getQuery<T>(_normalizedKey);
    if (existing != null && !existing.isDisposed) {
      _consumerRefCounts[_normalizedKey] =
          (_consumerRefCounts[_normalizedKey] ?? 0) + 1;
      return existing;
    }

    final query = ZenQuery<T>(
      queryKey: widget.queryKey,
      fetcher: widget.fetcher,
      config: widget.config,
      initialData: widget.initialData,
      registerInCache: true,
    );
    _consumerRefCounts[_normalizedKey] = 1;
    _consumerCreatedQueries.add(query);
    return query;
  }

  void _releaseQuery(String key, ZenQuery<T> queryToRelease) {
    final count = (_consumerRefCounts[key] ?? 1) - 1;
    if (count <= 0) {
      _consumerRefCounts.remove(key);
      if (_consumerCreatedQueries.remove(queryToRelease) &&
          !queryToRelease.isDisposed) {
        queryToRelease.dispose();
      }
    } else {
      _consumerRefCounts[key] = count;
    }
  }

  @override
  void dispose() {
    _releaseQuery(_normalizedKey, _query);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZenQueryBuilder<T>(
      query: _query,
      builder: (context, value) => widget.data(value),
      loading: widget.loading,
      error: widget.error,
      idle: widget.idle,
      autoFetch: widget.autoFetch,
      showStaleData: widget.showStaleData,
      keepPreviousData: widget.keepPreviousData,
    );
  }
}
