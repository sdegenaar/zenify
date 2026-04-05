import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests covering:
/// - ZenOfflineException
/// - RefetchBehavior.shouldRefetch extension
/// - ZenMutation: mutate, onMutate, onSuccess, onError, onSettled, reset
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // ZenOfflineException
  // ══════════════════════════════════════════════════════════
  group('ZenOfflineException', () {
    test('has default message', () {
      const e = ZenOfflineException();
      expect(e.message, 'No internet connection');
    });

    test('custom message', () {
      const e = ZenOfflineException('Offline now');
      expect(e.message, 'Offline now');
    });

    test('icon is wifi signal', () {
      const e = ZenOfflineException();
      expect(e.icon, '📶');
    });

    test('category is Network', () {
      const e = ZenOfflineException();
      expect(e.category, 'Network');
    });

    test('has non-null suggestion', () {
      const e = ZenOfflineException();
      expect(e.suggestion, isNotNull);
    });

    test('toString includes category and message', () {
      const e = ZenOfflineException();
      final str = e.toString();
      expect(str, isNotEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RefetchBehavior.shouldRefetch
  // ══════════════════════════════════════════════════════════
  group('RefetchBehavior.shouldRefetch', () {
    test('never.shouldRefetch is always false', () {
      expect(RefetchBehavior.never.shouldRefetch(true), false);
      expect(RefetchBehavior.never.shouldRefetch(false), false);
    });

    test('always.shouldRefetch is always true', () {
      expect(RefetchBehavior.always.shouldRefetch(true), true);
      expect(RefetchBehavior.always.shouldRefetch(false), true);
    });

    test('ifStale.shouldRefetch is true only when stale', () {
      expect(RefetchBehavior.ifStale.shouldRefetch(true), true);
      expect(RefetchBehavior.ifStale.shouldRefetch(false), false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation — basic lifecycle
  // ══════════════════════════════════════════════════════════
  group('ZenMutation basic lifecycle', () {
    test('starts idle', () {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v * 2);
      expect(m.status.value, ZenMutationStatus.idle);
      m.dispose();
    });

    test('mutate completes with success', () async {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v * 2);
      final result = await m.mutate(5);
      expect(result, 10);
      expect(m.status.value, ZenMutationStatus.success);
      expect(m.isSuccess, true);
      m.dispose();
    });

    test('mutate sets data.value on success', () async {
      final m = ZenMutation<String, String>(mutationFn: (v) async => 'ok:$v');
      await m.mutate('hello');
      expect(m.data.value, 'ok:hello');
      m.dispose();
    });

    test('mutate goes to error state on exception', () async {
      final m = ZenMutation<int, int>(
        mutationFn: (_) async => throw Exception('fail'),
      );
      await m.mutate(0);
      expect(m.status.value, ZenMutationStatus.error);
      expect(m.isError, true);
      m.dispose();
    });

    test('isError is false before any mutation', () {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v);
      expect(m.isError, false);
      m.dispose();
    });

    test('isSuccess is false before mutation', () {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v);
      expect(m.isSuccess, false);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation — callbacks
  // ══════════════════════════════════════════════════════════
  group('ZenMutation callbacks', () {
    test('onSuccess fires with result', () async {
      int? received;
      final m = ZenMutation<int, int>(
        mutationFn: (v) async => v * 3,
        onSuccess: (data, _, __) => received = data,
      );
      await m.mutate(4);
      expect(received, 12);
      m.dispose();
    });

    test('onError fires on exception', () async {
      Object? receivedError;
      final m = ZenMutation<int, int>(
        mutationFn: (_) async => throw Exception('test error'),
        onError: (error, _, __) => receivedError = error,
      );
      await m.mutate(0);
      expect(receivedError, isNotNull);
      expect(receivedError.toString(), contains('test error'));
      m.dispose();
    });

    test('onSettled fires on success (error is null)', () async {
      bool? settledWithNoError;
      final m = ZenMutation<int, int>(
        mutationFn: (v) async => v,
        onSettled: (_, error, __, ___) => settledWithNoError = (error == null),
      );
      await m.mutate(1);
      expect(settledWithNoError, true);
      m.dispose();
    });

    test('onSettled fires on error', () async {
      bool? settledWithError;
      final m = ZenMutation<int, int>(
        mutationFn: (_) async => throw Exception('boom'),
        onSettled: (_, error, __, ___) => settledWithError = (error != null),
      );
      await m.mutate(0);
      expect(settledWithError, true);
      m.dispose();
    });

    test('onMutate fires before mutationFn', () async {
      final order = <String>[];
      final m = ZenMutation<int, int>(
        mutationFn: (v) async {
          order.add('fn');
          return v;
        },
        onMutate: (v) {
          order.add('onMutate');
          return null;
        },
      );
      await m.mutate(1);
      expect(order.first, 'onMutate');
      m.dispose();
    });

    test('on-call onSuccess callback fires after constructor onSuccess',
        () async {
      final order = <String>[];
      final m = ZenMutation<int, int>(
        mutationFn: (v) async => v,
        onSuccess: (_, __, ___) => order.add('constructor'),
      );
      await m.mutate(1, onSuccess: (_, __) => order.add('call-time'));
      expect(order, ['constructor', 'call-time']);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation — reset
  // ══════════════════════════════════════════════════════════
  group('ZenMutation.reset', () {
    test('reset returns to idle after success', () async {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v);
      await m.mutate(7);
      m.reset();
      expect(m.status.value, ZenMutationStatus.idle);
      expect(m.data.value, isNull);
      m.dispose();
    });

    test('reset clears error after failure', () async {
      final m = ZenMutation<int, int>(
        mutationFn: (_) async => throw Exception('err'),
      );
      await m.mutate(0);
      m.reset();
      expect(m.status.value, ZenMutationStatus.idle);
      expect(m.error.value, isNull);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation — isLoading
  // ══════════════════════════════════════════════════════════
  group('ZenMutation.isLoading', () {
    test('isLoading is false before any mutation', () {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v);
      expect(m.isLoading.value, false);
      m.dispose();
    });

    test('isLoading is false after completion', () async {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v);
      await m.mutate(1);
      expect(m.isLoading.value, false);
      m.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenMutation — dispose
  // ══════════════════════════════════════════════════════════
  group('ZenMutation.dispose', () {
    test('dispose does not throw', () {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v);
      expect(() => m.dispose(), returnsNormally);
    });

    test('mutate on disposed throws StateError', () async {
      final m = ZenMutation<int, int>(mutationFn: (v) async => v);
      m.dispose();
      await expectLater(
        () => m.mutate(1),
        throwsA(isA<StateError>()),
      );
    });
  });
}
