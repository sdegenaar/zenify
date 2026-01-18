import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:zenify/query/core/query_key.dart';
import 'package:zenify/query/core/zen_cancel_token.dart';
import 'package:zenify/workers/zen_workers.dart';

import '../../controllers/zen_controller.dart';
import '../../core/zen_logger.dart';
import '../../core/zen_scope.dart';
import '../../reactive/core/rx_value.dart';
import '../../di/zen_di.dart';
import '../core/zen_query_cache.dart';
import '../core/zen_query_config.dart';
import '../core/zen_query_client.dart';
import '../core/zen_query_enums.dart';
import '../core/zen_exceptions.dart';
import '../../utils/zen_utils.dart';

/// Function signature for data fetching with cancellation support
typedef ZenQueryFetcher<T> = Future<T> Function(ZenCancelToken cancelToken);

/// A reactive query that manages async data fetching with caching and cancellation
///
/// Example:
/// ```dart
/// final userQuery = ZenQuery<User>(
///   queryKey: 'user:123',
///   fetcher: (token) => api.getUser(123, cancelToken: token),
///   config: ZenQueryConfig(
///     staleTime: Duration(minutes: 5),
///     retryCount: 3,
///   ),
/// );
/// ```
class ZenQuery<T> extends ZenController {
  /// Unique key for this query (used for caching and deduplication)
  final String queryKey;

  /// Function that fetches the data
  final ZenQueryFetcher<T> fetcher;

  /// Configuration for this query
  final ZenQueryConfig<T> config;

  /// Optional initial data
  final T? initialData;

  /// Optional scope - if provided, query will be tied to this scope
  final ZenScope? scope;

  /// Whether to automatically dispose when scope disposes
  final bool autoDispose;

  /// Whether the query is enabled to fetch data
  final RxBool enabled;

  /// Current status of the query
  final Rx<ZenQueryStatus> status = Rx(ZenQueryStatus.idle);

  /// Current network fetch status
  final Rx<ZenQueryFetchStatus> fetchStatus = Rx(ZenQueryFetchStatus.idle);

  /// Current data (null if not loaded yet)
  final Rx<T?> data = Rx(null);

  /// Current error (null if no error)
  final Rx<Object?> error = Rx(null);

  bool _isDisposed = false;

  /// Whether the current data is placeholder data
  final RxBool isPlaceholderData = RxBool(false);

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
    return DateTime.now().difference(_lastFetchTime!) > config.staleTime;
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

  /// Current cancellation token for the active request
  ZenCancelToken? _currentCancelToken;

  /// Resolve configuration using QueryClient pattern
  /// Priority: QueryClient defaults -> instance config
  static ZenQueryConfig<T> _resolveConfig<T>(ZenQueryConfig? instanceConfig) {
    try {
      // Try to get QueryClient from DI
      final client = Zen.findOrNull<ZenQueryClient>();
      if (client != null) {
        return client.resolveQueryConfig<T>(instanceConfig);
      }
    } catch (_) {
      // QueryClient not registered, use defaults
    }

    // Fallback to library defaults
    if (instanceConfig == null) {
      return ZenQueryConfig.defaults.cast<T>();
    }
    return ZenQueryConfig.defaults.merge(instanceConfig).cast<T>();
  }

