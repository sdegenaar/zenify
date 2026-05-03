import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:zenify/query/core/query_key.dart';
import 'package:zenify/query/core/zen_storage.dart';

import '../../core/zen_logger.dart';
import '../../di/zen_lifecycle.dart';
import '../logic/zen_query.dart';
import 'zen_query_config.dart';
import 'zen_query_enums.dart';

/// Cache entry for a query
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration? cacheTime;
  Timer? expiryTimer;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    this.cacheTime,
  });

  bool get isExpired {
    if (cacheTime == null) return false;
    return DateTime.now().difference(timestamp) > cacheTime!;
  }
}

/// Global cache manager for ZenQuery instances
///
/// Supports both global queries and scope-aware queries for flexible
/// lifecycle management and cache isolation.
///
/// Handles:
/// - Query deduplication
/// - Cache invalidation
/// - Memory management
/// - Query coordination
/// - Smart refetching (Focus/Reconnect)
class ZenQueryCache {
  ZenQueryCache._() {
    // Start observing app lifecycle via ZenLifecycleManager
    ZenLifecycleManager.instance.addLifecycleListener(_onLifecycleChanged);
  }

  static final ZenQueryCache instance = ZenQueryCache._();

  // Map of query key to query instance
  final Map<String, ZenQuery> _queries = {};

  // Track which queries belong to which scope
  final Map<String, Set<String>> _scopeQueries = {};

  // Tag index: tag -> Set of query keys that carry that tag
  final Map<String, Set<String>> _tagIndex = {};

  /// Cached data by key
  final Map<String, _CacheEntry> _cache = {};

  /// Pending fetches by key (for deduplication)
  final Map<String, Future> _pendingFetches = {};

  /// Whether to use real timers (false in tests to avoid pending timer issues)
  bool _useRealTimers = true;

  /// Network status subscription
  StreamSubscription<bool>? _networkSubscription;
  bool _isOnline = true;

  /// Queries that want to retry their full fetch cycle when connectivity returns.
  /// Populated by ZenQuery when `retryWhenOnline=true` and retries are exhausted offline.
  final Set<ZenQuery> _retryWhenOnlineQueue = {};

  /// Whether the app is currently connected to the network
  bool get isOnline => _isOnline;

  /// Global storage implementation
  ZenStorage? _storage;

  /// Set the global storage implementation for persistence
  void setStorage(ZenStorage storage) {
    _storage = storage;
  }

  /// Configure timer behavior for testing
  ///
  /// Set [useRealTimers] to false in tests to prevent pending timer errors.
  /// This is automatically called by ZenTestMode.
  void configureForTesting({bool useRealTimers = false}) {
    _useRealTimers = useRealTimers;
  }

  /// Whether real timers are being used (false in test mode)
  bool get useRealTimers => _useRealTimers;

