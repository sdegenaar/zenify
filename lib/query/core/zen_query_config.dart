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
@immutable
class ZenQueryConfig<T> {
  /// How long data remains fresh
  final Duration? staleTime;

  /// How long inactive data remains in cache
  final Duration? cacheTime;

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

  /// Delay between retries
  final Duration retryDelay;

  /// Whether to use exponential backoff for retries
  final bool exponentialBackoff;

  // --- Persistence Configuration ---

  /// Whether to persist this query's data
  final bool persist;

  /// Function to convert JSON to data (for hydration)
  final T Function(Map<String, dynamic> json)? fromJson;

  /// Function to convert data to JSON (for persistence)
  final Map<String, dynamic> Function(T data)? toJson;

  /// Custom storage implementation (defaults to global storage if null)
  final ZenStorage? storage;

  const ZenQueryConfig({
    this.staleTime = const Duration(seconds: 30),
    this.cacheTime = const Duration(minutes: 5),
    this.refetchOnMount = true,
    this.refetchOnFocus = false,
    this.refetchOnReconnect = true,
    this.refetchInterval,
    this.enableBackgroundRefetch = false,
    this.retryCount = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.exponentialBackoff = true,
    this.persist = false,
    this.fromJson,
    this.toJson,
    this.storage,
  });

  /// Default configuration
  static const defaults = ZenQueryConfig();

  /// Merge with another config
  ZenQueryConfig<T> merge(ZenQueryConfig<T>? other) {
    if (other == null) return this;

    return ZenQueryConfig<T>(
      staleTime: other.staleTime ?? staleTime,
      cacheTime: other.cacheTime ?? cacheTime,
      refetchOnMount: other.refetchOnMount,
      refetchOnFocus: other.refetchOnFocus,
      refetchOnReconnect: other.refetchOnReconnect,
      refetchInterval: other.refetchInterval ?? refetchInterval,
      enableBackgroundRefetch: other.enableBackgroundRefetch,
      retryCount: other.retryCount,
      retryDelay: other.retryDelay,
      exponentialBackoff: other.exponentialBackoff,
      persist: other.persist,
      fromJson: other.fromJson ?? fromJson,
      toJson: other.toJson ?? toJson,
      storage: other.storage ?? storage,
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
      exponentialBackoff: exponentialBackoff,
      persist: persist,
      fromJson: fromJson != null ? (json) => fromJson!(json) as R : null,
      toJson: toJson != null ? (data) => toJson!(data as T) : null,
      storage: storage,
    );
  }
}
