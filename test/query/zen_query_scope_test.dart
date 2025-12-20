import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    // Use test mode - automatically configures cache and clears it
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQuery Scope Integration', () {
    test('query without scope registers globally', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-global',
        fetcher: (_) async => 'global-data',
      );

      await query.fetch();

      expect(query.hasData, true);
      expect(query.data.value, 'global-data');

      final stats = ZenQueryCache.instance.getStats();
      expect(stats['global_queries'], 1);
      expect(stats['scoped_queries'], 0);

      query.dispose();
    });

    test('query with scope registers in scope', () async {
      final scope = ZenScope(name: 'TestScope');

      final query = ZenQuery<String>(
        queryKey: 'test-scoped',
        fetcher: (_) async => 'scoped-data',
        scope: scope,
      );

      await query.fetch();

      expect(query.hasData, true);
      expect(query.data.value, 'scoped-data');

      final scopeQueries = ZenQueryCache.instance.getScopeQueries(scope.id);
      expect(scopeQueries.length, 1);
      expect(scopeQueries.first.queryKey, 'test-scoped');

      scope.dispose();
    });

    test('scoped query auto-disposes with scope', () async {
      final scope = ZenScope(name: 'TestScope');

      final query = ZenQuery<String>(
        queryKey: 'test-auto-dispose',
        fetcher: (_) async => 'data',
        scope: scope,
        autoDispose: true,
      );

      await query.fetch();
      expect(query.isDisposed, false);

      // Dispose the scope
      scope.dispose();

      // Query should be auto-disposed
      expect(query.isDisposed, true);
    });

    test('scoped query with autoDispose=false survives scope disposal',
        () async {
      final scope = ZenScope(name: 'TestScope');

      final query = ZenQuery<String>(
        queryKey: 'test-no-auto-dispose',
        fetcher: (_) async => 'data',
        scope: scope,
        autoDispose: false,
      );

      await query.fetch();
      expect(query.isDisposed, false);

      // Dispose the scope
      scope.dispose();

      // Query should still be alive
      expect(query.isDisposed, false);

      // Manual cleanup
      query.dispose();
    });

    test('invalidateScope invalidates all scope queries', () async {
      final scope = ZenScope(name: 'TestScope');

      final query1 = ZenQuery<String>(
        queryKey: 'query1',
        fetcher: (_) async => 'data1',
        scope: scope,
        config: ZenQueryConfig(staleTime: const Duration(hours: 1)),
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: (_) async => 'data2',
        scope: scope,
        config: ZenQueryConfig(staleTime: const Duration(hours: 1)),
      );

      await Future.wait([query1.fetch(), query2.fetch()]);

      expect(query1.isStale, false);
      expect(query2.isStale, false);

      // Invalidate all queries in scope
      ZenQueryCache.instance.invalidateScope(scope.id);

      expect(query1.isStale, true);
      expect(query2.isStale, true);

      scope.dispose();
    });

    test('clearScope removes all scope queries from cache', () async {
      final scope = ZenScope(name: 'TestScope');

      final query1 = ZenQuery<String>(
        queryKey: 'query1',
        fetcher: (_) async => 'data1',
        scope: scope,
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: (_) async => 'data2',
        scope: scope,
      );

      await Future.wait([query1.fetch(), query2.fetch()]);

      var scopeQueries = ZenQueryCache.instance.getScopeQueries(scope.id);
      expect(scopeQueries.length, 2);

      // Clear the scope
      ZenQueryCache.instance.clearScope(scope.id);

      scopeQueries = ZenQueryCache.instance.getScopeQueries(scope.id);
      expect(scopeQueries.length, 0);

      scope.dispose();
    });

    test('getScopeStats returns correct statistics', () async {
      final scope = ZenScope(name: 'TestScope');

      final query1 = ZenQuery<String>(
        queryKey: 'query1',
        fetcher: (_) async => 'data1',
        scope: scope,
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: (_) async => throw Exception('error'),
        scope: scope,
      );

      await query1.fetch();

      // Use try-catch instead of catchError
      try {
        await query2.fetch();
      } catch (_) {
        // Expected error - query2 should be in error state
      }

      final stats = ZenQueryCache.instance.getScopeStats(scope.id);

      expect(stats['total'], 2);
      expect(stats['success'], 1);
      expect(stats['error'], 1);

      scope.dispose();
    });

    test('module integration - queries tied to module scope', () async {
      final scope = ZenScope(name: 'ModuleScope');

      // Simulate module registration
      final productQuery = ZenQuery<String>(
        queryKey: 'product:123',
        fetcher: (_) async => 'Product 123',
        scope: scope,
      );

      scope.put(productQuery);

      await productQuery.fetch();
      expect(productQuery.hasData, true);

      // Dispose module scope
      scope.dispose();

      // Query should be auto-disposed
      expect(productQuery.isDisposed, true);
    });

    test('refetchScope refetches all queries in scope', () async {
      final scope = ZenScope(name: 'TestScope');

      int fetchCount1 = 0;
      int fetchCount2 = 0;

      final query1 = ZenQuery<String>(
        queryKey: 'query1',
        fetcher: (_) async {
          await Future.delayed(const Duration(milliseconds: 10));
          fetchCount1++;
          return 'data1-$fetchCount1';
        },
        scope: scope,
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: (_) async {
          await Future.delayed(const Duration(milliseconds: 10));
          fetchCount2++;
          return 'data2-$fetchCount2';
        },
        scope: scope,
      );

      // Initial fetch
      await Future.wait([query1.fetch(), query2.fetch()]);

      expect(query1.data.value, 'data1-1');
      expect(query2.data.value, 'data2-1');
      expect(fetchCount1, 1);
      expect(fetchCount2, 1);

      // Refetch all queries in scope - this waits for completion
      await ZenQueryCache.instance.refetchScope(scope.id);

      // Verify refetch happened
      expect(query1.data.value, 'data1-2');
      expect(query2.data.value, 'data2-2');
      expect(fetchCount1, 2);
      expect(fetchCount2, 2);

      scope.dispose();
    });

    test('hierarchical scopes - child scope queries independent from parent',
        () async {
      final parentScope = ZenScope(name: 'ParentScope');
      final childScope = parentScope.createChild(name: 'ChildScope');

      final parentQuery = ZenQuery<String>(
        queryKey: 'parent-query',
        fetcher: (_) async => 'parent-data',
        scope: parentScope,
      );

      final childQuery = ZenQuery<String>(
        queryKey: 'child-query',
        fetcher: (_) async => 'child-data',
        scope: childScope,
      );

      await Future.wait([parentQuery.fetch(), childQuery.fetch()]);

      var parentQueries =
          ZenQueryCache.instance.getScopeQueries(parentScope.id);
      var childQueries = ZenQueryCache.instance.getScopeQueries(childScope.id);

      expect(parentQueries.length, 1);
      expect(childQueries.length, 1);

      // Dispose child scope
      childScope.dispose();

      // Child query should be disposed, parent should remain
      expect(childQuery.isDisposed, true);
      expect(parentQuery.isDisposed, false);

      parentScope.dispose();
    });

    test('cache stats correctly differentiate global and scoped queries',
        () async {
      final scope = ZenScope(name: 'TestScope');

      // Global query
      final globalQuery = ZenQuery<String>(
        queryKey: 'global',
        fetcher: (_) async => 'global-data',
      );

      // Scoped query
      final scopedQuery = ZenQuery<String>(
        queryKey: 'scoped',
        fetcher: (_) async => 'scoped-data',
        scope: scope,
      );

      await Future.wait([globalQuery.fetch(), scopedQuery.fetch()]);

      final stats = ZenQueryCache.instance.getStats();

      expect(stats['total_queries'], 2);
      expect(stats['global_queries'], 1);
      expect(stats['scoped_queries'], 1);
      expect(stats['active_scopes'], 1);

      scope.dispose();
      globalQuery.dispose();
    });
  });

  group('ZenScopeQueryExtension', () {
    test('putQuery creates and registers scoped query in one call', () async {
      final scope = ZenScope(name: 'TestScope');

      // Use the extension method
      final query = scope.putQuery<String>(
        queryKey: 'test-query',
        fetcher: (_) async => 'test-data',
      );

      // Verify query was created and registered
      expect(query, isNotNull);
      expect(query.queryKey, 'test-query');
      expect(query.scope, scope);

      // Fetch data
      await query.fetch();
      expect(query.data.value, 'test-data');
      expect(query.hasData, true);

      // Verify it's tracked in the scope
      final scopeQueries = ZenQueryCache.instance.getScopeQueries(scope.id);
      expect(scopeQueries.length, 1);
      expect(scopeQueries.first, query);

      scope.dispose();
    });

    test('putQuery with config applies configuration correctly', () async {
      final scope = ZenScope(name: 'TestScope');

      final query = scope.putQuery<String>(
        queryKey: 'configured-query',
        fetcher: (_) async => 'data',
        config: ZenQueryConfig(
          staleTime: Duration(hours: 1),
          retryCount: 5,
        ),
      );

      expect(query.config.staleTime, Duration(hours: 1));
      expect(query.config.retryCount, 5);

      scope.dispose();
    });

    test('putQuery with initialData sets initial state correctly', () {
      final scope = ZenScope(name: 'TestScope');

      final query = scope.putQuery<String>(
        queryKey: 'initial-data-query',
        fetcher: (_) async => 'fetched-data',
        initialData: 'initial-data',
        // Disable refetchOnMount to prevent immediate loading state transition
        // This ensures we are testing strictly the "initial" state application
        config: ZenQueryConfig(refetchOnMount: false),
      );

      expect(query.data.value, 'initial-data');
      expect(query.status.value, ZenQueryStatus.success);
      expect(query.hasData, true);

      scope.dispose();
    });

    test('putCachedQuery applies default caching configuration', () async {
      final scope = ZenScope(name: 'TestScope');

      final query = scope.putCachedQuery<String>(
        queryKey: 'cached-query',
        fetcher: (_) async => 'cached-data',
      );

      // Verify default staleTime is applied
      expect(query.config.staleTime, Duration(minutes: 5));

      await query.fetch();
      expect(query.data.value, 'cached-data');

      scope.dispose();
    });

    test('putCachedQuery with custom staleTime overrides default', () {
      final scope = ZenScope(name: 'TestScope');

      final query = scope.putCachedQuery<String>(
        queryKey: 'custom-cached-query',
        fetcher: (_) async => 'data',
        staleTime: Duration(minutes: 10),
      );

      expect(query.config.staleTime, Duration(minutes: 10));

      scope.dispose();
    });

    test('putQuery auto-disposes with scope by default', () async {
      final scope = ZenScope(name: 'TestScope');

      final query = scope.putQuery<String>(
        queryKey: 'auto-dispose-query',
        fetcher: (_) async => 'data',
      );

      await query.fetch();
      expect(query.isDisposed, false);

      // Dispose scope
      scope.dispose();

      // Query should auto-dispose
      expect(query.isDisposed, true);
    });

    test('multiple queries can be created with putQuery in same scope',
        () async {
      final scope = ZenScope(name: 'TestScope');

      final query1 = scope.putQuery<String>(
        queryKey: 'query1',
        fetcher: (_) async => 'data1',
      );

      final query2 = scope.putQuery<int>(
        queryKey: 'query2',
        fetcher: (_) async => 42,
      );

      final query3 = scope.putCachedQuery<bool>(
        queryKey: 'query3',
        fetcher: (_) async => true,
      );

      await Future.wait([
        query1.fetch(),
        query2.fetch(),
        query3.fetch(),
      ]);

      expect(query1.data.value, 'data1');
      expect(query2.data.value, 42);
      expect(query3.data.value, true);

      // All should be tracked in scope
      final scopeQueries = ZenQueryCache.instance.getScopeQueries(scope.id);
      expect(scopeQueries.length, 3);

      scope.dispose();
    });

    test('putQuery returns query for further customization', () async {
      final scope = ZenScope(name: 'TestScope');

      final query = scope.putQuery<String>(
        queryKey: 'customizable-query',
        fetcher: (_) async => 'original',
      );

      // Can use returned query for operations
      await query.fetch();
      expect(query.data.value, 'original');

      // Optimistic update
      query.setData('updated');
      expect(query.data.value, 'updated');

      scope.dispose();
    });
  });

  group('Shared Query Pattern - Module-based Registration', () {
    test('should share query across multiple controllers via Zen.find',
        () async {
      final scope = ZenScope(name: 'FeatureScope');

      // Simulate module registration pattern
      final sharedQuery = scope.putQuery<String>(
        queryKey: 'shared-user-data',
        fetcher: (_) async => 'Shared User',
        config: ZenQueryConfig(staleTime: Duration(minutes: 5)),
      );

      // Fetch initial data
      await sharedQuery.fetch();
      expect(sharedQuery.data.value, 'Shared User');

      // Register query in DI so controllers can find it
      scope.put<ZenQuery<String>>(sharedQuery, tag: 'user-query');

      // Simulate Controller 1 accessing the shared query
      final controller1Query = scope.find<ZenQuery<String>>(tag: 'user-query');
      expect(controller1Query, same(sharedQuery));
      expect(controller1Query?.data.value, 'Shared User');

      // Simulate Controller 2 accessing the same query
      final controller2Query = scope.find<ZenQuery<String>>(tag: 'user-query');
      expect(controller2Query, same(sharedQuery));
      expect(controller2Query, same(controller1Query));

      // All controllers share the same query instance
      expect(controller2Query?.data.value, 'Shared User');

      // Dispose scope - shared query should be disposed
      scope.dispose();
      expect(sharedQuery.isDisposed, isTrue);
    });

    test('should dispose shared query when scope disposes', () async {
      final scope = ZenScope(name: 'FeatureScope');

      // Create shared query via module pattern
      final sharedQuery = scope.putQuery<Map<String, dynamic>>(
        queryKey: 'shared-config',
        fetcher: (_) async => {'theme': 'dark', 'language': 'en'},
      );

      await sharedQuery.fetch();

      // putQuery already registers it, so we can access it directly
      // Multiple controllers would use sharedQuery directly or find it via scope
      expect(sharedQuery.isDisposed, isFalse);

      // Dispose scope
      scope.dispose();

      // Shared query should be disposed
      expect(sharedQuery.isDisposed, isTrue);
    });

    test('should handle multiple shared queries in module', () async {
      final scope = ZenScope(name: 'FeatureModule');

      // Module registers multiple shared queries
      final userQuery = scope.putQuery<String>(
        queryKey: 'module:user',
        fetcher: (_) async => 'Module User',
      );

      final settingsQuery = scope.putQuery<Map<String, dynamic>>(
        queryKey: 'module:settings',
        fetcher: (_) async => {'setting1': 'value1'},
      );

      final postsQuery = scope.putQuery<List<String>>(
        queryKey: 'module:posts',
        fetcher: (_) async => ['Post 1', 'Post 2'],
      );

      // Register all in DI
      scope.put<ZenQuery<String>>(userQuery, tag: 'user');
      scope.put<ZenQuery<Map<String, dynamic>>>(settingsQuery, tag: 'settings');
      scope.put<ZenQuery<List<String>>>(postsQuery, tag: 'posts');

      // Fetch all
      await Future.wait([
        userQuery.fetch(),
        settingsQuery.fetch(),
        postsQuery.fetch(),
      ]);

      // Controllers can access all shared queries
      final foundUser = scope.find<ZenQuery<String>>(tag: 'user');
      final foundSettings =
          scope.find<ZenQuery<Map<String, dynamic>>>(tag: 'settings');
      final foundPosts = scope.find<ZenQuery<List<String>>>(tag: 'posts');

      expect(foundUser, same(userQuery));
      expect(foundSettings, same(settingsQuery));
      expect(foundPosts, same(postsQuery));

      // All queries alive
      expect(userQuery.isDisposed, isFalse);
      expect(settingsQuery.isDisposed, isFalse);
      expect(postsQuery.isDisposed, isFalse);

      // Dispose scope
      scope.dispose();

      // All queries should be disposed
      expect(userQuery.isDisposed, isTrue);
      expect(settingsQuery.isDisposed, isTrue);
      expect(postsQuery.isDisposed, isTrue);
    });

    test('should support hierarchical module pattern with shared queries',
        () async {
      final appScope = ZenScope(name: 'AppScope');
      final featureScope = appScope.createChild(name: 'FeatureScope');

      // App-level shared query
      final appQuery = appScope.putQuery<String>(
        queryKey: 'app:user',
        fetcher: (_) async => 'App User',
      );
      appScope.put<ZenQuery<String>>(appQuery, tag: 'app-user');

      // Feature-level shared query
      final featureQuery = featureScope.putQuery<String>(
        queryKey: 'feature:data',
        fetcher: (_) async => 'Feature Data',
      );
      featureScope.put<ZenQuery<String>>(featureQuery, tag: 'feature-data');

      await Future.wait([appQuery.fetch(), featureQuery.fetch()]);

      // Feature scope can access both queries (hierarchical lookup)
      final foundApp = featureScope.find<ZenQuery<String>>(tag: 'app-user');
      final foundFeature =
          featureScope.find<ZenQuery<String>>(tag: 'feature-data');

      expect(foundApp, same(appQuery));
      expect(foundFeature, same(featureQuery));

      // Dispose only feature scope
      featureScope.dispose();

      // Feature query disposed, app query still alive
      expect(featureQuery.isDisposed, isTrue);
      expect(appQuery.isDisposed, isFalse);

      // Clean up
      appScope.dispose();
      expect(appQuery.isDisposed, isTrue);
    });

    test('should handle controllers and shared queries together', () async {
      final scope = ZenScope(name: 'FeatureScope');

      // Module registers shared query
      final sharedQuery = scope.putQuery<String>(
        queryKey: 'shared:data',
        fetcher: (_) async => 'Shared Data',
      );
      scope.put<ZenQuery<String>>(sharedQuery, tag: 'shared');

      // Create controllers that use the shared query
      final controller1 = _TestControllerUsingSharedQuery(scope, 'shared');
      final controller2 = _TestControllerUsingSharedQuery(scope, 'shared');

      scope.put(controller1, tag: 'controller1');
      scope.put(controller2, tag: 'controller2');

      controller1.onInit();
      controller2.onInit();

      // Both controllers should reference the same query
      expect(controller1.sharedQuery, same(sharedQuery));
      expect(controller2.sharedQuery, same(sharedQuery));
      expect(controller1.sharedQuery, same(controller2.sharedQuery));

      // Dispose scope
      scope.dispose();

      // Controllers and shared query should all be disposed
      expect(controller1.isDisposed, isTrue);
      expect(controller2.isDisposed, isTrue);
      expect(sharedQuery.isDisposed, isTrue);
    });
  });
}

// Test controller that uses a shared query
class _TestControllerUsingSharedQuery extends ZenController {
  final ZenScope scope;
  final String queryTag;
  ZenQuery<String>? sharedQuery;
  @override
  bool isDisposed = false;

  _TestControllerUsingSharedQuery(this.scope, this.queryTag);

  @override
  void onInit() {
    super.onInit();
    // Access the shared query from scope
    sharedQuery = scope.find<ZenQuery<String>>(tag: queryTag);
  }

  @override
  void onClose() {
    isDisposed = true;
    super.onClose();
  }
}
