import 'package:flutter/foundation.dart';
import 'zen_query_config.dart';

/// Client for managing query configuration and cache.
///
/// Inspired by TanStack Query's QueryClient pattern, this provides
/// a centralized place to configure default options for all queries.
///
/// ## Usage
///
/// ```dart
/// // Create client with default options
/// final queryClient = ZenQueryClient(
///   defaultOptions: ZenQueryClientOptions(
///     queries: ZenQueryConfig(
///       staleTime: Duration.zero,
///       retryCount: 1,
///     ),
///   ),
/// );
///
/// // Register with Zen DI
/// Zen.put(queryClient);
///
/// // Queries automatically use these defaults
/// final query = ZenQuery(
///   queryKey: 'users',
///   fetcher: (token) => api.getUsers(),
/// );
/// ```
@immutable
class ZenQueryClient {
  /// Default options for all queries
  final ZenQueryClientOptions defaultOptions;

  const ZenQueryClient({
    this.defaultOptions = const ZenQueryClientOptions(),
  });

  /// Get default options for queries
  ZenQueryConfig getQueryDefaults() {
    return defaultOptions.queries;
  }

  /// Resolve config for a specific query
  /// Merges: client defaults -> instance config
  ZenQueryConfig<T> resolveQueryConfig<T>(ZenQueryConfig? instanceConfig) {
    if (instanceConfig == null) {
      return defaultOptions.queries.cast<T>();
    }
    return defaultOptions.queries.merge(instanceConfig).cast<T>();
  }
}

/// Default options for ZenQueryClient
@immutable
class ZenQueryClientOptions {
  /// Default configuration for all queries
  final ZenQueryConfig queries;

  const ZenQueryClientOptions({
    this.queries = ZenQueryConfig.defaults,
  });
}
