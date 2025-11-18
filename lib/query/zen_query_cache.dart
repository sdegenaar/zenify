import 'dart:async';
import 'package:flutter/foundation.dart';
import 'zen_query.dart';

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

/// Global cache manager for ZenQuery
///
/// Handles:
/// - Query deduplication
/// - Cache invalidation
/// - Memory management
/// - Query coordination
class ZenQueryCache {
  ZenQueryCache._();

  static final ZenQueryCache instance = ZenQueryCache._();

  /// Active queries by key
  final Map<String, ZenQuery> _queries = {};

  /// Cached data by key
  final Map<String, _CacheEntry> _cache = {};

  /// Pending fetches by key (for deduplication)
  final Map<String, Future> _pendingFetches = {};

  /// Whether to use real timers (false in tests to avoid pending timer issues)
  bool _useRealTimers = true;

  /// Configure timer behavior for testing
  ///
  /// Set [useRealTimers] to false in tests to prevent pending timer errors.
  /// This is automatically called by ZenTestMode.
  void configureForTesting({bool useRealTimers = false}) {
    _useRealTimers = useRealTimers;
  }

  /// Register a query
  void register<T>(ZenQuery<T> query) {
    final existing = _queries[query.queryKey];
    if (existing != null && existing != query) {
      debugPrint(
          'Warning: Query with key "${query.queryKey}" already exists. Using existing instance.');
    }
    _queries[query.queryKey] = query;
  }

  /// Unregister a query
  void unregister(String queryKey) {
    _queries.remove(queryKey);
  }

  /// Get query by key
  ZenQuery<T>? getQuery<T>(String queryKey) {
    return _queries[queryKey] as ZenQuery<T>?;
  }

  /// Get all queries
  List<ZenQuery> get queries => _queries.values.toList();

  /// Update cache for a query
  void updateCache<T>(String queryKey, T data, DateTime timestamp) {
    final query = _queries[queryKey];
    if (query == null) return;

    // Cancel existing expiry timer
    _cache[queryKey]?.expiryTimer?.cancel();

    // Create new cache entry
    final entry = _CacheEntry<T>(
      data: data,
      timestamp: timestamp,
      cacheTime: query.config.cacheTime,
    );

    // Setup expiry timer if cacheTime is set AND we're using real timers
    if (entry.cacheTime != null && _useRealTimers) {
      entry.expiryTimer = Timer(entry.cacheTime!, () {
        _cache.remove(queryKey);
      });
    }

    _cache[queryKey] = entry;
  }

  /// Get cached data for a query
  T? getCachedData<T>(String queryKey) {
    final entry = _cache[queryKey];
    if (entry == null || entry.isExpired) {
      return null;
    }
    return entry.data as T?;
  }

  /// Invalidate query (mark as stale)
  void invalidateQuery(String queryKey) {
    final query = _queries[queryKey];
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
        futures.add(entry.value.refetch().catchError((_) {}));
      }
    }
    await Future.wait(futures);
  }

  /// Remove query from cache
  void removeQuery(String queryKey) {
    _cache[queryKey]?.expiryTimer?.cancel();
    _cache.remove(queryKey);
    _queries.remove(queryKey);
    _pendingFetches.remove(queryKey);
  }

  /// Clear all queries and cache
  void clear() {
    for (final entry in _cache.values) {
      entry.expiryTimer?.cancel();
    }
    _cache.clear();
    _queries.clear();
    _pendingFetches.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'activeQueries': _queries.length,
      'cachedEntries': _cache.length,
      'pendingFetches': _pendingFetches.length,
      'queries': _queries.keys.toList(),
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
