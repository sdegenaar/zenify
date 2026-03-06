import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:zenify_devtools/src/models/query_cache_data.dart';

/// Service for interacting with ZenQuery cache via VM Service
class QueryCacheService {
  /// Fetch all query cache entries from the running app
  Future<List<QueryCacheData>> getQueries() async {
    try {
      final response = await serviceManager.service!.callServiceExtension(
        'ext.zenify.getQueries',
      );

      final queries = response.json!['queries'] as List;
      return queries
          .map((q) => QueryCacheData.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return mock data for development
      return _getMockQueries();
    }
  }

  /// Fetch query cache statistics
  Future<QueryCacheStats> getStats() async {
    try {
      final response = await serviceManager.service!.callServiceExtension(
        'ext.zenify.getQueryStats',
      );

      return QueryCacheStats.fromJson(
        response.json!['stats'] as Map<String, dynamic>,
      );
    } catch (e) {
      return const QueryCacheStats(
        totalQueries: 5,
        globalQueries: 3,
        scopedQueries: 2,
        activeScopes: 2,
        loadingQueries: 1,
        successQueries: 3,
        errorQueries: 1,
        staleQueries: 2,
      );
    }
  }

  /// Invalidate a specific query
  Future<void> invalidateQuery(String queryKey) async {
    try {
      await serviceManager.service!.callServiceExtension(
        'ext.zenify.invalidateQuery',
        args: {'queryKey': queryKey},
      );
    } catch (e) {
      // Silent failure for demo
    }
  }

  /// Refetch a specific query
  Future<void> refetchQuery(String queryKey) async {
    try {
      await serviceManager.service!.callServiceExtension(
        'ext.zenify.refetchQuery',
        args: {'queryKey': queryKey},
      );
    } catch (e) {
      // Silent failure for demo
    }
  }

  /// Clear all queries
  Future<void> clearAllQueries() async {
    try {
      await serviceManager.service!.callServiceExtension(
        'ext.zenify.clearQueries',
      );
    } catch (e) {
      // Silent failure for demo
    }
  }

  /// Mock data for development
  List<QueryCacheData> _getMockQueries() {
    return [
      QueryCacheData(
        queryKey: 'users',
        status: 'success',
        dataTimestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        lastFetch: DateTime.now().subtract(const Duration(minutes: 2)),
        isStale: false,
        isLoading: false,
        hasError: false,
        fetchCount: 3,
      ),
      QueryCacheData(
        queryKey: 'posts:user_123',
        status: 'loading',
        dataTimestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        lastFetch: DateTime.now(),
        isStale: true,
        isLoading: true,
        hasError: false,
        fetchCount: 1,
        scopeId: 'UserScope',
      ),
      QueryCacheData(
        queryKey: 'profile:user_456',
        status: 'error',
        dataTimestamp: DateTime.now().subtract(const Duration(hours: 1)),
        lastFetch: DateTime.now().subtract(const Duration(seconds: 30)),
        isStale: true,
        isLoading: false,
        hasError: true,
        errorMessage: 'Network timeout',
        fetchCount: 5,
      ),
      QueryCacheData(
        queryKey: 'settings',
        status: 'success',
        dataTimestamp: DateTime.now().subtract(const Duration(days: 1)),
        lastFetch: DateTime.now().subtract(const Duration(days: 1)),
        isStale: true,
        isLoading: false,
        hasError: false,
        fetchCount: 1,
      ),
      QueryCacheData(
        queryKey: 'notifications',
        status: 'success',
        dataTimestamp: DateTime.now().subtract(const Duration(seconds: 30)),
        lastFetch: DateTime.now().subtract(const Duration(seconds: 30)),
        isStale: false,
        isLoading: false,
        hasError: false,
        fetchCount: 12,
        scopeId: 'DashboardScope',
      ),
    ];
  }
}
