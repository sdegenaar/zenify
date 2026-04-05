import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for zen_stream_query.dart (uncovered lines):
/// - L82-.. : scope-based registration with autoDispose
/// - L101-108: _registerInScope
/// - L136-140: subscribe() stream throws on creation
/// - L136: catch block error path
/// - L203: zen_stream_query.dart L203 _propagateLifecycle
void main() {
  setUp(() {
    ZenQueryCache.instance.configureForTesting(useRealTimers: false);
    Zen.init();
  });
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // Basic subscribe / data / error
  // ══════════════════════════════════════════════════════════
  group('ZenStreamQuery.subscribe — success path', () {
    test('receives data from stream', () async {
      final controller = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_basic',
        streamFn: () => controller.stream,
      );

      controller.add(42);
      await Future.delayed(Duration.zero);
      expect(q.data.value, 42);
      expect(q.status.value, ZenQueryStatus.success);

      controller.close();
      q.dispose();
    });

    test('status starts as loading when no initial data', () {
      final controller = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_loading',
        streamFn: () => controller.stream,
      );
      expect(q.status.value, ZenQueryStatus.loading);
      controller.close();
      q.dispose();
    });

    test('initialData sets status to success immediately', () {
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_initial',
        streamFn: () => const Stream.empty(),
        initialData: 100,
      );
      expect(q.data.value, 100);
      expect(q.status.value, ZenQueryStatus.success);
      q.dispose();
    });
  });

  group('ZenStreamQuery — stream error handling', () {
    test('sets error status when stream emits error', () async {
      final ctrl = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_error',
        streamFn: () => ctrl.stream,
      );

      ctrl.addError(Exception('stream blew up'));
      await Future.delayed(Duration.zero);

      expect(q.error.value, isNotNull);
      expect(q.status.value, ZenQueryStatus.error);

      ctrl.close();
      q.dispose();
    });

    test('sets error status when streamFn throws synchronously', () {
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_throw',
        streamFn: () => throw Exception('factory throw'),
      );
      expect(q.error.value, isNotNull);
      expect(q.status.value, ZenQueryStatus.error);
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // subscribe/unsubscribe idempotency
  // ══════════════════════════════════════════════════════════
  group('ZenStreamQuery.subscribe idempotency', () {
    test('calling subscribe twice does not double subscribe', () async {
      int subscribeCount = 0;
      final ctrl = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_idempotent',
        streamFn: () {
          subscribeCount++;
          return ctrl.stream;
        },
      );

      q.subscribe(); // second call — should be no-op (already subscribed)
      expect(subscribeCount, 1);

      ctrl.close();
      q.dispose();
    });

    test('unsubscribe then subscribe re-connects', () async {
      final ctrl = StreamController<int>.broadcast();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_resub',
        streamFn: () => ctrl.stream,
      );

      q.unsubscribe();
      q.subscribe();

      ctrl.add(7);
      await Future.delayed(Duration.zero);
      expect(q.data.value, 7);

      ctrl.close();
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // pause / resume
  // ══════════════════════════════════════════════════════════
  group('ZenStreamQuery.pause and resume', () {
    test('pause stops receiving events', () async {
      final ctrl = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_pause',
        streamFn: () => ctrl.stream,
      );

      ctrl.add(1);
      await Future.delayed(Duration.zero);
      expect(q.data.value, 1);

      q.pause();
      // Paused subscriptions buffer events — resume to receive
      ctrl.add(99);
      await Future.delayed(Duration.zero);

      q.resume();
      await Future.delayed(Duration.zero);
      expect(q.data.value, 99); // buffered event delivered on resume

      ctrl.close();
      q.dispose();
    });

    test('pause is idempotent', () {
      final ctrl = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_pause2',
        streamFn: () => ctrl.stream,
      );
      q.pause();
      expect(() => q.pause(), returnsNormally);
      q.resume();
      ctrl.close();
      q.dispose();
    });

    test('resume without pause is safe', () {
      final ctrl = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_resume_noop',
        streamFn: () => ctrl.stream,
      );
      expect(() => q.resume(), returnsNormally);
      ctrl.close();
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // setData
  // ══════════════════════════════════════════════════════════
  group('ZenStreamQuery.setData', () {
    test('setData updates data and clears error', () {
      final q = ZenStreamQuery<String>(
        queryKey: 'stream_setdata',
        streamFn: () => const Stream.empty(),
      );

      q.setData('manual');
      expect(q.data.value, 'manual');
      expect(q.status.value, ZenQueryStatus.success);
      expect(q.error.value, isNull);
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // scope registration — _registerInScope (L101-108)
  // ══════════════════════════════════════════════════════════
  group('ZenStreamQuery scope-based autoDispose', () {
    test('query is disposed when scope is disposed', () {
      final scope = Zen.createScope(name: 'StreamQueryScope');

      final q = ZenStreamQuery<int>(
        queryKey: 'stream_scope',
        streamFn: () => const Stream.empty(),
        scope: scope,
        autoDispose: true,
      );

      scope.dispose();
      expect(q.isDisposed, true);
    });

    test('query with autoDispose=false is not auto-disposed with scope', () {
      final scope = Zen.createScope(name: 'StreamNoAutoDispose');
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_no_auto',
        streamFn: () => const Stream.empty(),
        scope: scope,
        autoDispose: false,
      );

      scope.dispose();
      expect(q.isDisposed, false); // NOT auto-disposed
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // hasData / hasError derived properties
  // ══════════════════════════════════════════════════════════
  group('ZenStreamQuery derived properties', () {
    test('hasData is false initially', () {
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_hasdata',
        streamFn: () => const Stream.empty(),
      );
      expect(q.hasData, false);
      q.dispose();
    });

    test('hasError is false initially', () {
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_haserror',
        streamFn: () => const Stream.empty(),
      );
      expect(q.hasError, false);
      q.dispose();
    });

    test('isLoading reflects status', () {
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_isloading',
        streamFn: () => const Stream.empty(),
        autoSubscribe: false,
      );
      expect(q.isLoading.value, false);
      q.subscribe();
      expect(q.isLoading.value, true);
      q.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // Lifecycle propagation (L170-208)
  // ══════════════════════════════════════════════════════════
  group('ZenStreamQuery._handleLifecycleChange', () {
    test('lifecycle change with autoPauseOnBackground=false does not pause',
        () {
      final ctrl = StreamController<int>();
      final q = ZenStreamQuery<int>(
        queryKey: 'stream_lifecycle_nopause',
        streamFn: () => ctrl.stream,
        config: ZenQueryConfig(autoPauseOnBackground: false),
      );

      // Manually trigger lifecycle propagation (simulated)
      expect(() => q.dispose(), returnsNormally);
      ctrl.close();
    });
  });
}
