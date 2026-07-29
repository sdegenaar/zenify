import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.init();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenMutation retries', () {
    test('does not retry by default (retryCount = 0)', () async {
      int fetchCount = 0;
      final mutation = ZenMutation<String, void>(
        mutationFn: (_) async {
          fetchCount++;
          throw Exception('fail');
        },
      );

      await mutation.mutate(null);
      expect(fetchCount, 1);
      expect(mutation.status.value, ZenMutationStatus.error);
    });

    test('retries up to retryCount times', () async {
      int fetchCount = 0;
      final mutation = ZenMutation<String, void>(
        retryCount: 2,
        retryDelay: Duration.zero,
        mutationFn: (_) async {
          fetchCount++;
          throw Exception('fail');
        },
      );

      await mutation.mutate(null);

      // 1 initial + 2 retries = 3
      expect(fetchCount, 3);
      expect(mutation.status.value, ZenMutationStatus.error);
    });

    test('resolves successfully on retry', () async {
      int fetchCount = 0;
      final mutation = ZenMutation<String, void>(
        retryCount: 2,
        retryDelay: Duration.zero,
        mutationFn: (_) async {
          fetchCount++;
          if (fetchCount < 2) {
            throw Exception('fail');
          }
          return 'success';
        },
      );

      final result = await mutation.mutate(null);

      expect(fetchCount, 2);
      expect(result, 'success');
      expect(mutation.status.value, ZenMutationStatus.success);
    });

    test('custom retryDelayFn is used', () async {
      int fetchCount = 0;
      List<Duration> delays = [];

      final mutation = ZenMutation<String, void>(
        retryCount: 2,
        retryDelayFn: (attempt, error) {
          final delay = Duration(milliseconds: (attempt + 1) * 10);
          delays.add(delay);
          return delay;
        },
        mutationFn: (_) async {
          fetchCount++;
          throw Exception('fail');
        },
      );

      await mutation.mutate(null);

      expect(fetchCount, 3);
      expect(delays.length, 2);
      expect(delays[0], const Duration(milliseconds: 10));
      expect(delays[1], const Duration(milliseconds: 20));
    });

    test('uses exponential backoff without jitter', () async {
      int fetchCount = 0;
      final mutation = ZenMutation<String, void>(
        retryCount: 2,
        retryDelay: const Duration(milliseconds: 1),
        exponentialBackoff: true,
        retryWithJitter: false,
        mutationFn: (_) async {
          fetchCount++;
          throw Exception('fail');
        },
      );

      await mutation.mutate(null);

      expect(fetchCount, 3);
    });

    test('activeMutations counter returns to 0 after failed retry cycle',
        () async {
      expect(ZenMutation.activeMutations.value, 0);

      final mutation = ZenMutation<String, void>(
        retryCount: 2,
        retryDelay: Duration.zero,
        mutationFn: (_) async => throw Exception('fail'),
      );

      await mutation.mutate(null);

      expect(ZenMutation.activeMutations.value, 0);
    });

    test('activeMutations counter returns to 0 after successful retry',
        () async {
      expect(ZenMutation.activeMutations.value, 0);
      int attempts = 0;

      final mutation = ZenMutation<String, void>(
        retryCount: 2,
        retryDelay: Duration.zero,
        mutationFn: (_) async {
          attempts++;
          if (attempts < 2) throw Exception('transient');
          return 'ok';
        },
      );

      await mutation.mutate(null);

      expect(ZenMutation.activeMutations.value, 0);
      expect(mutation.status.value, ZenMutationStatus.success);
    });
  });
}
