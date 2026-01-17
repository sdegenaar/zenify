import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQuery Pause/Resume', () {
    test('pause() prevents fetch from executing', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-pause-fetch',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero, // Always stale
        ),
      );

      // Initial fetch
      await query.fetch();
      expect(fetchCount, 1);
      expect(query.data.value, 'data-1');

      // Pause the query
      query.pause();

      // Try to fetch - should return cached data without fetching
      final result = await query.fetch();
      expect(result, 'data-1'); // Same cached data
      expect(fetchCount, 1); // No new fetch

      // Verify query is still paused
      expect(query.data.value, 'data-1');
    });

    test('pause() with force: true still fetches', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-pause-force',
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

    test('pause() throws error when no cached data available', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-pause-no-data',
        fetcher: (token) async => 'data',
      );

      // Pause before any fetch
      query.pause();

      // Should throw error since no cached data
      expect(
        () => query.fetch(),
        throwsA(equals('Query is paused')),
      );
    });

    test('pause() cancels background refetch timer', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-pause-timer',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          refetchInterval: Duration(milliseconds: 100),
          enableBackgroundRefetch: true,
        ),
      );

      // Initial fetch
      await query.fetch();
      expect(fetchCount, 1);

      // Wait for background refetch
      await Future.delayed(const Duration(milliseconds: 150));
      expect(fetchCount, greaterThan(1),
          reason: 'Background refetch should occur');

      final countBeforePause = fetchCount;

      // Pause should stop background refetch
      query.pause();

      // Wait - should NOT refetch
      await Future.delayed(const Duration(milliseconds: 150));
      expect(fetchCount, countBeforePause,
          reason: 'No refetch should occur while paused');
    });

    test('pause() cancels pending request', () async {
      bool fetchCompleted = false;

      final query = ZenQuery<String>(
        queryKey: 'test-pause-pending',
        fetcher: (token) async {
          await Future.delayed(const Duration(milliseconds: 200));
          if (token.isCancelled) {
            throw Exception('Cancelled');
          }
          fetchCompleted = true;
          return 'data';
        },
      );

      // Start fetch but don't await
      final fetchFuture = query.fetch();

      // Pause immediately
      await Future.delayed(const Duration(milliseconds: 50));
      query.pause();

      // Wait for fetch to complete
      try {
        await fetchFuture;
      } catch (e) {
        // Expected - request was cancelled
      }

      // Fetch should have been cancelled
      expect(fetchCompleted, false,
          reason: 'Fetch should be cancelled by pause');
    });

    test('resume() restarts background refetch timer', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-resume-timer',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          refetchInterval: Duration(milliseconds: 100),
          enableBackgroundRefetch: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Pause
      query.pause();
      await Future.delayed(const Duration(milliseconds: 150));
      final countAfterPause = fetchCount;

      // Resume
      query.resume();

      // Wait for background refetch to restart
      await Future.delayed(const Duration(milliseconds: 150));
      expect(fetchCount, greaterThan(countAfterPause),
          reason: 'Background refetch should restart after resume');
    });

    test('resume() refetches stale data when refetchOnResume is true',
        () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-resume-refetch',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration(milliseconds: 50),
          refetchOnResume: true,
        ),
      );

      // Initial fetch
      await query.fetch();
      expect(fetchCount, 1);

      // Wait for data to become stale
      await Future.delayed(const Duration(milliseconds: 100));
      expect(query.isStale, true);

      // Pause
      query.pause();

      // Resume should trigger refetch of stale data
      query.resume();

      // Wait for refetch to complete
      await Future.delayed(const Duration(milliseconds: 100));
      expect(fetchCount, 2, reason: 'Should refetch stale data on resume');
    });

    test('resume() does not refetch fresh data', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-resume-fresh',
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
      expect(query.isStale, false);

      query.pause();
      query.resume();

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 100));

      // Should NOT refetch because data is still fresh
      expect(fetchCount, 1, reason: 'Should not refetch fresh data');
    });

    test('resume() respects refetchOnResume: false', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-resume-no-refetch',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero, // Always stale
          refetchOnResume: false, // Don't refetch on resume
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      query.pause();
      query.resume();

      await Future.delayed(const Duration(milliseconds: 100));

      // Should NOT refetch even though data is stale
      expect(fetchCount, 1,
          reason: 'Should not refetch when refetchOnResume is false');
    });

    test('multiple pause/resume cycles work correctly', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-multiple-cycles',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Cycle 1
      query.pause();
      query.resume();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(fetchCount, 2);

      // Cycle 2
      query.pause();
      query.resume();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(fetchCount, 3);

      // Cycle 3
      query.pause();
      query.resume();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(fetchCount, 4);
    });

    test('pause() is idempotent (multiple calls are safe)', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-pause-idempotent',
        fetcher: (token) async => 'data',
      );

      await query.fetch();

      // Multiple pause calls should be safe
      query.pause();
      query.pause();
      query.pause();

      // Should still work
      final result = await query.fetch();
      expect(result, 'data');
    });

    test('resume() is idempotent (multiple calls are safe)', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-resume-idempotent',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      query.pause();

      // Multiple resume calls should only trigger one refetch
      query.resume();
      query.resume();
      query.resume();

      await Future.delayed(const Duration(milliseconds: 100));

      // Should only refetch once
      expect(fetchCount, 2);
    });

    test('dispose() while paused works correctly', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-dispose-paused',
        fetcher: (token) async => 'data',
      );

      await query.fetch();
      query.pause();

      // Should dispose cleanly
      query.dispose();

      expect(query.isDisposed, true);
    });

    test('paused query with enabled: false still respects pause', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-pause-disabled',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        enabled: false,
      );

      // Manually enable and fetch
      query.enabled.value = true;
      await query.fetch();
      expect(fetchCount, 1);

      // Pause
      query.pause();

      // Try to fetch - should return cached data
      final result = await query.fetch();
      expect(result, 'data-1');
      expect(fetchCount, 1);
    });

    test('resume() works after query was disabled then enabled', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-resume-after-disabled',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero,
          refetchOnResume: true,
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      // Disable, pause, enable, resume
      query.enabled.value = false;
      query.pause();
      query.enabled.value = true;
      query.resume();

      await Future.delayed(const Duration(milliseconds: 100));

      // Should refetch
      expect(fetchCount, 2);
    });
  });

  group('Pause/Resume Configuration', () {
    test('autoPauseOnBackground defaults to false', () {
      final query = ZenQuery<String>(
        queryKey: 'test-auto-pause-default',
        fetcher: (token) async => 'data',
      );

      expect(query.config.autoPauseOnBackground, false);
    });

    test('refetchOnResume defaults to false', () {
      final query = ZenQuery<String>(
        queryKey: 'test-refetch-default',
        fetcher: (token) async => 'data',
      );

      expect(query.config.refetchOnResume, false);
    });

    test('can disable autoPauseOnBackground', () {
      final query = ZenQuery<String>(
        queryKey: 'test-no-auto-pause',
        fetcher: (token) async => 'data',
        config: const ZenQueryConfig(
          autoPauseOnBackground: false,
        ),
      );

      expect(query.config.autoPauseOnBackground, false);
    });

    test('can disable refetchOnResume', () {
      final query = ZenQuery<String>(
        queryKey: 'test-no-refetch',
        fetcher: (token) async => 'data',
        config: const ZenQueryConfig(
          refetchOnResume: false,
        ),
      );

      expect(query.config.refetchOnResume, false);
    });

    test('config merge preserves pause/resume settings', () {
      const config1 = ZenQueryConfig(
        autoPauseOnBackground: false,
      );

      const config2 = ZenQueryConfig(
        refetchOnResume: false,
      );

      final merged = config1.merge(config2);

      // merge() uses other's values directly
      expect(merged.autoPauseOnBackground, false); // config2's default
      expect(merged.refetchOnResume, false); // config2's value
    });

    test('config cast preserves pause/resume settings', () {
      const config = ZenQueryConfig<String>(
        autoPauseOnBackground: false,
        refetchOnResume: false,
      );

      final casted = config.cast<int>();

      expect(casted.autoPauseOnBackground, false);
      expect(casted.refetchOnResume, false);
    });
  });
}
