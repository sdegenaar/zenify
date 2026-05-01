import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.init();
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
    ZenMutation.activeMutations.value = 0;
  });

  tearDown(() {
    Zen.reset();
    ZenMutation.activeMutations.value = 0;
  });

  group('ZenMutation.anyMutating — global mutation status tracking', () {
    test('starts at false when no mutations are active', () {
      expect(ZenMutation.anyMutating, false);
      expect(ZenMutation.activeMutations.value, 0);
    });

    test('is true while a single mutation is in-flight', () async {
      final mutation = ZenMutation<String, void>(
        mutationFn: (_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'done';
        },
      );

      final future = mutation.mutate(null);
      await Future.delayed(Duration.zero); // let state update

      expect(ZenMutation.anyMutating, true);
      expect(ZenMutation.activeMutations.value, 1);

      await future;

      expect(ZenMutation.anyMutating, false);
      expect(ZenMutation.activeMutations.value, 0);
    });

    test('tracks concurrent mutations correctly', () async {
      final m1 = ZenMutation<String, void>(
        mutationFn: (_) async {
          await Future.delayed(const Duration(milliseconds: 80));
          return 'a';
        },
      );
      final m2 = ZenMutation<String, void>(
        mutationFn: (_) async {
          await Future.delayed(const Duration(milliseconds: 120));
          return 'b';
        },
      );

      final f1 = m1.mutate(null);
      final f2 = m2.mutate(null);
      await Future.delayed(Duration.zero);

      expect(ZenMutation.activeMutations.value, 2);
      expect(ZenMutation.anyMutating, true);

      await f1;
      expect(ZenMutation.activeMutations.value, 1);
      expect(ZenMutation.anyMutating, true);

      await f2;
      expect(ZenMutation.activeMutations.value, 0);
      expect(ZenMutation.anyMutating, false);
    });

    test('decrements counter even when mutationFn throws', () async {
      final mutation = ZenMutation<String, void>(
        mutationFn: (_) async {
          await Future.delayed(const Duration(milliseconds: 10));
          throw Exception('server error');
        },
      );

      final future = mutation.mutate(null);
      await Future.delayed(Duration.zero);

      expect(ZenMutation.activeMutations.value, 1);

      await future; // returns null on error, does not rethrow

      expect(ZenMutation.activeMutations.value, 0);
      expect(ZenMutation.anyMutating, false);
    });

    test('activeMutations is reactive and can be listened to', () async {
      final observed = <int>[];
      void listener() => observed.add(ZenMutation.activeMutations.value);
      ZenMutation.activeMutations.addListener(listener);

      final mutation = ZenMutation<String, void>(
        mutationFn: (_) async {
          await Future.delayed(const Duration(milliseconds: 20));
          return 'done';
        },
      );

      await mutation.mutate(null);
      await Future.delayed(Duration.zero);

      // Should have seen: 1 (start), 0 (finish)
      expect(observed, contains(1));
      expect(observed.last, 0);

      ZenMutation.activeMutations.removeListener(listener);
    });
  });
}
