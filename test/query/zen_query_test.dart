import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  late ZenQuery<String> query;

  setUp(() {
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    query.dispose();
    Zen.reset();
  });

  group('ZenQuery', () {
    test('initial state is idle', () {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'data',
      );

      expect(query.status.value, ZenQueryStatus.idle);
      expect(query.hasData, false);
      expect(query.hasError, false);
    });

    test('fetches data successfully', () async {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'test data',
      );

      final result = await query.fetch();

      expect(result, 'test data');
      expect(query.status.value, ZenQueryStatus.success);
      expect(query.data.value, 'test data');
      expect(query.hasData, true);
    });

    test('handles errors correctly', () async {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => throw Exception('Test error'),
        config: const ZenQueryConfig(retryCount: 0),
      );

      expect(
        () => query.fetch(),
        throwsA(isA<Exception>()),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(query.status.value, ZenQueryStatus.error);
      expect(query.hasError, true);
    });

    test('retries on failure', () async {
      int attempts = 0;
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async {
          attempts++;
          if (attempts < 3) {
            throw Exception('Retry me');
          }
          return 'success after retry';
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 10),
        ),
      );

      final result = await query.fetch();

      expect(result, 'success after retry');
      expect(attempts, 3);
    });

    test('caches data and returns from cache', () async {
      int fetchCount = 0;
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async {
          fetchCount++;
          return 'data $fetchCount';
        },
        config: const ZenQueryConfig(staleTime: Duration(seconds: 10)),
      );

      // First fetch
      await query.fetch();
      expect(fetchCount, 1);

      // Second fetch should return from cache
      await query.fetch();
      expect(fetchCount, 1); // Should not increment
    });

    test('refetches when data is stale', () async {
      int fetchCount = 0;
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async {
          fetchCount++;
          return 'data $fetchCount';
        },
        config: const ZenQueryConfig(staleTime: Duration(milliseconds: 100)),
      );

      // First fetch
      await query.fetch();
      expect(fetchCount, 1);

      // Wait for data to become stale
      await Future.delayed(const Duration(milliseconds: 150));

      // Should refetch
      await query.fetch();
      expect(fetchCount, 2);
    });

    test('supports optimistic updates', () async {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'original',
      );

      await query.fetch();
      expect(query.data.value, 'original');

      // Optimistic update
      query.setData('updated');
      expect(query.data.value, 'updated');
    });

    test('invalidate marks data as stale', () async {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'data',
        config: const ZenQueryConfig(staleTime: Duration(hours: 1)),
      );

      await query.fetch();
      expect(query.isStale, false);

      query.invalidate();
      expect(query.isStale, true);
    });

    test('reset returns to initial state', () async {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'data',
        initialData: 'initial',
      );

      await query.fetch();
      expect(query.data.value, 'data');

      query.reset();
      expect(query.data.value, 'initial');
      expect(query.status.value, ZenQueryStatus.success);
    });

    test('deduplicates concurrent requests', () async {
      int fetchCount = 0;
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return 'data';
        },
      );

      // Start multiple fetches simultaneously
      final futures = [
        query.fetch(),
        query.fetch(),
        query.fetch(),
      ];

      await Future.wait(futures);

      // Should only fetch once
      expect(fetchCount, 1);
    });

    test('registers with cache on creation', () {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'data',
      );

      final cached = ZenQueryCache.instance.getQuery<String>('test');
      expect(cached, query);
    });

    test('unregisters from cache on disposal', () {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'data',
      );

      query.dispose();

      final cached = ZenQueryCache.instance.getQuery<String>('test');
      expect(cached, null);
    });

    test('supports list keys', () {
      final query = ZenQuery<String>(
        queryKey: ['user', 123, 'details'],
        fetcher: () async => 'data',
      );

      expect(query.queryKey, "['user', 123, 'details']");

      final cached =
          ZenQueryCache.instance.getQuery<String>(['user', 123, 'details']);
      expect(cached, query);

      query.dispose();
    });
  });

  group('ZenQueryCache', () {
    test('invalidates query by key', () async {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'data',
        config: const ZenQueryConfig(staleTime: Duration(hours: 1)),
      );

      await query.fetch();
      expect(query.isStale, false);

      ZenQueryCache.instance.invalidateQuery('test');
      expect(query.isStale, true);
    });

    test('invalidates queries with prefix', () async {
      final query1 = ZenQuery<String>(
        queryKey: 'user:1',
        fetcher: () async => 'user1',
        config: const ZenQueryConfig(staleTime: Duration(hours: 1)),
      );

      final query2 = ZenQuery<String>(
        queryKey: 'user:2',
        fetcher: () async => 'user2',
        config: const ZenQueryConfig(staleTime: Duration(hours: 1)),
      );

      await query1.fetch();
      await query2.fetch();

      ZenQueryCache.instance.invalidateQueriesWithPrefix('user:');

      expect(query1.isStale, true);
      expect(query2.isStale, true);

      query1.dispose();
      query2.dispose();
    });

    test('provides cache statistics', () {
      query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: () async => 'data',
      );

      final stats = ZenQueryCache.instance.getStats();

      // Updated to match new stats format
      expect(stats['total_queries'], 1);
      expect(stats['global_queries'], 1);
      expect(stats['scoped_queries'], 0);
    });
  });
}