  ZenQuery({
    required Object queryKey,
    required this.fetcher,
    ZenQueryConfig? config,
    this.initialData,
    this.scope,
    this.autoDispose = true,
    bool registerInCache = true,
    bool enabled = true,
  })  : queryKey = QueryKey.normalize(queryKey),
        config = _resolveConfig<T>(config),
        _registerInCache = registerInCache,
        enabled = RxBool(enabled) {
    // ⭐ AUTOMATIC CHILD CONTROLLER TRACKING
    // If a parent controller is currently initializing (onInit is running),
    // automatically register this query with it for automatic disposal
    if (ZenController.currentParentController != null) {
      ZenController.currentParentController!.trackController(this);
    }

    // Set initial data if provided
    if (initialData != null) {
      data.value = initialData;
      status.value = ZenQueryStatus.success;
      // Don't set _lastFetchTime here - initial data should be considered stale
      // so that the first fetch() actually fetches fresh data
      _lastFetchTime = null;
    } else if (this.config.placeholderData != null) {
      data.value = this.config.placeholderData;
      status.value = ZenQueryStatus.success;
      isPlaceholderData.value = true;
    }

    // Register in cache (scope-aware or global)
    if (_registerInCache) {
      if (scope != null) {
        _registerInScope();
      } else {
        ZenQueryCache.instance.register(this);
      }
    }

    // Setup background refetch if enabled
    _setupBackgroundRefetch();

    // Setup enabled listener
    ZenWorkers.ever(this.enabled, (isEnabled) {
      if (isEnabled && !_isDisposed) {
        // When re-enabled, fetch if stale or idle
        if (isStale || status.value == ZenQueryStatus.idle) {
          fetch().then((_) {}, onError: (_) {});
        }
      }
    });

    _initData();
  }

