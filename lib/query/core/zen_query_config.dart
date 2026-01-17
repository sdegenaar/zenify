import 'package:flutter/foundation.dart';

import 'package:zenify/query/core/zen_storage.dart';

/// Status of a ZenQuery
enum ZenQueryStatus {
  /// Query has not been executed yet
  idle,

  /// Query is currently fetching data
  loading,

  /// Query completed successfully
  success,

  /// Query failed with an error
  error,
}

/// Configuration for ZenQuery
///
/// Follows TanStack Query's pattern: all fields have concrete defaults,
/// and configuration is merged explicitly rather than using nullable fields.
@immutable
class ZenQueryConfig<T> {
  /// How long data remains fresh
  final Duration staleTime;

  /// How long inactive data remains in cache
  final Duration cacheTime;

  /// Whether to refetch when component mounts
  final bool refetchOnMount;

  /// Whether to refetch when window gains focus
  final bool refetchOnFocus;

  /// Whether to refetch when network reconnects
  final bool refetchOnReconnect;

  /// Interval for background refetching (null = disabled)
  final Duration? refetchInterval;

  /// Whether to enable background refetching
  final bool enableBackgroundRefetch;

  /// Number of retry attempts
  final int retryCount;

  /// Base delay between retries (e.g., 200ms)
  final Duration retryDelay;

  /// Maximum delay for retries (prevents infinite growth)
  final Duration maxRetryDelay;

  /// Multiplier for exponential backoff (default: 2.0)
  /// Delay formula: min(retryDelay * (multiplier ^ attempt), maxRetryDelay)
  final double retryBackoffMultiplier;

  /// Whether to use exponential backoff for retries
  final bool exponentialBackoff;

  /// Whether to add random jitter to retry delays (prevents thundering herd)
  final bool retryWithJitter;

  // --- Pause/Resume Configuration ---

  /// Whether to automatically pause queries when app goes to background
  ///
  /// When true, queries will automatically pause when the app lifecycle
  /// state changes to paused, inactive, or hidden. This is useful for
  /// mobile apps to save battery and reduce unnecessary network requests.
  ///
  /// For desktop/web apps where users frequently switch windows, consider
  /// keeping this false (default) to maintain query activity.
  ///
  /// Default: false (opt-in for battery optimization)
  final bool autoPauseOnBackground;

  /// Whether to refetch stale data when resuming from background
  ///
  /// When true, queries will automatically refetch if data is stale when
  /// the app returns to foreground. Works in conjunction with autoPauseOnBackground.
  ///
  /// Default: false (opt-in)
  final bool refetchOnResume;

  // --- Persistence Configuration ---

  /// Whether to persist this query's data
  final bool persist;

  /// Function to convert JSON to data (for hydration)
  final T Function(Map<String, dynamic> json)? fromJson;

  /// Function to convert data to JSON (for persistence)
  final Map<String, dynamic> Function(T data)? toJson;

  /// Custom storage implementation (defaults to global storage if null)
  final ZenStorage? storage;

  /// Placeholder data to show while the query is loading.
  /// This does not persist to cache.
  final T? placeholderData;

  const ZenQueryConfig({
    this.staleTime = const Duration(seconds: 30),
    this.cacheTime = const Duration(minutes: 5),
    this.refetchOnMount = true,
    this.refetchOnFocus = false,
    this.refetchOnReconnect = true,
    this.refetchInterval,
    this.enableBackgroundRefetch = false,
    this.retryCount = 3,
    this.retryDelay = const Duration(milliseconds: 200),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.retryBackoffMultiplier = 2.0,
    this.exponentialBackoff = true,
    this.retryWithJitter = true,
    this.autoPauseOnBackground = false,
    this.refetchOnResume = false,
    this.persist = false,
    this.fromJson,
    this.toJson,
    this.storage,
    this.placeholderData,
  });

  /// Standard library defaults
  static const defaults = ZenQueryConfig();

