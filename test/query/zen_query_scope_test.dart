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
        fetcher: () async => 'global-data',
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
        fetcher: () async => 'scoped-data',
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
        fetcher: () async => 'data',
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
        fetcher: () async => 'data',
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
        fetcher: () async => 'data1',
        scope: scope,
        config: ZenQueryConfig(staleTime: const Duration(hours: 1)),
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: () async => 'data2',
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
        fetcher: () async => 'data1',
        scope: scope,
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: () async => 'data2',
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
        fetcher: () async => 'data1',
        scope: scope,
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: () async => throw Exception('error'),
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
        fetcher: () async => 'Product 123',
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
        fetcher: () async {
          await Future.delayed(const Duration(milliseconds: 10));
          fetchCount1++;
          return 'data1-$fetchCount1';
        },
        scope: scope,
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: () async {
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
        fetcher: () async => 'parent-data',
        scope: parentScope,
      );

      final childQuery = ZenQuery<String>(
        queryKey: 'child-query',
        fetcher: () async => 'child-data',
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
        fetcher: () async => 'global-data',
      );

      // Scoped query
      final scopedQuery = ZenQuery<String>(
        queryKey: 'scoped',
        fetcher: () async => 'scoped-data',
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
        fetcher: () async => 'test-data',
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
        fetcher: () async => 'data',
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
        fetcher: () async => 'fetched-data',
        initialData: 'initial-data',
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
        fetcher: () async => 'cached-data',
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
        fetcher: () async => 'data',
        staleTime: Duration(minutes: 10),
      );

      expect(query.config.staleTime, Duration(minutes: 10));

      scope.dispose();
    });

    test('putQuery auto-disposes with scope by default', () async {
      final scope = ZenScope(name: 'TestScope');

      final query = scope.putQuery<String>(
        queryKey: 'auto-dispose-query',
        fetcher: () async => 'data',
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
        fetcher: () async => 'data1',
      );

      final query2 = scope.putQuery<int>(
        queryKey: 'query2',
        fetcher: () async => 42,
      );

      final query3 = scope.putCachedQuery<bool>(
        queryKey: 'query3',
        fetcher: () async => true,
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
        fetcher: () async => 'original',
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
}
