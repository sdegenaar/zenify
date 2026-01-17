import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('Query Integration Tests', () {
    test('resume refetches only if data is stale', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-resume-stale-check',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration(minutes: 5), // Long stale time
          refetchOnResume: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      query.pause();
      query.resume();

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 100));

      // Should NOT refetch (data still fresh)
      expect(fetchCount, 1);
    });

    test('scoped queries work with pause/resume', () async {
      final scope = Zen.createScope(name: 'test-scope');
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-scoped-pause',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        scope: scope,
      );

      await query.fetch();
      expect(fetchCount, 1);

      query.pause();

      // Should return cached data
      final result = await query.fetch();
      expect(result, 'data-1');
      expect(fetchCount, 1);

      query.resume();

      // Should be able to fetch again
      await query.fetch(force: true);
      expect(fetchCount, 2);
    });

    test('retry with exponential backoff and pause interaction', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-retry-pause-interaction',
        fetcher: (token) async {
          attempts++;
          await Future.delayed(const Duration(milliseconds: 100));
          if (attempts < 5) throw Exception('Fail');
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 10,
          retryDelay: Duration(milliseconds: 50),
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      // Start fetch
      final future = query.fetch();

      // Pause during retry sequence
      await Future.delayed(const Duration(milliseconds: 150));
      query.pause();

      try {
        await future;
      } catch (e) {
        // May fail if paused during retry
      }

      // Resume and try again
      query.resume();
      final result = await query.fetch(force: true);

      expect(result, 'success');
    });

    test('multiple queries with different keys work independently', () async {
      int fetch1Count = 0;
      int fetch2Count = 0;

      final query1 = ZenQuery<String>(
        queryKey: 'key-1',
        fetcher: (token) async {
          fetch1Count++;
          return 'data1-$fetch1Count';
        },
      );

      final query2 = ZenQuery<String>(
        queryKey: 'key-2', // Different key
        fetcher: (token) async {
          fetch2Count++;
          return 'data2-$fetch2Count';
        },
      );

      // Both should fetch independently
      await query1.fetch();
      await query2.fetch();

      // Both should have fetched
      expect(fetch1Count, 1);
      expect(fetch2Count, 1);
    });

    test('pause/resume with placeholder data', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-placeholder-pause',
        fetcher: (token) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'real-data';
        },
        config: const ZenQueryConfig(
          placeholderData: 'placeholder',
        ),
      );

      // Should have placeholder immediately
      expect(query.data.value, 'placeholder');

      // Fetch real data
      await query.fetch();
      expect(query.data.value, 'real-data');

      query.pause();

      // Real data should still be there
      expect(query.data.value, 'real-data');

      query.resume();
      expect(query.data.value, 'real-data');
    });

    test('enabled state interacts correctly with pause', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-enabled-pause',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        enabled: false, // Disabled initially
      );

      // Enable and fetch
      query.enabled.value = true;
      await query.fetch();
      expect(fetchCount, 1);

      // Pause
      query.pause();

      // Still can't fetch (paused)
      final pausedResult = await query.fetch();
      expect(pausedResult, 'data-1');
      expect(fetchCount, 1);

      // Resume
      query.resume();

      // Now can fetch
      await query.fetch(force: true);
      expect(fetchCount, 2);
    });

    test('stale time and cache time work together', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-stale-cache-interaction',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration(milliseconds: 100),
          cacheTime: Duration(seconds: 10),
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);
      expect(query.isStale, false);

      // Wait for stale
      await Future.delayed(const Duration(milliseconds: 150));
      expect(query.isStale, true);

      // Fetch again (should refetch because stale)
      await query.fetch();
      expect(fetchCount, 2);
    });

    test('background refetch respects pause state', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-background-pause',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          refetchInterval: Duration(milliseconds: 100),
          enableBackgroundRefetch: false, // Disabled for test
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      query.pause();

      // Wait - should not refetch
      await Future.delayed(const Duration(milliseconds: 200));
      expect(fetchCount, 1);

      query.resume();

      // Still should not refetch (background refetch disabled)
      await Future.delayed(const Duration(milliseconds: 200));
      expect(fetchCount, 1);
    });

    test('query disposal cleans up all resources', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-disposal',
        fetcher: (token) async => 'data',
        config: const ZenQueryConfig(
          refetchInterval: Duration(milliseconds: 100),
          enableBackgroundRefetch: false,
        ),
      );

      await query.fetch();
      expect(query.hasData, true);

      query.dispose();

      expect(query.isDisposed, true);
      // Should not crash when accessing disposed query
      expect(() => query.hasData, returnsNormally);
    });

    test('concurrent fetches are deduplicated', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-deduplication',
        fetcher: (token) async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return 'data-$fetchCount';
        },
      );

      // Start multiple fetches concurrently
      final futures = [
        query.fetch(),
        query.fetch(),
        query.fetch(),
      ];

      await Future.wait(futures);

      // Should only fetch once
      expect(fetchCount, 1);
    });
  });
}