  /// Register query in scope with automatic cleanup
  void _registerInScope() {
    if (scope == null) return;

    final scopedKey = '${scope!.id}:$queryKey';
    ZenQueryCache.instance.registerScoped(this, scopedKey, scope!.id);

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
  Future<T> fetch({bool force = false}) async {
    // 1. Check enabled state (Priority 1)
    if (!enabled.value && !force) {
      if (hasData) return data.value!;
      return Future.error('Query is disabled');
    }

    // 2. Check Offline Status (Automatic Pause) (Priority 2)
    // If we are offline and mode is NOT 'always', we pause.
    final shouldPauseForNetwork = config.networkMode != NetworkMode.always &&
        !ZenQueryCache.instance.isOnline;

    if (shouldPauseForNetwork) {
      if (config.networkMode == NetworkMode.offlineFirst &&
          hasData &&
          !isStale) {
        return data.value!;
      }

      if (fetchStatus.value != ZenQueryFetchStatus.paused) {
        ZenLogger.logDebug('Query $queryKey paused (offline)');
        fetchStatus.value = ZenQueryFetchStatus.paused;
        update();
      }

      if (hasData) return data.value!;
      throw const ZenOfflineException('Query paused due to network connection');
    }

    // 3. Check Manual Pause (Sticky) (Priority 3)
    // If manually paused, stay paused unless forced (or network check overrode it)
    if (fetchStatus.value == ZenQueryFetchStatus.paused && !force) {
      if (hasData) return data.value!;
      return Future.error('Query is paused');
    }

    // 4. Return cached data if available and not stale
    if (!force && hasData && !isStale) {
      return data.value!;
    }

    // Deduplicate concurrent requests
    if (_currentFetch != null) {
      return _currentFetch!;
    }

    // Start fetch operation
    _currentFetch = performFetch();

    try {
      final result = await _currentFetch!;
      return result;
    } finally {
      _currentFetch = null;
    }
  }

  /// Perform the actual fetch with retry logic.
  /// Intended to be overridden by subclasses like ZenInfiniteQuery.
  @protected
  Future<T> performFetch() async {
    // Cancel previous pending request if any
    _cancelPendingRequest();

    _retryAttempt = 0;
    return _fetchWithRetry();
  }

  Future<T> _fetchWithRetry() async {
    if (_isDisposed) {
      throw StateError('Query has been disposed');
    }

    // Create new token for this attempt
    final token = ZenCancelToken('Refetching $queryKey');
    _currentCancelToken = token;

    // Update status to loading
    // Only set loading status if we don't have data (real or placeholder) to show
    if (!hasData && !isPlaceholderData.value) {
      status.value = ZenQueryStatus.loading;
    }
    _isLoadingNotifier?.value = true;
    // Set fetch status to fetching
    fetchStatus.value = ZenQueryFetchStatus.fetching;

    error.value = null;
    // Note: We do NOT clear isPlaceholderData here yet,
    // because if we have placeholder data, we want to keep showing it while loading
    update();

    try {
      // Execute fetcher with cancellation token
      final result = await fetcher(token);

      // If cancelled during await, don't update state
      if (token.isCancelled) {
        if (hasData) return data.value!;
        throw ZenCancellationException('Request cancelled');
      }
      if (_isDisposed) {
        throw StateError('Query was disposed during fetch');
      }

      // Update state: Success
      // Use structural sharing to prevent unnecessary rebuilds
      final optimizedData = ZenUtils.shareStructure(data.value, result);
      data.value = optimizedData;
      status.value = ZenQueryStatus.success;
      isPlaceholderData.value = false; // Real data arrived
      _isLoadingNotifier?.value = false;
      error.value = null;
      _lastFetchTime = DateTime.now();
      _retryAttempt = 0;
      fetchStatus.value = ZenQueryFetchStatus.idle;
      update();

      // Cache the result if caching is enabled
      if (_registerInCache) {
        ZenQueryCache.instance.updateCache(queryKey, result, _lastFetchTime!);
      }

      return result;
    } catch (e, s) {
      if (token.isCancelled || e is ZenCancellationException) {
        // If cancelled, we generally don't treat it as an error state
        if (hasData) return data.value!;
        rethrow;
      }

      if (_isDisposed) {
        throw StateError('Query was disposed during fetch');
      }

      // Check if should retry
      if (_retryAttempt < config.retryCount) {
        _retryAttempt++;

        ZenLogger.logDebug(
            'Query $queryKey failed, retrying ($_retryAttempt/${config.retryCount})');

        // Calculate retry delay with exponential backoff and jitter
        final delay = _calculateRetryDelay(_retryAttempt, e);

        await Future.delayed(delay);

        // Retry
        return _fetchWithRetry();
      }

      // No more retries, update with error
      ZenLogger.logError('Query failed: $queryKey', e, s);
      error.value = e;
      status.value = ZenQueryStatus.error;
      _isLoadingNotifier?.value = false;
      fetchStatus.value = ZenQueryFetchStatus.idle;
      update();

      rethrow;
    } finally {
      if (_currentCancelToken == token) {
        _currentCancelToken = null;
      }
    }
  }

  void _cancelPendingRequest() {
    if (_currentCancelToken != null && !_currentCancelToken!.isCancelled) {
      ZenLogger.logDebug('Cancelling pending request for $queryKey');
      _currentCancelToken!.cancel('Query disposed or new fetch started');
      _currentCancelToken = null;
      fetchStatus.value = ZenQueryFetchStatus.idle;
    }
  }

  /// Calculate retry delay with exponential backoff and optional jitter
  ///
  /// If `config.retryDelayFn` is provided, it will be used instead of the
  /// default exponential backoff calculation.
  ///
  /// Formula: min(baseDelay * (multiplier ^ (attempt - 1)), maxDelay) + jitter
  ///
  /// Example with defaults (baseDelay=200ms, multiplier=2.0, maxDelay=30s):
  /// - Attempt 1: 200ms
  /// - Attempt 2: 400ms
  /// - Attempt 3: 800ms
  /// - Attempt 4: 1600ms
  /// - Attempt 5: 3200ms
  /// - etc., capped at 30s
  Duration _calculateRetryDelay(int attempt, [Object? currentError]) {
    // Use custom function if provided
    if (config.retryDelayFn != null) {
      // Use the passed error, or fall back to stored error, or throw/default
      final err = currentError ?? error.value;
      if (err != null) {
        final delay = config.retryDelayFn!(attempt - 1, err);
        ZenLogger.logDebug(
          'Retry delay for attempt $attempt: ${delay.inMilliseconds}ms (custom function)',
        );
        return delay;
      }
    }

    if (!config.exponentialBackoff) {
      // Linear backoff - just use base delay
      return config.retryDelay;
    }

    // Exponential backoff calculation
    final baseMs = config.retryDelay.inMilliseconds;
    final multiplier = config.retryBackoffMultiplier;

    // Calculate: baseDelay * (multiplier ^ (attempt - 1))
    final exponentialMs = baseMs * pow(multiplier, attempt - 1);

    // Cap at max delay
    final cappedMs = min(
      exponentialMs,
      config.maxRetryDelay.inMilliseconds.toDouble(),
    );

    // Add jitter if enabled (±20% randomness to prevent thundering herd)
    var finalMs = cappedMs;
    if (config.retryWithJitter) {
      final jitterRange = cappedMs * 0.2; // 20% of the delay
      final jitter = jitterRange * (Random().nextDouble() - 0.5) * 2;
      finalMs = cappedMs + jitter;
    }

    final delay = Duration(milliseconds: finalMs.toInt());

    ZenLogger.logDebug(
      'Retry delay for attempt $attempt: ${delay.inMilliseconds}ms '
      '(exponential: ${config.exponentialBackoff}, jitter: ${config.retryWithJitter})',
    );

    return delay;
  }

  /// Helper to stop background refetch timer
  void _stopBackgroundRefetch() {
    _refetchTimer?.cancel();
    _refetchTimer = null;
  }

  /// Pause this query
  ///
  /// Pausing a query will:
  /// - Stop background refetch timers
  /// - Cancel any pending requests
  /// - Prevent new fetches (unless forced)
  ///
  /// This is useful for battery optimization when the app is backgrounded.
  void pause() {
    _cancelPendingRequest();
    _stopBackgroundRefetch();

    // Set status to paused
    if (fetchStatus.value != ZenQueryFetchStatus.paused) {
      fetchStatus.value = ZenQueryFetchStatus.paused;
      ZenLogger.logDebug('Query paused: $queryKey');
      update();
    }
  }

  /// Resume this query
  ///
  /// Resuming a query will:
  /// - Restart background refetch timers (if configured)
  /// - Refetch data if stale (if refetchOnResume is enabled)
  /// - Set fetchStatus to idle (so new fetches can happen)
  ///
  /// This is called automatically when the app returns to foreground.
  void resume() {
    if (fetchStatus.value == ZenQueryFetchStatus.paused) {
      fetchStatus.value = ZenQueryFetchStatus.idle;
      ZenLogger.logDebug('Query resumed: $queryKey');
      update();
    }

    // Restart background refetch if configured
    _setupBackgroundRefetch();

    // Refetch if data is stale and refetchOnResume is enabled
    if ((config.refetchOnResume) && isStale && enabled.value && !_isDisposed) {
      fetch().then(
        (_) {},
        onError: (error, stackTrace) {
          ZenLogger.logWarning(
            'ZenQuery resume refetch failed for query: $queryKey',
          );
        },
      );
    }

    ZenLogger.logDebug('Query resumed: $queryKey');
  }

  /// Manually set data (for optimistic updates)
  void setData(T newData) {
    // Use structural sharing
    data.value = ZenUtils.shareStructure(data.value, newData);
    isPlaceholderData.value = false; // Manual set implies real data
    if (status.value == ZenQueryStatus.idle) {
      status.value = ZenQueryStatus.success;
    }
    _lastFetchTime = DateTime.now();
    update();
  }

  /// Invalidate query (mark as stale and refetch if active)
  ///
  /// Marks the query data as stale and triggers an automatic refetch
  /// if the query is currently enabled and not already loading.
  ///
  /// This matches React Query's behavior where invalidating an active
  /// query causes it to refetch immediately.
  ///
  /// Example:
  /// ```dart
  /// // After a mutation, invalidate related queries
  /// createPostMutation.onSuccess = (_, __) {
  ///   postsQuery.invalidate(); // Automatically refetches
  /// };
  /// ```
  void invalidate() {
    _lastFetchTime = null;
    update();

    // Auto-refetch if query is active (enabled and not already loading)
    if (enabled.value && !isLoading.value && !_isDisposed) {
      fetch();
    }
  }

  /// Reset query to idle state
  void reset() {
    data.value = initialData;
    isPlaceholderData.value = false;
    error.value = null;
    status.value =
        initialData != null ? ZenQueryStatus.success : ZenQueryStatus.idle;
    _isLoadingNotifier?.value = false;
    fetchStatus.value = ZenQueryFetchStatus.idle;
    _lastFetchTime = initialData != null ? DateTime.now() : null;
    _retryAttempt = 0;
    _cancelPendingRequest();
    update();
  }

  /// Refetch data (force refresh)
  Future<T> refetch() => fetch(force: true);

  /// Setup automatic background refetching
  void _setupBackgroundRefetch() {
    final interval = config.refetchInterval;
    if (config.enableBackgroundRefetch && interval != null) {
      _refetchTimer?.cancel();

      // Don't create timers in test mode to avoid pending timer errors
      if (!ZenQueryCache.instance.useRealTimers) {
        return;
      }

      _refetchTimer = Timer.periodic(interval, (_) {
        if (hasData && !isLoading.value && !_isDisposed) {
          fetch(force: true).then(
            (_) {},
            onError: (error, stackTrace) {
              ZenLogger.logWarning(
                'ZenQuery background refetch failed for query: $queryKey',
              );
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
  ZenQuery<R> select<R>(R Function(T data) selector) {
    return _SelectedZenQuery<T, R>(this, selector);
  }

  Future<void> _initData() async {
    // 1. Check memory cache (sync)
    if (_registerInCache && data.value == null) {
      final cachedData = ZenQueryCache.instance.getCachedData<T>(queryKey);
      if (cachedData != null) {
        data.value = cachedData;
        status.value = ZenQueryStatus.success;
        isPlaceholderData.value = false;
        return; // Done
      }
    }

    // 1.5 Check Placeholder Data
    if (data.value == null && config.placeholderData != null) {
      data.value = config.placeholderData;
      status.value = ZenQueryStatus.success; // Treat as success so UI renders
      isPlaceholderData.value = true;
      // We still continue to step 2/3 to fetch real data
    }

    // 2. Try Hydration (async) if no data
    if (config.persist && data.value == null) {
      try {
        final hydratedData = await ZenQueryCache.instance.hydrate<T>(
          queryKey,
          config,
        );

        if (hydratedData != null && !_isDisposed) {
          data.value = ZenUtils.shareStructure(data.value, hydratedData);
          status.value = ZenQueryStatus.success;
          isPlaceholderData.value = false;
          _lastFetchTime = ZenQueryCache.instance.getTimestamp(queryKey);
          // If we found hydrated data, we might still want to fetch if stale,
          // but we shouldn't overwrite it with placeholder data.
        }
      } catch (e) {
        ZenLogger.logWarning('Hydration failed for $queryKey: $e');
      }
    }

    // 3. Auto-fetch on mount if enabled and configured
    if (enabled.value) {
      // If we have placeholder data, we definitely want to fetch real data
      if (hasData) {
        final shouldFetch = config.refetchOnMount
            .shouldRefetch(isStale || isPlaceholderData.value);
        if (shouldFetch) {
          fetch().then((_) {}, onError: (_) {});
        }
      } else {
        // No data yet - check if we should fetch
        if (config.refetchOnMount != RefetchBehavior.never) {
          fetch().then((_) {}, onError: (_) {});
        }
      }
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    _refetchTimer?.cancel();
    _refetchTimer = null;
    _currentFetch = null;

    // Cancel any pending request to prevent network waste
    _cancelPendingRequest();

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
    enabled.dispose();
    isPlaceholderData.dispose();
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
          fetcher: (token) async {
            // We can't easily pass token to parent fetcher as it might be running.
            // But we can await the parent result.
            final parentData = await source.fetch();
            return selector(parentData);
          },
          config: source.config,
          scope: source.scope,
          autoDispose: source.autoDispose,
          registerInCache: false,
          enabled: source.enabled.value,
        ) {
    _bindToSource();
  }

  void _bindToSource() {
    void update(_) => _computeState();

    _workers.add(ZenWorkers.ever(source.status, update));
    _workers.add(ZenWorkers.ever(source.data, update));
    _workers.add(ZenWorkers.ever(source.error, update));

    // Sync enabled state
    _workers.add(ZenWorkers.ever(source.enabled, (e) {
      if (enabled.value != e) enabled.value = e;
    }));

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
