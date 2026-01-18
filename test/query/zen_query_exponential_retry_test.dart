import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('Exponential Backoff Retry Logic', () {
    test('calculates exponential delay correctly with default multiplier (2.0)',
        () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-exponential',
        fetcher: (token) async {
          attemptCount++;
          // Capture the delay by checking timing
          if (attemptCount <= 3) {
            throw Exception('Simulated failure $attemptCount');
          }
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 100), // Base delay
          maxRetryDelay: Duration(seconds: 10),
          retryBackoffMultiplier: 2.0,
          exponentialBackoff: true,
          retryWithJitter: false, // Disable jitter for predictable testing
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      // Should have tried 4 times total (initial + 3 retries)
      expect(attemptCount, 4);

      // Total time should be approximately:
      // Attempt 1: immediate (0ms)
      // Delay 1: 100ms (base * 2^0)
      // Attempt 2: after 100ms
      // Delay 2: 200ms (base * 2^1)
      // Attempt 3: after 200ms
      // Delay 3: 400ms (base * 2^2)
      // Attempt 4: after 400ms
      // Total: ~700ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(650));
      expect(stopwatch.elapsedMilliseconds, lessThan(850));
    });

    test('respects max delay cap', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-max-delay',
        fetcher: (token) async {
          attemptCount++;
          if (attemptCount <= 5) {
            throw Exception('Simulated failure $attemptCount');
          }
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 5,
          retryDelay: Duration(milliseconds: 100),
          maxRetryDelay: Duration(milliseconds: 300), // Cap at 300ms
          retryBackoffMultiplier: 2.0,
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attemptCount, 6); // Initial + 5 retries

      // Delays should be: 100ms, 200ms, 300ms (capped), 300ms (capped), 300ms (capped)
      // Total: ~1200ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(1150));
      expect(stopwatch.elapsedMilliseconds, lessThan(1350));
    });

    test('uses custom multiplier correctly', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-custom-multiplier',
        fetcher: (token) async {
          attemptCount++;
          if (attemptCount <= 3) {
            throw Exception('Simulated failure $attemptCount');
          }
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 100),
          maxRetryDelay: Duration(seconds: 10),
          retryBackoffMultiplier: 3.0, // Aggressive backoff
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attemptCount, 4);

      // Delays should be: 100ms (100*3^0), 300ms (100*3^1), 900ms (100*3^2)
      // Total: ~1300ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(1250));
      expect(stopwatch.elapsedMilliseconds, lessThan(1450));
    });

    test('adds jitter when enabled (delays vary)', () async {
      final delays = <int>[];

      // Run the same query multiple times and collect delays
      for (int i = 0; i < 5; i++) {
        Zen.reset();
        int attemptCount = 0;

        final query = ZenQuery<String>(
          queryKey: 'test-jitter-$i',
          fetcher: (token) async {
            attemptCount++;
            if (attemptCount <= 2) {
              throw Exception('Simulated failure');
            }
            return 'success';
          },
          config: const ZenQueryConfig(
            retryCount: 2,
            retryDelay: Duration(milliseconds: 100),
            maxRetryDelay: Duration(seconds: 10),
            retryBackoffMultiplier: 2.0,
            exponentialBackoff: true,
            retryWithJitter: true, // Enable jitter
          ),
        );

        final stopwatch = Stopwatch()..start();
        await query.fetch();
        stopwatch.stop();

        delays.add(stopwatch.elapsedMilliseconds);
      }

      // With jitter, delays should vary
      // Without jitter, all would be ~300ms (100ms + 200ms)
      // With ±20% jitter, should range from ~240ms to ~360ms

      // Check that not all delays are identical
      final uniqueDelays = delays.toSet();
      expect(uniqueDelays.length, greaterThan(1),
          reason: 'Jitter should cause variation in delays');

      // Check that all delays are within expected range (with jitter)
      for (final delay in delays) {
        expect(delay, greaterThan(200)); // Lower bound with jitter
        expect(delay, lessThan(400)); // Upper bound with jitter
      }
    });

    test('uses linear backoff when exponentialBackoff is false', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-linear',
        fetcher: (token) async {
          attemptCount++;
          if (attemptCount <= 3) {
            throw Exception('Simulated failure $attemptCount');
          }
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 100),
          exponentialBackoff: false, // Linear backoff
          retryWithJitter: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attemptCount, 4);

      // All delays should be 100ms each
      // Total: ~300ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(280));
      expect(stopwatch.elapsedMilliseconds, lessThan(400));
    });

    test('still respects retry count limit', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-retry-count',
        fetcher: (token) async {
          attemptCount++;
          throw Exception('Always fails');
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 50),
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      try {
        await query.fetch();
        fail('Should have thrown an exception');
      } catch (e) {
        // Expected
      }

      // Should try 4 times total (initial + 3 retries)
      expect(attemptCount, 4);
      expect(query.status.value, ZenQueryStatus.error);
    });

    test('exponential backoff with zero retries fails immediately', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-zero-retries',
        fetcher: (token) async {
          attemptCount++;
          throw Exception('Fails');
        },
        config: const ZenQueryConfig(
          retryCount: 0,
          retryDelay: Duration(milliseconds: 100),
          exponentialBackoff: true,
        ),
      );

      final stopwatch = Stopwatch()..start();
      try {
        await query.fetch();
        fail('Should have thrown');
      } catch (e) {
        // Expected
      }
      stopwatch.stop();

      expect(attemptCount, 1); // Only initial attempt
      expect(stopwatch.elapsedMilliseconds, lessThan(50)); // No retry delay
    });

    test('exponential backoff works with very small base delay', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-small-delay',
        fetcher: (token) async {
          attemptCount++;
          if (attemptCount <= 2) {
            throw Exception('Simulated failure');
          }
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 2,
          retryDelay: Duration(milliseconds: 10), // Very small
          maxRetryDelay: Duration(seconds: 10),
          retryBackoffMultiplier: 2.0,
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attemptCount, 3);

      // Delays: 10ms, 20ms
      // Total: ~30ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(25));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('exponential backoff handles large multipliers', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-large-multiplier',
        fetcher: (token) async {
          attemptCount++;
          if (attemptCount <= 3) {
            throw Exception('Simulated failure');
          }
          return 'success';
        },
        config: const ZenQueryConfig(
          retryCount: 3,
          retryDelay: Duration(milliseconds: 10),
          maxRetryDelay:
              Duration(milliseconds: 500), // Cap to prevent huge delays
          retryBackoffMultiplier: 10.0, // Very aggressive
          exponentialBackoff: true,
          retryWithJitter: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attemptCount, 4);

      // Delays: 10ms (10*10^0), 100ms (10*10^1), 500ms (capped from 1000ms)
      // Total: ~610ms
      expect(stopwatch.elapsedMilliseconds, lessThan(700));
    });

    test('uses retryDelayFn when provided', () async {
      int attemptCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-custom-fn',
        fetcher: (token) async {
          attemptCount++;
          if (attemptCount <= 2) throw 'fail';
          return 'success';
        },
        config: ZenQueryConfig(
          retryCount: 2,
          retryDelayFn: (attempt, error) {
            // attempt is 0-indexed
            // Return different delays based on attempt
            if (attempt == 0) return const Duration(milliseconds: 50);
            return const Duration(milliseconds: 100);
          },
        ),
      );

      final stopwatch = Stopwatch()..start();
      await query.fetch();
      stopwatch.stop();

      expect(attemptCount, 3);
      // Expected: 50ms + 100ms = 150ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(130));
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
  });

  group('Retry Configuration Validation', () {
    test('default configuration uses exponential backoff', () {
      final query = ZenQuery<String>(
        queryKey: 'test-defaults',
        fetcher: (token) async => 'success',
      );

      expect(query.config.exponentialBackoff, true);
      expect(query.config.retryWithJitter, true);
      expect(query.config.retryBackoffMultiplier, 2.0);
      expect(query.config.maxRetryDelay, const Duration(seconds: 30));
      expect(query.config.retryDelay, const Duration(milliseconds: 200));
    });

    test('config copyWith preserves and overrides retry settings', () {
      const config1 = ZenQueryConfig(
        retryCount: 5,
        retryDelay: Duration(milliseconds: 100),
      );

      // Use copyWith to override specific fields
      final updated = config1.copyWith(
        maxRetryDelay: Duration(seconds: 20),
        retryBackoffMultiplier: 3.0,
      );

      // copyWith preserves original values and applies overrides
      expect(updated.retryCount, 5); // Kept from config1
      expect(updated.retryDelay,
          const Duration(milliseconds: 100)); // Kept from config1
      expect(updated.maxRetryDelay, const Duration(seconds: 20)); // Overridden
      expect(updated.retryBackoffMultiplier, 3.0); // Overridden
    });

    test('config cast preserves retry settings', () {
      const config = ZenQueryConfig<String>(
        retryCount: 5,
        retryDelay: Duration(milliseconds: 150),
        maxRetryDelay: Duration(seconds: 25),
        retryBackoffMultiplier: 2.5,
        exponentialBackoff: true,
        retryWithJitter: false,
      );

      final casted = config.cast<int>();

      expect(casted.retryCount, 5);
      expect(casted.retryDelay, const Duration(milliseconds: 150));
      expect(casted.maxRetryDelay, const Duration(seconds: 25));
      expect(casted.retryBackoffMultiplier, 2.5);
      expect(casted.exponentialBackoff, true);
      expect(casted.retryWithJitter, false);
    });
  });
}
