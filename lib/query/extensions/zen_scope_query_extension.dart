import 'package:zenify/query/logic/zen_query.dart';

import '../../core/zen_scope.dart';
import '../core/zen_query_config.dart';

/// Extension methods for ZenScope to simplify scoped query registration.
///
/// These methods combine query creation and scope registration in a single call,
/// reducing boilerplate and preventing common mistakes like forgetting to register
/// the query or passing the wrong scope.
///
/// Example usage in a module:
/// ```dart
/// class ProductModule extends ZenModule {
///   final String productId;
///
///   ProductModule(this.productId);
///
///   @override
///   void register(ZenScope scope) {
///     // Register scoped query - auto-disposes when scope disposes
///     scope.putQuery<Product>(
///       queryKey: 'product:$productId',
///       fetcher: (_) => api.getProduct(productId), // Updated signature
///     );
///
///     // Or use the cached variant with sensible defaults
///     scope.putCachedQuery<List<Review>>(
///       queryKey: 'reviews:$productId',
///       fetcher: (_) => api.getReviews(productId), // Updated signature
///       staleTime: Duration(minutes: 10), // Optional: override default
///     );
///   }
/// }
/// ```
extension ZenScopeQueryExtension on ZenScope {
  /// Register a scoped query with automatic lifecycle management.
  ///
  /// This method creates a [ZenQuery] tied to this scope and automatically
  /// registers it. The query will be disposed when the scope is disposed,
  /// preventing memory leaks.
  ///
  /// **Parameters:**
  /// - [queryKey]: Unique identifier for the query (used for caching and deduplication)
  /// - [fetcher]: Async function that fetches the data (receives cancel token)
  /// - [config]: Optional configuration for cache behavior, retries, etc.
  /// - [initialData]: Optional initial data to show before first fetch
  ///
  /// **Returns:** The created [ZenQuery] instance for further customization
  ///
  /// **Example:**
  /// ```dart
  /// final query = scope.putQuery<User>(
  ///   queryKey: 'user:123',
  ///   fetcher: (token) => api.getUser(123, cancelToken: token),
  ///   config: ZenQueryConfig(
  ///     staleTime: Duration(minutes: 5),
  ///     retryCount: 3,
  ///   ),
  /// );
  /// ```
  ///
  /// **Benefits:**
  /// - ✅ Automatic scope binding (no manual `scope: this` needed)
  /// - ✅ Automatic registration (no separate `scope.put()` call)
  /// - ✅ Auto-disposal when scope disposes (prevents memory leaks)
  /// - ✅ Consistent with `scope.put()` / `scope.putLazy()` API pattern
  ///
  /// See also:
  /// - [putCachedQuery] for common caching patterns
  /// - [ZenQuery] for full query documentation
  ZenQuery<T> putQuery<T>({
    required Object queryKey,
    // CHANGED: Now accepts a ZenQueryFetcher (takes cancelToken)
    required ZenQueryFetcher<T> fetcher,
    ZenQueryConfig? config,
    T? initialData,
  }) {
    final query = ZenQuery<T>(
      queryKey: queryKey,
      fetcher: fetcher,
      config: config,
      initialData: initialData,
      scope: this, // Automatically scoped
    );
    put(query); // Automatically registered
    return query;
  }

  /// Register a scoped query with common caching defaults.
  ///
  /// This is a convenience method that provides sensible defaults for
  /// cached data. It's equivalent to [putQuery] with a pre-configured
  /// [ZenQueryConfig] that sets the stale time.
  ///
  /// **Parameters:**
  /// - [queryKey]: Unique identifier for the query
  /// - [fetcher]: Async function that fetches the data
  /// - [staleTime]: How long data is considered fresh (default: 5 minutes)
  /// - [initialData]: Optional initial data to show before first fetch
  ///
  /// **Returns:** The created [ZenQuery] instance
  ///
  /// **Example:**
  /// ```dart
  /// // Data stays fresh for 5 minutes (default)
  /// scope.putCachedQuery<Product>(
  ///   queryKey: 'product:$id',
  ///   fetcher: (_) => api.getProduct(id),
  /// );
  ///
  /// // Custom stale time for real-time data
  /// scope.putCachedQuery<StockPrice>(
  ///   queryKey: 'stock:AAPL',
  ///   fetcher: (_) => api.getStockPrice('AAPL'),
  ///   staleTime: Duration(seconds: 30), // Refresh more frequently
  /// );
  /// ```
  ///
  /// **When to use:**
  /// - ✅ Standard CRUD operations (user profiles, product details, etc.)
  /// - ✅ Data that doesn't change frequently
  /// - ✅ You want sensible caching without configuration
  ///
  /// **When to use [putQuery] instead:**
  /// - ❌ You need more control (custom retry logic, background refetch, etc.)
  /// - ❌ Data changes frequently and needs shorter stale time
  /// - ❌ You want different cache vs stale time settings
  ///
  /// See also: [putQuery] for full configuration options
  ZenQuery<T> putCachedQuery<T>({
    required Object queryKey,
    // CHANGED: Now accepts a ZenQueryFetcher (takes cancelToken)
    required ZenQueryFetcher<T> fetcher,
    Duration staleTime = const Duration(minutes: 5),
    T? initialData,
  }) {
    return putQuery<T>(
      queryKey: queryKey,
      fetcher: fetcher,
      config: ZenQueryConfig(staleTime: staleTime),
      initialData: initialData,
    );
  }
}
