import 'dart:async';
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

  ZenQuery({
    required this.queryKey,
    required this.fetcher,
    ZenQueryConfig? config,
    this.initialData,
    this.scope,
    this.autoDispose = true,
  }) : config = ZenQueryConfig.defaults.merge(config) {
    // Set initial data if provided
    if (initialData != null) {
      data.value = initialData;
      status.value = ZenQueryStatus.success;
      // Don't set _lastFetchTime here - initial data should be considered stale
      // so that the first fetch() actually fetches fresh data
      _lastFetchTime = null;
    }

    // Register in cache (scope-aware or global)
    if (scope != null) {
      _registerInScope();
    } else {
      // Register in global cache (existing behavior)
      ZenQueryCache.instance.register(this);
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

      // Cache the result
      ZenQueryCache.instance.updateCache(queryKey, result, _lastFetchTime!);

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

  @override
  @override
  void onClose() {
    _isDisposed = true;
    _refetchTimer?.cancel();
    _refetchTimer = null;
    _currentFetch = null;

    // Unregister based on how it was registered
    if (scope != null) {
      final scopedKey = '${scope!.id}:$queryKey';
      ZenQueryCache.instance.unregister(scopedKey);
    } else {
      ZenQueryCache.instance.unregister(queryKey);
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
