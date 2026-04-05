import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  // ══════════════════════════════════════════════════════════
  // ZenEffect state management
  // ══════════════════════════════════════════════════════════
  group('ZenEffect state management', () {
    test('starts with no data, not loading, no error', () {
      final fx = ZenEffect<int>(name: 'test');
      expect(fx.data.value, isNull);
      expect(fx.isLoading.value, false);
      expect(fx.error.value, isNull);
      expect(fx.hasData, false);
      expect(fx.isDisposed, false);
      fx.dispose();
    });

    test('loading() sets isLoading true and clears error', () {
      final fx = ZenEffect<int>(name: 'test');
      fx.setError(Exception('prev'));
      fx.loading();
      expect(fx.isLoading.value, true);
      expect(fx.error.value, isNull);
      fx.dispose();
    });

    test('success() sets data, clears loading and error', () {
      final fx = ZenEffect<String>(name: 'test');
      fx.loading();
      fx.success('hello');
      expect(fx.data.value, 'hello');
      expect(fx.isLoading.value, false);
      expect(fx.error.value, isNull);
      expect(fx.hasData, true);
      expect(fx.dataWasSet.value, true);
      fx.dispose();
    });

    test('success() with null data still sets hasData = true', () {
      final fx = ZenEffect<String?>(name: 'test');
      fx.success(null);
      expect(fx.hasData, true);
      fx.dispose();
    });

    test('setError() sets error and clears loading', () {
      final fx = ZenEffect<int>(name: 'test');
      fx.loading();
      fx.setError(Exception('oops'));
      expect(fx.error.value, isNotNull);
      expect(fx.isLoading.value, false);
      fx.dispose();
    });

    test('reset() clears all state', () {
      final fx = ZenEffect<int>(name: 'test');
      fx.success(42);
      fx.reset();
      expect(fx.data.value, isNull);
      expect(fx.hasData, false);
      expect(fx.isLoading.value, false);
      expect(fx.error.value, isNull);
      fx.dispose();
    });

    test('clearError() clears only error', () {
      final fx = ZenEffect<int>(name: 'test');
      fx.success(5);
      fx.setError(Exception('e'));
      fx.clearError();
      expect(fx.error.value, isNull);
      expect(fx.data.value, 5); // unchanged
      fx.dispose();
    });

    test('clearData() clears only data and dataWasSet', () {
      final fx = ZenEffect<int>(name: 'test');
      fx.success(10);
      fx.setError(Exception('e'));
      fx.clearData();
      expect(fx.data.value, isNull);
      expect(fx.hasData, false);
      expect(fx.error.value, isNotNull); // unchanged
      fx.dispose();
    });

    test('toString includes name', () {
      final fx = ZenEffect<int>(name: 'myEffect');
      expect(fx.toString(), contains('myEffect'));
      fx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenEffect.run() - async operation management
  // ══════════════════════════════════════════════════════════
  group('ZenEffect.run', () {
    test('run sets loading then success', () async {
      final fx = ZenEffect<int>(name: 'run');
      final result = await fx.run(() async => 99);
      expect(result, 99);
      expect(fx.data.value, 99);
      expect(fx.isLoading.value, false);
      expect(fx.error.value, isNull);
      fx.dispose();
    });

    test('run sets error and rethrows on failure', () async {
      final fx = ZenEffect<int>(name: 'runErr');
      await expectLater(
        () => fx.run(() async => throw Exception('net error')),
        throwsException,
      );
      expect(fx.error.value, isNotNull);
      expect(fx.isLoading.value, false);
      fx.dispose();
    });

    test('run returns null if already disposed', () async {
      final fx = ZenEffect<int>(name: 'disposed');
      fx.dispose();
      final result = await fx.run(() async => 42);
      expect(result, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Dispose guard — all state methods become no-ops after dispose
  // ══════════════════════════════════════════════════════════
  group('ZenEffect dispose guard', () {
    test('loading() is no-op after dispose', () {
      final fx = ZenEffect<int>(name: 'd');
      fx.dispose();
      expect(() => fx.loading(), returnsNormally);
    });

    test('success() is no-op after dispose', () {
      final fx = ZenEffect<int>(name: 'd');
      fx.dispose();
      expect(() => fx.success(1), returnsNormally);
    });

    test('setError() is no-op after dispose', () {
      final fx = ZenEffect<int>(name: 'd');
      fx.dispose();
      expect(() => fx.setError(Exception()), returnsNormally);
    });

    test('reset() is no-op after dispose', () {
      final fx = ZenEffect<int>(name: 'd');
      fx.dispose();
      expect(() => fx.reset(), returnsNormally);
    });

    test('clearError() is no-op after dispose', () {
      final fx = ZenEffect<int>(name: 'd');
      fx.dispose();
      expect(() => fx.clearError(), returnsNormally);
    });

    test('clearData() is no-op after dispose', () {
      final fx = ZenEffect<int>(name: 'd');
      fx.dispose();
      expect(() => fx.clearData(), returnsNormally);
    });

    test('dispose() is idempotent', () {
      final fx = ZenEffect<int>(name: 'd');
      fx.dispose();
      expect(() => fx.dispose(), returnsNormally);
      expect(fx.isDisposed, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // createEffect() helper
  // ══════════════════════════════════════════════════════════
  group('createEffect', () {
    test('creates a ZenEffect with given name', () {
      final fx = createEffect<String>(name: 'helper');
      expect(fx.name, 'helper');
      expect(fx, isA<ZenEffect<String>>());
      fx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenEffectWatch extension
  // ══════════════════════════════════════════════════════════
  group('ZenEffectWatch', () {
    late _TestController ctrl;

    setUp(() {
      Zen.init();
      ctrl = Zen.put(_TestController());
    });
    tearDown(Zen.reset);

    test('watch returns no-op disposer for disposed effect', () {
      final fx = ZenEffect<int>(name: 'disposed');
      fx.dispose();
      final dispose = fx.watch(ctrl, onData: (_) {});
      expect(() => dispose(), returnsNormally);
    });

    test('watch with onData fires on success', () {
      final fx = ZenEffect<int>(name: 'w');
      int? seen;
      fx.watch(ctrl, onData: (v) => seen = v);
      fx.success(7);
      expect(seen, 7);
      fx.dispose();
    });

    test('watch with onLoading fires on loading()', () {
      final fx = ZenEffect<int>(name: 'l');
      bool? seen;
      fx.watch(ctrl, onLoading: (v) => seen = v);
      fx.loading();
      expect(seen, true);
      fx.dispose();
    });

    test('watch with onError fires on setError()', () {
      final fx = ZenEffect<int>(name: 'e');
      Object? seen;
      fx.watch(ctrl, onError: (e) => seen = e);
      fx.setError(Exception('boom'));
      expect(seen, isNotNull);
      fx.dispose();
    });

    test('watch disposer stops further callbacks', () {
      final fx = ZenEffect<int>(name: 'stop');
      int callCount = 0;
      final dispose = fx.watch(ctrl, onData: (_) => callCount++);
      fx.success(1);
      dispose();
      fx.success(2); // should not fire
      expect(callCount, 1);
      fx.dispose();
    });

    test('watchData convenience method works', () {
      final fx = ZenEffect<int>(name: 'wd');
      int? seen;
      fx.watchData(ctrl, (v) => seen = v);
      fx.success(9);
      expect(seen, 9);
      fx.dispose();
    });

    test('watchLoading convenience method works', () {
      final fx = ZenEffect<int>(name: 'wl');
      bool? seen;
      fx.watchLoading(ctrl, (v) => seen = v);
      fx.loading();
      expect(seen, true);
      fx.dispose();
    });

    test('watchError convenience method works', () {
      final fx = ZenEffect<int>(name: 'we');
      Object? seen;
      fx.watchError(ctrl, (e) => seen = e);
      fx.setError(Exception('err'));
      expect(seen, isNotNull);
      fx.dispose();
    });
  });
}

class _TestController extends ZenController {}
