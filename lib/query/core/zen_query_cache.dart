import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:zenify/query/core/query_key.dart';
import 'package:zenify/query/core/zen_storage.dart';

import '../../core/zen_logger.dart';
import '../../di/zen_lifecycle.dart';
import '../logic/zen_query.dart';
import 'zen_query_config.dart';

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

  /// Cached data by key
  final Map<String, _CacheEntry> _cache = {};

  /// Pending fetches by key (for deduplication)
  final Map<String, Future> _pendingFetches = {};

  /// Whether to use real timers (false in tests to avoid pending timer issues)
  bool _useRealTimers = true;

  /// Network status subscription
  StreamSubscription<bool>? _networkSubscription;
  bool _isOnline = true;

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

  /// Set the network connectivity stream
  void setNetworkStream(Stream<bool> stream) {
    _networkSubscription?.cancel();
    _networkSubscription = stream.listen((isOnline) {
      final wasOffline = !_isOnline;
      _isOnline = isOnline;

      if (wasOffline && isOnline) {
        ZenLogger.logDebug(
            'Network reconnected. Refetching eligible queries...');
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

      if (query.config.refetchOnFocus &&
          (query.isStale || query.hasError) &&
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

      if (query.config.refetchOnReconnect &&
          (query.isStale || query.hasError) &&
          !query.isLoading.value) {
        if (query.enabled.value) {
          query.refetch().then((_) {}, onError: (_) {});
        }
      }
    }
  }

  /// Register a query in the cache
  void register<T>(ZenQuery<T> query) {
    _queries[query.queryKey] = query;
    ZenLogger.logDebug('Registered global query: ${query.queryKey}');
  }

  /// Register a scoped query with automatic scope tracking
  void registerScoped<T>(ZenQuery<T> query, String scopedKey, String scopeId) {
    _queries[scopedKey] = query;

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

  /// Update cache for a query
  void updateCache<T>(String queryKey, T data, DateTime timestamp) {
    final query = _queries[queryKey];
    // Allow caching even without a query instance (e.g. prefetch)
    // Default to 5 minutes if no query/config available
    final cacheTime = query?.config.cacheTime ?? const Duration(minutes: 5);

    _setCacheEntry(queryKey, data, timestamp, cacheTime);

    // Persist if enabled
    if (query != null && query.config.persist) {
      _persistQuery(
          queryKey, data, timestamp, query.config as ZenQueryConfig<T>);
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
      final cacheTime = config.cacheTime ?? const Duration(minutes: 5);
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

  /// Refetch query by key
  Future<void> refetchQuery(String queryKey) async {
    final query = _queries[queryKey];
    if (query != null) {
      await query.refetch();
    }
  }

  /// Refetch queries matching pattern
  Future<void> refetchQueries(bool Function(String key) predicate) async {
    final futures = <Future>[];
    for (final entry in _queries.entries) {
      if (predicate(entry.key)) {
        // Wrap in anonymous function to handle errors properly
        futures.add(
          Future(() async {
            try {
              await entry.value.refetch();
            } catch (e) {
              ZenLogger.logWarning(
                'Failed to refetch query ${entry.key}: $e',
              );
              // Don't rethrow - we want to continue with other queries
            }
          }),
        );
      }
    }
    await Future.wait(futures);
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
