import 'dart:async';
import 'package:zenify/query/query_key.dart';
import 'package:zenify/workers/zen_workers.dart';

import '../controllers/zen_controller.dart';
import '../core/zen_logger.dart';
import '../core/zen_scope.dart';
import '../reactive/reactive.dart';
import 'zen_query_cache.dart';
import 'zen_query_config.dart';

/// A reactive query that manages async data fetching with caching
///
/// Example:
/// ```dart
/// final userQuery = ZenQuery<User>(
///   queryKey: 'user:123',
///   fetcher: () => api.getUser(123),
///   config: ZenQueryConfig(
///     staleTime: Duration(minutes: 5),
///     retryCount: 3,
///   ),
/// );
///
/// // In widget
/// ZenQueryBuilder<User>(
///   query: userQuery,
///   builder: (context, data) => Text(data.name),
/// );
/// ```
class ZenQuery<T> extends ZenController {
  /// Unique key for this query (used for caching and deduplication)
  final String queryKey;

  /// Function that fetches the data
  final Future<T> Function() fetcher;

  /// Configuration for this query
  final ZenQueryConfig config;

  /// Optional initial data
  final T? initialData;

  /// Optional scope - if provided, query will be tied to this scope
  final ZenScope? scope;

  /// Whether to automatically dispose when scope disposes
  final bool autoDispose;

  /// Current status of the query
  final Rx<ZenQueryStatus> status = Rx(ZenQueryStatus.idle);

  /// Current data (null if not loaded yet)
  final Rx<T?> data = Rx(null);

  /// Current error (null if no error)
  final Rx<Object?> error = Rx(null);

  bool _isDisposed = false;

  /// Whether the query is currently loading
  RxBool get isLoading =>
      _isLoadingNotifier ??= RxBool(status.value == ZenQueryStatus.loading);
  RxBool? _isLoadingNotifier;

  /// Whether the query has data
  bool get hasData => data.value != null;

  /// Whether the query has an error
  bool get hasError => error.value != null;

  /// Whether this query has been disposed
  @override
  bool get isDisposed => _isDisposed;

  /// Whether data is stale and needs refetching
  bool get isStale {
    if (_lastFetchTime == null) return true;
    final staleTime = config.staleTime;
    if (staleTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) > staleTime;
  }

  /// Whether the query is currently refetching (loading while having data)
  bool get isRefetching => isLoading.value && hasData;

  /// Timestamp of last successful fetch
  DateTime? _lastFetchTime;

  /// Current fetch operation (for deduplication)
  Future<T>? _currentFetch;

  /// Number of current retry attempt
  int _retryAttempt = 0;

  /// Timer for background refetching
  Timer? _refetchTimer;

  /// Whether to register this query in the cache
  final bool _registerInCache;

  ZenQuery({
    required Object queryKey,
    required this.fetcher,
    ZenQueryConfig? config,
    this.initialData,
    this.scope,
    this.autoDispose = true,
    bool registerInCache = true,
  })  : queryKey = QueryKey.normalize(queryKey), // Normalize on init
        config = ZenQueryConfig.defaults.merge(config),
        _registerInCache = registerInCache {
    // Set initial data if provided
    if (initialData != null) {
      data.value = initialData;
      status.value = ZenQueryStatus.success;
      // Don't set _lastFetchTime here - initial data should be considered stale
      // so that the first fetch() actually fetches fresh data
      _lastFetchTime = null;
    }

    // Register in cache (scope-aware or global)
    if (_registerInCache) {
      if (scope != null) {
        _registerInScope();
      } else {
        // Register in global cache (existing behavior)
        ZenQueryCache.instance.register(this);
      }
    }

    // Setup background refetch if enabled
    _setupBackgroundRefetch();
  }

