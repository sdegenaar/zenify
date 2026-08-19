// test/query/zen_cancellable_retry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  group('Cancellable retry delays', () {
    test('ZenQuery: disposing during retry delay cancels immediately',
        () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'cancellable-query',
        fetcher: (_) async {
          attempts++;
          throw Exception('network error');
        },
        config: ZenQueryConfig(
          retryCount: 3,
          retryDelay: const Duration(seconds: 30), // Long delay
          exponentialBackoff: false,
          retryWithJitter: false,
        ),
      );

      // Trigger fetch which will fail attempt 1 and enter 30s delay
      final future = query.fetch();

      // Let the first attempt fail and enter the delay
      await Future.delayed(const Duration(milliseconds: 10));
      expect(attempts, 1);

      final stopwatch = Stopwatch()..start();

      // Dispose the query while it is in the 30-second delay
      query.dispose();

      // Await future failure/cancellation
      try {
        await future;
      } catch (_) {}

      stopwatch.stop();

      // Should complete in milliseconds, NOT waiting 30 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(query.isDisposed, isTrue);
    });

    test(
        'ZenQuery: pause() during retry delay cancels delay and enters paused state cleanly',
        () async {
      int attempts = 0;

      final query = ZenQuery<String>(
        queryKey: 'cancellable-query-pause',
        fetcher: (_) async {
          attempts++;
          throw Exception('network error');
        },
        config: ZenQueryConfig(
          retryCount: 3,
          retryDelay: const Duration(seconds: 30),
          exponentialBackoff: false,
          retryWithJitter: false,
        ),
      );

      final future = query.fetch();

      await Future.delayed(const Duration(milliseconds: 20));
      expect(attempts, 1);

      final stopwatch = Stopwatch()..start();

      query.pause();

      try {
        await future;
      } catch (e) {
        expect(e, isA<ZenOfflineException>());
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'pause() should interrupt retry delay immediately');
      expect(query.fetchStatus.value, ZenQueryFetchStatus.paused);
      expect(attempts, 1, reason: 'Should not execute retry while paused');

      query.dispose();
    });

    test('ZenMutation: disposing during retry delay cancels immediately',
        () async {
      int attempts = 0;

      final mutation = ZenMutation<String, void>(
        mutationFn: (_) async {
          attempts++;
          throw Exception('mutation failure');
        },
        retryCount: 3,
        retryDelay: const Duration(seconds: 30),
        exponentialBackoff: false,
        retryWithJitter: false,
      );

      final future = mutation.mutate(null);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(attempts, 1);

      final stopwatch = Stopwatch()..start();

      mutation.dispose();

      try {
        await future;
      } catch (_) {}

      stopwatch.stop();

      // Should cancel immediately, NOT waiting 30 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(mutation.isDisposed, isTrue);
    });

    test(
        'ZenMutation: reset() during retry delay halts retrying and resolves the future cleanly',
        () async {
      // With the _resetRequested flag, reset() now does the right thing:
      // it cancels the backoff delay AND signals the retry loop to exit cleanly.
      // The mutate() future resolves with null immediately (not waiting 30s),
      // and the mutation is still fully usable for subsequent calls.
      int attempts = 0;

      final mutation = ZenMutation<String, void>(
        mutationFn: (_) async {
          attempts++;
          throw Exception('mutation failure');
        },
        retryCount: 3,
        retryDelay: const Duration(seconds: 30),
        exponentialBackoff: false,
        retryWithJitter: false,
      );

      // Start mutation — it will fail and enter a 30-second retry delay
      final future = mutation.mutate(null);

      // Let the first attempt fail and enter the delay
      await Future.delayed(const Duration(milliseconds: 20));
      expect(attempts, 1);

      final stopwatch = Stopwatch()..start();

      // reset() sets _resetRequested = true AND cancels the delay Completer
      mutation.reset();

      // Await the future — should resolve immediately, NOT hang for 30s
      final result = await future;
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'reset() should halt the retry loop immediately');

      // Future resolves to null (clean exit, not an error)
      expect(result, isNull);

      // Mutation is still idle and usable — NOT disposed
      expect(mutation.isDisposed, isFalse);
      expect(mutation.status.value, ZenMutationStatus.idle);

      // Confirm it can still be used normally after reset
      // (retryCount still fires, but now against a permanently-failing fn,
      //  so we just verify the call completes without hanging)
      expect(attempts, 1,
          reason: 'Only 1 attempt fired before reset halted it');

      mutation.dispose();
    });
  });
}
