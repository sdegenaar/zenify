/// Query-related enums and extensions for ZenQuery
library;

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

/// Status of a ZenMutation
enum ZenMutationStatus {
  /// Mutation has not been executed yet
  idle,

  /// Mutation is currently running
  loading,

  /// Mutation completed successfully
  success,

  /// Mutation failed with an error
  error,
}

/// Status of the network request for a query
///
/// Separates the "network state" from the "data state" (ZenQueryStatus).
enum ZenQueryFetchStatus {
  /// Query is not currently fetching
  idle,

  /// Query is currently fetching via network
  fetching,

  /// Query wanted to fetch but is paused (e.g., no network connection)
  paused,
}

/// Refetch behavior for queries
///
/// Matches TanStack Query's refetch modes for full semantic parity.
enum RefetchBehavior {
  /// Never refetch (disabled)
  never,

  /// Refetch only if data is stale (default)
  ifStale,

  /// Always refetch, regardless of staleness
  /// Useful for critical data that must always be fresh (e.g., financial data)
  always,
}

/// Extension methods for RefetchBehavior
extension RefetchBehaviorX on RefetchBehavior {
  /// Check if refetch should occur given staleness
  bool shouldRefetch(bool isStale) {
    switch (this) {
      case RefetchBehavior.never:
        return false;
      case RefetchBehavior.ifStale:
        return isStale;
      case RefetchBehavior.always:
        return true;
    }
  }
}

/// Function signature for dynamic retry delay calculation
///
/// Receives the current retry attempt (0-indexed) and the error that occurred.
/// Returns the duration to wait before the next retry attempt.
///
/// **Example:**
/// ```dart
/// // Custom delay based on error type
/// retryDelayFn: (attempt, error) {
///   if (error is RateLimitException) {
///     return Duration(seconds: 60); // Wait 1 minute for rate limits
///   }
///   return Duration(milliseconds: 200 * (attempt + 1)); // Linear backoff
/// }
/// ```
typedef RetryDelayFn = Duration Function(int attempt, Object error);

/// Network usage mode
///
/// Determines how queries behave based on network connectivity.
enum NetworkMode {
  /// Default. Fetches require network connection.
  /// If offline, queries will pause and wait for connection.
  online,

  /// Always fetch, regardless of network status.
  /// Useful for localhost or internal networks not detected by standard connectivity checks.
  always,

  /// Offline first. Return cache if available.
  /// If cache is missing, pause and wait for connection.
  offlineFirst,
}