  /// Merge with another config (other's values take precedence)
  ZenQueryConfig<T> merge(ZenQueryConfig<T>? other) {
    if (other == null) return this;

    return ZenQueryConfig<T>(
      staleTime: other.staleTime,
      cacheTime: other.cacheTime,
      refetchOnMount: other.refetchOnMount,
      refetchOnFocus: other.refetchOnFocus,
      refetchOnReconnect: other.refetchOnReconnect,
      refetchInterval: other.refetchInterval ?? refetchInterval,
      enableBackgroundRefetch: other.enableBackgroundRefetch,
      retryCount: other.retryCount,
      retryDelay: other.retryDelay,
      maxRetryDelay: other.maxRetryDelay,
      retryBackoffMultiplier: other.retryBackoffMultiplier,
      exponentialBackoff: other.exponentialBackoff,
      retryWithJitter: other.retryWithJitter,
      autoPauseOnBackground: other.autoPauseOnBackground,
      refetchOnResume: other.refetchOnResume,
      persist: other.persist,
      fromJson: other.fromJson ?? fromJson,
      toJson: other.toJson ?? toJson,
      storage: other.storage ?? storage,
      placeholderData: other.placeholderData ?? placeholderData,
    );
  }

  /// Create a copy with specific fields overridden
  ///
  /// This provides a clean API for creating variants:
  /// ```dart
  /// final baseConfig = ZenQueryConfig(staleTime: Duration.zero);
  /// final withRetries = baseConfig.copyWith(retryCount: 5);
  /// ```
  ZenQueryConfig<T> copyWith({
    Duration? staleTime,
    Duration? cacheTime,
    bool? refetchOnMount,
    bool? refetchOnFocus,
    bool? refetchOnReconnect,
    Duration? refetchInterval,
    bool? enableBackgroundRefetch,
    int? retryCount,
    Duration? retryDelay,
    Duration? maxRetryDelay,
    double? retryBackoffMultiplier,
    bool? exponentialBackoff,
    bool? retryWithJitter,
    bool? autoPauseOnBackground,
    bool? refetchOnResume,
    bool? persist,
    T Function(Map<String, dynamic> json)? fromJson,
    Map<String, dynamic> Function(T data)? toJson,
    ZenStorage? storage,
    T? placeholderData,
  }) {
    return ZenQueryConfig<T>(
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      refetchOnFocus: refetchOnFocus ?? this.refetchOnFocus,
      refetchOnReconnect: refetchOnReconnect ?? this.refetchOnReconnect,
      refetchInterval: refetchInterval ?? this.refetchInterval,
      enableBackgroundRefetch:
          enableBackgroundRefetch ?? this.enableBackgroundRefetch,
      retryCount: retryCount ?? this.retryCount,
      retryDelay: retryDelay ?? this.retryDelay,
      maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
      retryBackoffMultiplier:
          retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      exponentialBackoff: exponentialBackoff ?? this.exponentialBackoff,
      retryWithJitter: retryWithJitter ?? this.retryWithJitter,
      autoPauseOnBackground:
          autoPauseOnBackground ?? this.autoPauseOnBackground,
      refetchOnResume: refetchOnResume ?? this.refetchOnResume,
      persist: persist ?? this.persist,
      fromJson: fromJson ?? this.fromJson,
      toJson: toJson ?? this.toJson,
      storage: storage ?? this.storage,
      placeholderData: placeholderData ?? this.placeholderData,
    );
  }

  /// Cast configuration to a new type
  ZenQueryConfig<R> cast<R>() {
    if (this is ZenQueryConfig<R>) {
      return this as ZenQueryConfig<R>;
    }
    return ZenQueryConfig<R>(
      staleTime: staleTime,
      cacheTime: cacheTime,
      refetchOnMount: refetchOnMount,
      refetchOnFocus: refetchOnFocus,
      refetchOnReconnect: refetchOnReconnect,
      refetchInterval: refetchInterval,
      enableBackgroundRefetch: enableBackgroundRefetch,
      retryCount: retryCount,
      retryDelay: retryDelay,
      maxRetryDelay: maxRetryDelay,
      retryBackoffMultiplier: retryBackoffMultiplier,
      exponentialBackoff: exponentialBackoff,
      retryWithJitter: retryWithJitter,
      autoPauseOnBackground: autoPauseOnBackground,
      refetchOnResume: refetchOnResume,
      persist: persist,
      fromJson: fromJson != null ? (json) => fromJson!(json) as R : null,
      toJson: toJson != null ? (data) => toJson!(data as T) : null,
      storage: storage,
      placeholderData: placeholderData as R?,
    );
  }
}