  /// Register query in scope with automatic cleanup
  void _registerInScope() {
    if (scope == null) return;

    // Register in global cache with scope prefix for tracking
    final scopedKey = '${scope!.id}:$queryKey';
    ZenQueryCache.instance.registerScoped(this, scopedKey, scope!.id);

    // Register disposer with scope for automatic cleanup
    if (autoDispose) {
      scope!.registerDisposer(() {
        if (!_isDisposed) {
          ZenLogger.logDebug(
            'Auto-disposing scoped query: $queryKey (scope: ${scope!.name})',
          );
          dispose();
        }
      });
    }

    ZenLogger.logDebug(
      'Registered scoped query: $queryKey in scope ${scope!.name} '
      '(autoDispose: $autoDispose)',
    );
  }

  /// Fetch or refetch data
  ///
  /// Returns cached data immediately if available and not stale,
  /// otherwise fetches fresh data
  Future<T> fetch({bool force = false}) async {
    // Return cached data if available and not stale
    if (!force && hasData && !isStale) {
      return data.value!;
    }

    // Deduplicate concurrent requests
    if (_currentFetch != null) {
      return _currentFetch!;
    }

    // Start fetch operation
    _currentFetch = _performFetch();

    try {
      final result = await _currentFetch!;
      return result;
    } finally {
      _currentFetch = null;
    }
  }

  /// Perform the actual fetch with retry logic
  Future<T> _performFetch() async {
    _retryAttempt = 0;
    return _fetchWithRetry();
  }

  Future<T> _fetchWithRetry() async {
    if (_isDisposed) {
      throw StateError('Query has been disposed');
    }

    // Update status to loading
    status.value = ZenQueryStatus.loading;
    _isLoadingNotifier?.value = true;
    error.value = null;
    update();

    try {
      // Execute fetcher
      final result = await fetcher();

      if (_isDisposed) {
        throw StateError('Query was disposed during fetch');
      }

      // Update with success
      data.value = result;
      status.value = ZenQueryStatus.success;
      _isLoadingNotifier?.value = false;
      error.value = null;
      _lastFetchTime = DateTime.now();
      _retryAttempt = 0;
      update();

      // Cache the result if caching is enabled
      if (_registerInCache) {
        ZenQueryCache.instance.updateCache(queryKey, result, _lastFetchTime!);
      }

      return result;
    } catch (e) {
      if (_isDisposed) {
        throw StateError('Query was disposed during fetch');
      }

      // Check if should retry
      if (_retryAttempt < config.retryCount) {
        _retryAttempt++;

        // Calculate retry delay with exponential backoff
        final delay = config.exponentialBackoff
            ? config.retryDelay * _retryAttempt
            : config.retryDelay;

        await Future.delayed(delay);

        // Retry
        return _fetchWithRetry();
      }

      // No more retries, update with error
      error.value = e;
      status.value = ZenQueryStatus.error;
      _isLoadingNotifier?.value = false;
      update();

      rethrow;
    }
  }

  /// Manually set data (for optimistic updates)
  void setData(T newData) {
    data.value = newData;
    if (status.value == ZenQueryStatus.idle) {
      status.value = ZenQueryStatus.success;
    }
    _lastFetchTime = DateTime.now();
    update();
  }

  /// Invalidate query (mark as stale)
  void invalidate() {
    _lastFetchTime = null;
    update();
  }

  /// Reset query to idle state
  void reset() {
    data.value = initialData;
    error.value = null;
    status.value =
        initialData != null ? ZenQueryStatus.success : ZenQueryStatus.idle;
    _isLoadingNotifier?.value = false;
    _lastFetchTime = initialData != null ? DateTime.now() : null;
    _retryAttempt = 0;
    update();
  }

  /// Refetch data (force refresh)
  Future<T> refetch() => fetch(force: true);

