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

/// Configuration for a ZenQuery
class ZenQueryConfig {
  /// How long data is considered fresh (no refetch needed)
  final Duration? staleTime;

  /// How long to keep unused data in cache
  final Duration? cacheTime;

  /// Whether to refetch when query is mounted
  final bool refetchOnMount;

  /// Whether to refetch when window regains focus
  final bool refetchOnFocus;

  /// Whether to refetch on network reconnection
  final bool refetchOnReconnect;

  /// Number of retry attempts on failure
  final int retryCount;

  /// Delay between retry attempts
  final Duration retryDelay;

  /// Whether to use exponential backoff for retries
  final bool exponentialBackoff;

  /// Whether to enable automatic background refetching
  final bool enableBackgroundRefetch;

  /// Interval for background refetching (null = disabled)
  final Duration? refetchInterval;

  const ZenQueryConfig({
    this.staleTime = const Duration(seconds: 30),
    this.cacheTime = const Duration(minutes: 5),
    this.refetchOnMount = true,
    this.refetchOnFocus = false,
    this.refetchOnReconnect = true,
    this.retryCount = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.exponentialBackoff = true,
    this.enableBackgroundRefetch = true,
    this.refetchInterval,
  });

  /// Default configuration for all queries
  static const ZenQueryConfig defaults = ZenQueryConfig();

  /// Merge with another config (other takes precedence)
  ZenQueryConfig merge(ZenQueryConfig? other) {
    if (other == null) return this;
    return ZenQueryConfig(
      staleTime: other.staleTime ?? staleTime,
      cacheTime: other.cacheTime ?? cacheTime,
      refetchOnMount: other.refetchOnMount,
      refetchOnFocus: other.refetchOnFocus,
      refetchOnReconnect: other.refetchOnReconnect,
      retryCount: other.retryCount,
      retryDelay: other.retryDelay,
      exponentialBackoff: other.exponentialBackoff,
      enableBackgroundRefetch: other.enableBackgroundRefetch,
      refetchInterval: other.refetchInterval ?? refetchInterval,
    );
  }
}
