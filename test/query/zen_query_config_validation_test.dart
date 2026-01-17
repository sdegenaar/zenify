import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('Query Configuration Validation', () {
    test('handles zero retry delay', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-zero-delay',
        fetcher: (token) async {
          attempts++;
          if (attempts < 3) throw Exception('Fail');
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration.zero, // Immediate retry
          exponentialBackoff: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attempts, 3);
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Zero delay should retry very fast');
    });

    test('handles Duration.zero stale time', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-zero-stale',
        fetcher: (token) async => 'data',
        config: const ZenQueryConfig(
          staleTime: Duration.zero, // Always stale
        ),
      );

      await query.fetch();
      expect(query.isStale, true, reason: 'Data should be immediately stale');
    });

    test('handles very long stale time', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-long-stale',
        fetcher: (token) async => 'data',
        config: const ZenQueryConfig(
          staleTime: Duration(days: 365), // Very long
        ),
      );

      await query.fetch();
      expect(query.isStale, false, reason: 'Data should stay fresh');
    });

    test('conflicting background refetch and auto-pause config', () {
      // This configuration is contradictory but should not crash
      final query = ZenQuery<String>(
        queryKey: 'test-conflicting-config',
        fetcher: (token) async => 'data',
        config: const ZenQueryConfig(
          enableBackgroundRefetch: true,
          autoPauseOnBackground: true, // Will pause background refetch
          refetchInterval: Duration(seconds: 30),
        ),
      );

      // Should create query without error
      expect(query, isNotNull);
      expect(query.config.enableBackgroundRefetch, true);
      expect(query.config.autoPauseOnBackground, true);
    });

    test('retry count of zero disables retries', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-no-retry',
        fetcher: (token) async {
          attempts++;
          throw Exception('Always fails');
        },
        config: const ZenQueryConfig(
          retryCount: 0, // No retries
        ),
      );

      try {
        await query.fetch();
        fail('Should have thrown');
      } catch (e) {
        // Expected
      }

      expect(attempts, 1, reason: 'Should only try once with retryCount: 0');
    });

    test('very high retry count works correctly', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-high-retry',
        fetcher: (token) async {
          attempts++;
          if (attempts < 5) throw Exception('Fail');
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 100, // Very high
          retryDelay: Duration(milliseconds: 1),
        ),
      );

      await query.fetch();
      expect(attempts, 5, reason: 'Should succeed before hitting max retries');
    });

    test('max retry delay caps exponential backoff', () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-max-delay-cap',
        fetcher: (token) async {
          attempts++;
          if (attempts <= 10) throw Exception('Fail');
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 10,
          retryDelay: Duration(milliseconds: 100),
          maxRetryDelay: Duration(milliseconds: 500), // Cap
          retryBackoffMultiplier: 2.0,
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attempts, 11);
      // With cap, delays are: 100, 200, 400, 500, 500, 500, 500, 500, 500, 500
      // Total: ~4600ms
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('refetchOnResume false prevents auto-refetch', () async {
      int fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-no-refetch-resume',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        config: const ZenQueryConfig(
          staleTime: Duration.zero, // Always stale
          refetchOnResume: false, // Don't auto-refetch
        ),
      );

      await query.fetch();
      expect(fetchCount, 1);

      query.pause();
      query.resume();

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 100));

      // Should NOT have refetched automatically
      expect(fetchCount, 1);
    });

    test('autoPauseOnBackground false prevents auto-pause', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-no-auto-pause',
        fetcher: (token) async => 'data',
        config: const ZenQueryConfig(
          autoPauseOnBackground: false, // Don't auto-pause
        ),
      );

      await query.fetch();

      // Manual pause should still work
      query.pause();
      final result = await query.fetch();
      expect(result, 'data');

      // But lifecycle wouldn't auto-pause this query
      expect(query.config.autoPauseOnBackground, false);
    });

    test('config merge preserves all new fields', () {
      const config1 = ZenQueryConfig(
        retryCount: 5,
        retryDelay: Duration(milliseconds: 100),
        autoPauseOnBackground: false,
      );

      const config2 = ZenQueryConfig(
        maxRetryDelay: Duration(seconds: 20),
        retryBackoffMultiplier: 3.0,
        refetchOnResume: false,
      );

      final merged = config1.merge(config2);

      // Should have config2's values
      expect(merged.maxRetryDelay, const Duration(seconds: 20));
      expect(merged.retryBackoffMultiplier, 3.0);
      expect(merged.refetchOnResume, false);
    });
  });
}