  /// Setup automatic background refetching
  void _setupBackgroundRefetch() {
    final interval = config.refetchInterval;
    if (config.enableBackgroundRefetch && interval != null) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (hasData && !isLoading.value && !_isDisposed) {
          fetch(force: true).then(
            (_) {
              // Background refetch successful
            },
            onError: (error, stackTrace) {
              ZenLogger.logWarning(
                'ZenQuery background refetch failed for query: $queryKey',
              );
              // Don't log full error details for background refetch - it's not critical
              // The query still has cached data that users can see
            },
          );
        }
      });
    }
  }

  /// Creates a derived query that selects a subset of data.
  ///
  /// The derived query shares the lifecycle and state of this query,
  /// but only updates its data when the selected value changes.
  ///
  /// **Important:** The returned query listens to the source query.
  /// You should dispose it when no longer needed to prevent memory leaks,
  /// especially if created inside a build method.
  ///
  /// Example:
  /// ```dart
  /// // In a controller
  /// late final nameQuery = userQuery.select((user) => user.name);
  ///
  /// @override
  /// void onClose() {
  ///   nameQuery.dispose();
  ///   super.onClose();
  /// }
  /// ```
  ZenQuery<R> select<R>(R Function(T data) selector) {
    return _SelectedZenQuery<T, R>(this, selector);
  }

  @override
  void onClose() {
    _isDisposed = true;
    _refetchTimer?.cancel();
    _refetchTimer = null;
    _currentFetch = null;

    // Unregister based on how it was registered
    if (_registerInCache) {
      if (scope != null) {
        final scopedKey = '${scope!.id}:$queryKey';
        ZenQueryCache.instance.unregister(scopedKey);
      } else {
        ZenQueryCache.instance.unregister(queryKey);
      }
    }

    // Dispose notifiers
    status.dispose();
    data.dispose();
    error.dispose();
    _isLoadingNotifier?.dispose();

    super.onClose();
  }

  @override
  String toString() {
    return 'ZenQuery<$T>(key: $queryKey, status: ${status.value}, hasData: $hasData, hasError: $hasError)';
  }
}

/// A specialized query that selects a subset of data from a source query.
class _SelectedZenQuery<T, R> extends ZenQuery<R> {
  final ZenQuery<T> source;
  final R Function(T) selector;
  final _workers = ZenWorkerGroup();

  _SelectedZenQuery(this.source, this.selector)
      : super(
          // Use a composite key to avoid collisions but keep traceability
          queryKey: '${source.queryKey}-select-${identityHashCode(selector)}',
          // Fetcher delegates to source
          fetcher: () async => selector(await source.fetch()),
          config: source.config,
          scope: source.scope,
          autoDispose: source.autoDispose,
          registerInCache: false,
        ) {
    _bindToSource();
  }

  void _bindToSource() {
    // Unified state update logic
    void update(_) => _computeState();

    _workers.add(ZenWorkers.ever(source.status, update));
    _workers.add(ZenWorkers.ever(source.data, update));
    _workers.add(ZenWorkers.ever(source.error, update));

    // Initial state computation
    _computeState();
  }

  void _computeState() {
    // 1. Propagate Loading (via status)
    if (source.status.value == ZenQueryStatus.loading) {
      if (status.value != ZenQueryStatus.loading) {
        status.value = ZenQueryStatus.loading;
      }
      return;
    }

    // 2. Propagate Error from parent
    if (source.status.value == ZenQueryStatus.error) {
      status.value = ZenQueryStatus.error;
      error.value = source.error.value;
      return;
    }

    // 3. Handle Success/Data
    if (source.data.value != null) {
      try {
        final selected = selector(source.data.value as T);

        // Only update if data actually changed (value equality)
        if (data.value != selected) {
          data.value = selected;
        }

        // Clear error if we recovered
        if (error.value != null) error.value = null;

        // Set success status
        if (status.value != ZenQueryStatus.success) {
          status.value = ZenQueryStatus.success;
        }
      } catch (e) {
        // Derivation error
        error.value = e;
        status.value = ZenQueryStatus.error;
      }
    } else {
      // No data (Idle or Success with null)
      if (status.value != source.status.value) {
        status.value = source.status.value;
      }
    }
  }

  @override
  RxBool get isLoading => source.isLoading;

  @override
  Future<R> fetch({bool force = false}) async {
    final parentData = await source.fetch(force: force);
    return selector(parentData);
  }

  @override
  Future<R> refetch() async {
    final parentData = await source.refetch();
    return selector(parentData);
  }

  @override
  void invalidate() {
    source.invalidate();
  }

  @override
  void onClose() {
    _workers.dispose();
    super.onClose();
  }
}