  /// Set the network connectivity stream
  void setNetworkStream(Stream<bool> stream) {
    _networkSubscription?.cancel();
    _networkSubscription = stream.listen((isOnline) {
      final wasOffline = !_isOnline;
      _isOnline = isOnline;

      if (wasOffline && isOnline) {
        ZenLogger.logDebug(
            'Network reconnected. Refetching eligible queries...');
        _drainRetryWhenOnlineQueue();
        _refetchOnReconnect();
      }
    });
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ZenLogger.logDebug('App resumed. Refetching eligible queries...');
      _refetchOnFocus();
    }
  }

  /// Manually trigger a lifecycle change for testing purposes.
  /// Use this instead of [didChangeAppLifecycleState] in tests.
  @visibleForTesting
  void simulateLifecycleState(AppLifecycleState state) {
    _onLifecycleChanged(state);
  }

  void _refetchOnFocus() {
    for (final query in _queries.values.toList()) {
      if (query.isDisposed) continue;

      if (query.config.refetchOnFocus
              .shouldRefetch(query.isStale || query.hasError) &&
          !query.isLoading.value) {
        if (query.enabled.value) {
          query.refetch().then((_) {}, onError: (_) {});
        }
      }
    }
  }

  void _refetchOnReconnect() {
    for (final query in _queries.values.toList()) {
      if (query.isDisposed) continue;

      if (query.config.refetchOnReconnect
              .shouldRefetch(query.isStale || query.hasError) &&
          !query.isLoading.value) {
        if (query.enabled.value) {
          query.refetch().then((_) {}, onError: (_) {});
        }
      }
    }
  }

  /// Register a query to retry its full fetch cycle when connectivity returns.
  ///
  /// Called internally by [ZenQuery] when `retryWhenOnline` is true and retries
  /// are exhausted while the device is offline.
  void registerRetryWhenOnline(ZenQuery query) {
    if (!query.isDisposed) {
      _retryWhenOnlineQueue.add(query);
      ZenLogger.logDebug(
          'Query "${query.queryKey}" queued for retry-when-online.');
    }
  }

  /// Unregister a query from the retry-when-online queue (e.g., on dispose).
  void unregisterRetryWhenOnline(ZenQuery query) {
    _retryWhenOnlineQueue.remove(query);
  }

  /// Drain all queries waiting for connectivity and restart their retry cycles.
  void _drainRetryWhenOnlineQueue() {
    if (_retryWhenOnlineQueue.isEmpty) return;

    final toRetry = _retryWhenOnlineQueue.toList();
    _retryWhenOnlineQueue.clear();

    ZenLogger.logDebug(
        'Draining retry-when-online queue: ${toRetry.length} queries.');

    for (final query in toRetry) {
      if (query.isDisposed || !query.enabled.value) continue;
      // Force a fresh fetch — this resets _retryAttempt and runs the full
      // retry cycle again with exponential backoff.
      query.fetch(force: true).then((_) {}, onError: (_) {});
    }
  }

  /// Register a query in the cache
  void register<T>(ZenQuery<T> query) {
    _queries[query.queryKey] = query;
    _indexTags(query.queryKey, query.tags);
    ZenLogger.logDebug('Registered global query: ${query.queryKey}');
  }

  /// Register a scoped query with automatic scope tracking
  void registerScoped<T>(ZenQuery<T> query, String scopedKey, String scopeId) {
    _queries[scopedKey] = query;
    _indexTags(scopedKey, query.tags);

    // Track which queries belong to this scope
    _scopeQueries.putIfAbsent(scopeId, () => <String>{}).add(scopedKey);

    ZenLogger.logDebug(
      'Registered scoped query: ${query.queryKey} '
      '(scopedKey: $scopedKey, scopeId: $scopeId)',
    );
  }

  /// Unregister a query from the cache
  void unregister(String queryKey) {
    final query = _queries.remove(queryKey);
    _unindexTags(queryKey);

    // Remove from scope tracking if it was a scoped query
    _scopeQueries.forEach((scopeId, keys) {
      keys.remove(queryKey);
    });

    // Clean up empty scope entries
    _scopeQueries.removeWhere((key, value) => value.isEmpty);

    if (query != null) {
      ZenLogger.logDebug('Unregistered query: $queryKey');
    }
  }

  // ---------------------------------------------------------------------------
  // Tag index helpers
  // ---------------------------------------------------------------------------

  void _indexTags(String queryKey, List<String> tags) {
    for (final tag in tags) {
      _tagIndex.putIfAbsent(tag, () => <String>{}).add(queryKey);
    }
  }

  void _unindexTags(String queryKey) {
    for (final keys in _tagIndex.values) {
      keys.remove(queryKey);
    }
    _tagIndex.removeWhere((_, keys) => keys.isEmpty);
  }

  /// Invalidate all queries in a specific scope
  void invalidateScope(String scopeId) {
    final scopeQueries = _scopeQueries[scopeId];
    if (scopeQueries == null) return;

    int invalidatedCount = 0;
    for (final key in scopeQueries) {
      final query = _queries[key];
      if (query != null && !query.isDisposed) {
        query.invalidate();
        invalidatedCount++;
      }
    }

    ZenLogger.logDebug(
      'Invalidated $invalidatedCount queries in scope: $scopeId',
    );
  }

  /// Refetch all queries in a specific scope
  Future<void> refetchScope(String scopeId) async {
    final scopeQueries = _scopeQueries[scopeId];
    if (scopeQueries == null) return;

    final refetchFutures = <Future>[];
    for (final key in scopeQueries) {
      final query = _queries[key];
      if (query != null && !query.isDisposed) {
        refetchFutures.add(query.refetch().catchError((e) {
          ZenLogger.logWarning(
            'Failed to refetch query $key in scope $scopeId: $e',
          );
        }));
      }
    }

    await Future.wait(refetchFutures);
    ZenLogger.logDebug(
        'Refetched ${refetchFutures.length} queries in scope: $scopeId');
  }

  /// Clear all queries in a specific scope
  void clearScope(String scopeId) {
    final scopeQueries = _scopeQueries[scopeId];
    if (scopeQueries == null) return;

    final keysToRemove = List<String>.from(scopeQueries);
    for (final key in keysToRemove) {
      _queries.remove(key);
    }

    _scopeQueries.remove(scopeId);
    ZenLogger.logDebug(
        'Cleared ${keysToRemove.length} queries from scope: $scopeId');
  }

  /// Get all queries in a specific scope
  List<ZenQuery> getScopeQueries(String scopeId) {
    final scopeQueries = _scopeQueries[scopeId];
    if (scopeQueries == null) return [];

    return scopeQueries
        .map((key) => _queries[key])
        .whereType<ZenQuery>()
        .toList();
  }

  /// Get statistics about scope queries
  Map<String, dynamic> getScopeStats(String scopeId) {
    final queries = getScopeQueries(scopeId);

    return {
      'total': queries.length,
      'loading': queries.where((q) => q.isLoading.value).length,
      'success':
          queries.where((q) => q.status.value == ZenQueryStatus.success).length,
      'error':
          queries.where((q) => q.status.value == ZenQueryStatus.error).length,
      'stale': queries.where((q) => q.isStale).length,
    };
  }

  /// Get query by key
  ZenQuery<T>? getQuery<T>(Object queryKey) {
    // Changed to Object
    final normalizedKey = QueryKey.normalize(queryKey);
    return _queries[normalizedKey] as ZenQuery<T>?;
  }

  /// Get all queries
  List<ZenQuery> get queries => _queries.values.toList();

  /// Get all queries (for lifecycle management)
  List<ZenQuery> getAllQueries() => _queries.values.toList();

  /// Update cache for a query
  void updateCache<T>(String queryKey, T data, DateTime timestamp) {
    final query = _queries[queryKey];
    // Allow caching even without a query instance (e.g. prefetch)
    // Default to 5 minutes if no query/config available
    final cacheTime = query?.config.cacheTime ?? const Duration(minutes: 5);

    _setCacheEntry(queryKey, data, timestamp, cacheTime);

    // Persist if enabled
    if (query != null) {
      // 1. Notify active query instance to update UI (Optimistic Updates / Prefetch)
      // Use dynamic dispatch to handle generic type erasure safely
      try {
        (query as dynamic).setData(data);
      } catch (e) {
        ZenLogger.logWarning(
          'Failed to propagate cache update to query $queryKey: $e',
        );
      }

      // 2. Persist
      if (query.config.persist) {
        _persistQuery(
            queryKey, data, timestamp, query.config as ZenQueryConfig<T>);
      }
    }
  }

  Future<void> _persistQuery<T>(
    String key,
    T data,
    DateTime timestamp,
    ZenQueryConfig<T> config,
  ) async {
    final storage = config.storage ?? _storage;
    if (storage == null) {
      ZenLogger.logWarning(
          'Query $key is marked for persistence but no storage is configured.');
      return;
    }

    if (config.toJson == null) {
      ZenLogger.logWarning(
          'Query $key is marked for persistence but toJson is not provided.');
      return;
    }

    try {
      final jsonData = config.toJson!(data);
      final entry = {
        'data': jsonData,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'version': 1,
      };
      await storage.write(key, entry);
      ZenLogger.logDebug('Persisted query: $key');
    } catch (e, stack) {
      ZenLogger.logError('Failed to persist query $key', e, stack);
    }
  }

  /// Try to hydrate a query from storage
  Future<T?> hydrate<T>(
    String key,
    ZenQueryConfig<T> config,
  ) async {
    final storage = config.storage ?? _storage;
    if (storage == null) return null;
    if (config.fromJson == null) return null;

    try {
      final entry = await storage.read(key);
      if (entry == null) return null;

      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(entry['timestamp'] as int);

      // Check if expired based on cacheTime
      final cacheTime = config.cacheTime;
      if (DateTime.now().difference(timestamp) > cacheTime) {
        await storage.delete(key);
        return null;
      }

      final data = config.fromJson!(entry['data'] as Map<String, dynamic>);

      // Update memory cache
      updateCache(key, data, timestamp);

      ZenLogger.logDebug('Hydrated query: $key');
      return data;
    } catch (e, stack) {
      ZenLogger.logError('Failed to hydrate query $key', e, stack);
      return null;
    }
  }

  void _setCacheEntry<T>(
      String key, T data, DateTime timestamp, Duration? cacheTime) {
    // Cancel existing expiry timer
    _cache[key]?.expiryTimer?.cancel();

    // Create new cache entry
    final entry = _CacheEntry<T>(
      data: data,
      timestamp: timestamp,
      cacheTime: cacheTime,
    );

    // Setup expiry timer if cacheTime is set AND we're using real timers
    if (entry.cacheTime != null && _useRealTimers) {
      entry.expiryTimer = Timer(entry.cacheTime!, () {
        _cache.remove(key);
      });
    }

    _cache[key] = entry;
  }

  /// Prefetch data and store it in the cache if it's not already fresh.
  Future<void> prefetch<T>({
    required Object queryKey,
    required Future<T> Function() fetcher,
    Duration? staleTime,
    Duration? cacheTime,
  }) async {
    final normalizedKey = QueryKey.normalize(queryKey);

    if (_isDataFresh(normalizedKey, staleTime)) return;

    try {
      final data = await deduplicateFetch(normalizedKey, fetcher);

      // Determine cache time
      final query = _queries[normalizedKey];
      final effectiveCacheTime =
          cacheTime ?? query?.config.cacheTime ?? const Duration(minutes: 5);

      _setCacheEntry(normalizedKey, data, DateTime.now(), effectiveCacheTime);
    } catch (e) {
      ZenLogger.logWarning('Prefetch failed for $normalizedKey: $e');
    }
  }

  bool _isDataFresh(String key, Duration? overrideStaleTime) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) return false;

    final query = _queries[key];
    final staleDuration =
        overrideStaleTime ?? query?.config.staleTime ?? Duration.zero;

    return DateTime.now().difference(entry.timestamp) <= staleDuration;
  }

  /// Get cached data for a query
  T? getCachedData<T>(Object queryKey) {
    // Changed to Object
    final normalizedKey = QueryKey.normalize(queryKey);
    final entry = _cache[normalizedKey];
    if (entry == null || entry.isExpired) {
      return null;
    }
    return entry.data as T?;
  }

  /// Functionally update cached data for a query.
  ///
  /// [updater] receives the previous data and returns new data.
  /// Automatically sets the timestamp to now.
  void setQueryData<T>(Object queryKey, T Function(T? oldData) updater) {
    final normalizedKey = QueryKey.normalize(queryKey);
    final oldData = getCachedData<T>(normalizedKey);
    final newData = updater(oldData);

    updateCache(normalizedKey, newData, DateTime.now());
  }

  /// Get cached timestamp for a query
  DateTime? getTimestamp(Object queryKey) {
    final normalizedKey = QueryKey.normalize(queryKey);
    return _cache[normalizedKey]?.timestamp;
  }

  /// Invalidate query (mark as stale)
  void invalidateQuery(Object queryKey) {
    // Changed to Object
    final normalizedKey = QueryKey.normalize(queryKey);
    final query = _queries[normalizedKey];
    if (query != null) {
      query.invalidate();
    }
  }

  /// Invalidate queries matching pattern
  void invalidateQueries(bool Function(String key) predicate) {
    for (final key in _queries.keys) {
      if (predicate(key)) {
        invalidateQuery(key);
      }
    }
  }

  /// Invalidate all queries with a prefix
  void invalidateQueriesWithPrefix(String prefix) {
    invalidateQueries((key) => key.startsWith(prefix));
  }

  /// Invalidate all queries that carry [tag].
  ///
  /// Tags are assigned at query creation:
  /// ```dart
  /// ZenQuery<User>(
  ///   queryKey: 'user:123',
  ///   tags: ['user', 'profile'],
  ///   fetcher: (_) => api.getUser(123),
  /// );
  ///
  /// // Invalidate everything tagged 'user':
  /// Zen.queryCache.invalidateQueriesByTag('user');
  /// ```
  void invalidateQueriesByTag(String tag) {
    final keys = _tagIndex[tag];
    if (keys == null || keys.isEmpty) return;

    int count = 0;
    for (final key in keys.toList()) {
      final query = _queries[key];
      if (query != null && !query.isDisposed) {
        query.invalidate();
        count++;
      }
    }
    ZenLogger.logDebug('Invalidated $count queries with tag: $tag');
  }

  /// Invalidate all queries whose keys match a glob-style [pattern].
  ///
  /// Supports `*` as a wildcard anywhere in the pattern:
  /// ```dart
  /// // All user entity queries:
  /// Zen.queryCache.invalidateQueriesByPattern('user:*');
  ///
  /// // All comment sub-queries regardless of entity:
  /// Zen.queryCache.invalidateQueriesByPattern('*:comments');
  ///
  /// // Any key containing 'feed':
  /// Zen.queryCache.invalidateQueriesByPattern('*feed*');
  /// ```
  void invalidateQueriesByPattern(String pattern) {
    final matches = _matchPattern(pattern);
    int count = 0;
    for (final key in matches) {
      final query = _queries[key];
      if (query != null && !query.isDisposed) {
        query.invalidate();
        count++;
      }
    }
    ZenLogger.logDebug('Invalidated $count queries matching pattern: $pattern');
  }

  /// Returns all query keys currently registered under [tag].
  List<String> getKeysByTag(String tag) {
    return (_tagIndex[tag] ?? {}).toList();
  }

  /// Returns all live (non-disposed) queries that carry [tag].
  List<ZenQuery> getQueriesByTag(String tag) {
    final keys = _tagIndex[tag];
    if (keys == null) return [];
    return keys
        .map((k) => _queries[k])
        .whereType<ZenQuery>()
        .where((q) => !q.isDisposed)
        .toList();
  }

  /// Refetch a query by key
  Future<void> refetchQuery(String queryKey) async {
    final query = _queries[queryKey];
    if (query != null) {
      await query.refetch();
    }
  }

  /// Refetch all queries whose keys match [predicate].
  Future<void> refetchQueries(bool Function(String key) predicate) async {
    final futures = <Future>[];
    for (final entry in _queries.entries) {
      if (predicate(entry.key)) {
        futures.add(
          Future(() async {
            try {
              await entry.value.refetch();
            } catch (e) {
              ZenLogger.logWarning(
                'Failed to refetch query ${entry.key}: $e',
              );
            }
          }),
        );
      }
    }
    await Future.wait(futures);
  }

  /// Refetch all queries that carry [tag].
  Future<void> refetchQueriesByTag(String tag) async {
    final keys = _tagIndex[tag];
    if (keys == null || keys.isEmpty) return;

    final futures = <Future>[];
    for (final key in keys.toList()) {
      final query = _queries[key];
      if (query != null && !query.isDisposed) {
        futures.add(
          query.refetch().catchError((Object e) {
            ZenLogger.logWarning(
                'Failed to refetch query $key (tag: $tag): $e');
          }),
        );
      }
    }
    await Future.wait(futures);
    ZenLogger.logDebug('Refetched ${futures.length} queries with tag: $tag');
  }

  /// Refetch all queries matching a glob-style [pattern].
  Future<void> refetchQueriesByPattern(String pattern) async {
    final matches = _matchPattern(pattern);
    final futures = <Future>[];
    for (final key in matches) {
      final query = _queries[key];
      if (query != null && !query.isDisposed) {
        futures.add(
          query.refetch().catchError((Object e) {
            ZenLogger.logWarning(
                'Failed to refetch query $key (pattern: $pattern): $e');
          }),
        );
      }
    }
    await Future.wait(futures);
    ZenLogger.logDebug(
        'Refetched ${futures.length} queries matching pattern: $pattern');
  }

  // ---------------------------------------------------------------------------
  // Pattern matching
  // ---------------------------------------------------------------------------

  /// Returns all registered query keys matching the glob-style [pattern].
  /// Supports [*] as a wildcard at any position in the pattern.
  List<String> _matchPattern(String pattern) {
    if (!pattern.contains('*')) {
      return _queries.containsKey(pattern) ? [pattern] : [];
    }

    // Warn if the pattern is only wildcards — this will match every query in the cache.
    if (pattern.replaceAll('*', '').isEmpty) {
      ZenLogger.logWarning(
        'invalidateQueriesByPattern called with "$pattern" which matches ALL '
        'queries in the cache. If this is intentional, use ZenQueryCache.clear() instead.',
      );
    }

    final parts = pattern.split('*').map(RegExp.escape).join('.*');
    final regex = RegExp('^$parts' r'$');
    return _queries.keys.where((k) => regex.hasMatch(k)).toList();
  }

  /// Remove query from cache
  void removeQuery(Object queryKey) {
    // Changed to Object
    final normalizedKey = QueryKey.normalize(queryKey);
    _cache[normalizedKey]?.expiryTimer?.cancel();
    _cache.remove(normalizedKey);
    _queries.remove(normalizedKey);
    _pendingFetches.remove(normalizedKey);
  }

  /// Clear all queries and cache
  void clear() {
    for (final entry in _cache.values) {
      entry.expiryTimer?.cancel();
    }
    _cache.clear();
    _queries.clear();
    _pendingFetches.clear();
    _scopeQueries.clear();
    _tagIndex.clear();
    _retryWhenOnlineQueue.clear(); // Prevent stale query references after reset
  }

  /// Get comprehensive cache statistics
  Map<String, dynamic> getStats() {
    int globalQueries = 0;
    int scopedQueries = 0;

    // Count queries by checking if they're tracked in _scopeQueries
    final allScopedKeys = <String>{};
    for (final scopeKeys in _scopeQueries.values) {
      allScopedKeys.addAll(scopeKeys);
    }

    for (final key in _queries.keys) {
      if (allScopedKeys.contains(key)) {
        scopedQueries++;
      } else {
        globalQueries++;
      }
    }

    return {
      'total_queries': _queries.length,
      'global_queries': globalQueries,
      'scoped_queries': scopedQueries,
      'active_scopes': _scopeQueries.length,
      'loading': _queries.values.where((q) => q.isLoading.value).length,
      'success': _queries.values
          .where((q) => q.status.value == ZenQueryStatus.success)
          .length,
      'error': _queries.values
          .where((q) => q.status.value == ZenQueryStatus.error)
          .length,
      'stale': _queries.values.where((q) => q.isStale).length,
    };
  }

  /// Deduplicate concurrent fetches for the same query
  Future<T> deduplicateFetch<T>(
    String queryKey,
    Future<T> Function() fetcher,
  ) async {
    // Check if fetch is already in progress
    final pending = _pendingFetches[queryKey];
    if (pending != null) {
      return pending as Future<T>;
    }

    // Start new fetch
    final future = fetcher();
    _pendingFetches[queryKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _pendingFetches.remove(queryKey);
    }
  }
}
