import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('Query Edge Cases', () {
    test('pause during active fetch cancels request', () async {
      bool fetchCompleted = false;

      final query = ZenQuery<String>(
        queryKey: 'test-pause-during-fetch',
        fetcher: (token) async {
          await Future.delayed(const Duration(milliseconds: 200));
          if (token.isCancelled) {
            throw Exception('Cancelled');
          }
          fetchCompleted = true;
          return 'data';
        },
      );

      // Start fetch
      final future = query.fetch();

      // Pause immediately
      await Future.delayed(const Duration(milliseconds: 50));
      query.pause();

      // Verify fetch was cancelled
      try {
        await future;
      } catch (e) {
        // Expected - request was cancelled
      }

      expect(fetchCompleted, false,
          reason: 'Fetch should be cancelled by pause');
    });

    test('resume during active fetch allows completion', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-resume-during-fetch',
        fetcher: (token) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'data';
        },
      );

      await query.fetch();
      query.pause();

      // Start fetch while paused (will return cached data)
      final cachedResult = await query.fetch();
      expect(cachedResult, 'data');

      // Resume and force fetch
      query.resume();
      final freshResult = await query.fetch(force: true);

      // Should complete successfully
      expect(freshResult, 'data');
    });

    test('handles rapid pause/resume cycles', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-rapid-cycles',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Rapid cycles
      for (int i = 0; i < 10; i++) {
        query.pause();
        query.resume();
      }

      // Should still work
      await query.fetch(force: true);
      expect(fetchCount, 2);
    });

    test('dispose while paused cleans up correctly', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-dispose-paused',
        fetcher: (token) async => 'data',
      );

      await query.fetch();
      query.pause();
      query.dispose();

      expect(query.isDisposed, true);
      // Should not crash
    });

    test('exponential backoff stops at max retries', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-max-retries',
        fetcher: (token) async {
          attempts++;
          throw Exception('Always fails');
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 10),
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      try {
        await query.fetch();
        fail('Should have thrown');
      } catch (e) {
        // Expected
      }

      expect(attempts, 4, reason: 'Initial attempt + 3 retries');
    });

    test('paused query does not retry', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-pause-no-retry',
        fetcher: (token) async {
          attempts++;
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Fail');
        },
        config: const ZenQueryConfig(
          retryCount: 5,
          retryDelay: Duration(milliseconds: 50),
        ),
      );

      // Start fetch (will retry)
      final future = query.fetch();

      // Pause during retry
      await Future.delayed(const Duration(milliseconds: 25));
      query.pause();

      try {
        await future;
      } catch (e) {
        // Expected
      }

      // Should have stopped retrying
      expect(attempts, lessThan(6), reason: 'Pause should stop retry attempts');
    });

    test('fetch with force bypasses pause state', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-force-bypass-pause',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      await query.fetch();
      expect(fetchCount, 1);

      query.pause();

      // Force fetch should work even when paused
      final result = await query.fetch(force: true);
      expect(result, 'data-2');
      expect(fetchCount, 2);
    });

    test('multiple queries with different pause states', () async {
      final query1 = ZenQuery<String>(
        queryKey: 'query1',
        fetcher: (token) async => 'data1',
      );

      final query2 = ZenQuery<String>(
        queryKey: 'query2',
        fetcher: (token) async => 'data2',
      );

      await query1.fetch();
      await query2.fetch();

      // Pause only query1
      query1.pause();

      // Query1 paused, Query2 not paused
      final result1 = await query1.fetch();
      final result2 = await query2.fetch(force: true);

      expect(result1, 'data1'); // Cached
      expect(result2, 'data2'); // Fresh fetch allowed
    });

    test('pause and resume preserve query state', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-state-preservation',
        fetcher: (token) async => 'data',
      );

      await query.fetch();

      expect(query.hasData, true);
      expect(query.data.value, 'data');

      query.pause();

      // State should be preserved
      expect(query.hasData, true);
      expect(query.data.value, 'data');

      query.resume();

      // State still preserved
      expect(query.hasData, true);
      expect(query.data.value, 'data');
    });
  });
}
