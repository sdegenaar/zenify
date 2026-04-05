import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() => Zen.init());
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // didChangeAppLifecycleState routing
  // ══════════════════════════════════════════════════════════
  group('ZenController.didChangeAppLifecycleState', () {
    test('resumed calls onResume', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(ctrl.calls, contains('resume'));
    });

    test('paused calls onPause', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(ctrl.calls, contains('pause'));
    });

    test('inactive calls onInactive', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(ctrl.calls, contains('inactive'));
    });

    test('detached calls onDetached', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(ctrl.calls, contains('detached'));
    });

    test('hidden calls onHidden', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(ctrl.calls, contains('hidden'));
    });

    test('no lifecycle call on disposed controller', () {
      final ctrl = _TrackCtrl();
      ctrl.dispose();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(ctrl.calls, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════
  // obs/obsList/obsMap/obsSet on disposed controller
  // ══════════════════════════════════════════════════════════
  group('ZenController reactive creation on disposed', () {
    test('obs throws StateError after dispose', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.obs(0), throwsStateError);
    });

    test('obsList throws StateError after dispose', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.obsList<int>(), throwsStateError);
    });

    test('obsMap throws StateError after dispose', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.obsMap<String, int>(), throwsStateError);
    });

    test('obsSet throws StateError after dispose', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.obsSet<String>(), throwsStateError);
    });
  });

  // ══════════════════════════════════════════════════════════
  // trackReactive on disposed — no-op
  // ══════════════════════════════════════════════════════════
  group('ZenController.trackReactive', () {
    test('trackReactive on disposed does not throw', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.trackReactive(0.obs()), returnsNormally);
    });

    test('trackReactive on live controller tracks object', () {
      final ctrl = _NoopCtrl();
      ctrl.trackReactive(0.obs());
      expect(ctrl.reactiveObjectCount, 1);
      ctrl.dispose();
    });

    test('duplicate trackReactive is ignored', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      ctrl.trackReactive(rx);
      ctrl.trackReactive(rx);
      expect(ctrl.reactiveObjectCount, 1);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // trackController
  // ══════════════════════════════════════════════════════════
  group('ZenController.trackController', () {
    test('throws StateError when tracking on disposed parent', () {
      final parent = _NoopCtrl();
      final child = _NoopCtrl();
      parent.dispose();
      expect(() => parent.trackController(child), throwsStateError);
      child.dispose();
    });

    test('tracks child controller', () {
      final parent = _NoopCtrl();
      final child = _NoopCtrl();
      parent.trackController(child);
      expect(parent.childControllerCount, 1);
      parent.dispose(); // disposes child too
    });

    test('duplicate trackController is ignored', () {
      final parent = _NoopCtrl();
      final child = _NoopCtrl();
      parent.trackController(child);
      parent.trackController(child);
      expect(parent.childControllerCount, 1);
      parent.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // reactiveStats / childControllerStats
  // ══════════════════════════════════════════════════════════
  group('ZenController stats maps', () {
    test('reactiveStats shows types and counts', () {
      final ctrl = _NoopCtrl();
      ctrl.trackReactive(0.obs());
      ctrl.trackReactive(''.obs());
      final stats = ctrl.reactiveStats;
      expect(stats.values.fold(0, (a, b) => a + b), 2);
      ctrl.dispose();
    });

    test('childControllerStats shows types and counts', () {
      final parent = _NoopCtrl();
      final child1 = _NoopCtrl();
      final child2 = _NoopCtrl();
      parent.trackController(child1);
      parent.trackController(child2);
      final stats = parent.childControllerStats;
      expect(stats.values.fold(0, (a, b) => a + b), 2);
      parent.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // addUpdateListener / removeUpdateListener / update
  // ══════════════════════════════════════════════════════════
  group('ZenController update listeners', () {
    test('update() notifies all listeners when no IDs given', () {
      final ctrl = _NoopCtrl();
      var count = 0;
      ctrl.addUpdateListener('a', () => count++);
      ctrl.addUpdateListener('b', () => count++);
      ctrl.update();
      expect(count, 2);
      ctrl.dispose();
    });

    test('update([id]) notifies only specific listeners', () {
      final ctrl = _NoopCtrl();
      var aCount = 0;
      var bCount = 0;
      ctrl.addUpdateListener('a', () => aCount++);
      ctrl.addUpdateListener('b', () => bCount++);
      ctrl.update(['a']);
      expect(aCount, 1);
      expect(bCount, 0);
      ctrl.dispose();
    });

    test('removeUpdateListener stops notifications', () {
      final ctrl = _NoopCtrl();
      var count = 0;
      void listener() => count++;
      ctrl.addUpdateListener('x', listener);
      ctrl.update(['x']);
      expect(count, 1);
      ctrl.removeUpdateListener('x', listener);
      ctrl.update(['x']);
      expect(count, 1); // still 1
      ctrl.dispose();
    });

    test('update on disposed controller does nothing', () {
      final ctrl = _NoopCtrl();
      var count = 0;
      ctrl.addUpdateListener('z', () => count++);
      ctrl.dispose();
      ctrl.update();
      expect(count, 0);
    });

    test('addUpdateListener on disposed controller does nothing', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.addUpdateListener('k', () {}), returnsNormally);
    });

    test('removeUpdateListener on disposed controller does nothing', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(
        () => ctrl.removeUpdateListener('k', () {}),
        returnsNormally,
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // addDisposer
  // ══════════════════════════════════════════════════════════
  group('ZenController.addDisposer', () {
    test('disposer is called on dispose', () {
      final ctrl = _NoopCtrl();
      var called = false;
      ctrl.addDisposer(() => called = true);
      ctrl.dispose();
      expect(called, true);
    });

    test('addDisposer on disposed controller does nothing', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      var called = false;
      ctrl.addDisposer(() => called = true);
      // disposer is not run even if we call dispose again
      ctrl.dispose();
      expect(called, false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // createEffect
  // ══════════════════════════════════════════════════════════
  group('ZenController.createEffect', () {
    test('creates and returns an effect', () {
      final ctrl = _NoopCtrl();
      final effect = ctrl.createEffect<int>(name: 'test');
      expect(effect, isNotNull);
      ctrl.dispose();
    });

    test('throws on disposed controller', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.createEffect<int>(name: 'x'), throwsStateError);
    });
  });

  // ══════════════════════════════════════════════════════════
  // getResourceStats
  // ══════════════════════════════════════════════════════════
  group('ZenController.getResourceStats', () {
    test('returns all expected keys', () {
      final ctrl = _NoopCtrl();
      final stats = ctrl.getResourceStats();
      expect(stats.containsKey('reactive_objects'), true);
      expect(stats.containsKey('child_controllers'), true);
      expect(stats.containsKey('workers'), true);
      expect(stats.containsKey('effects'), true);
      expect(stats.containsKey('disposers'), true);
      expect(stats.containsKey('is_disposed'), true);
      ctrl.dispose();
    });

    test('is_disposed reflects disposal state', () {
      final ctrl = _NoopCtrl();
      expect(ctrl.getResourceStats()['is_disposed'], false);
      ctrl.dispose();
      // Can't call after dispose due to guard, but we verified before
    });
  });

  // ══════════════════════════════════════════════════════════
  // onInit / onReady idempotency
  // ══════════════════════════════════════════════════════════
  group('ZenController lifecycle idempotency', () {
    test('onInit is idempotent', () {
      final ctrl = _NoopCtrl();
      ctrl.onInit();
      ctrl.onInit(); // second call should be no-op
      expect(ctrl.isInitialized, true);
      ctrl.dispose();
    });

    test('onReady is idempotent', () {
      final ctrl = _NoopCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.onReady(); // second call should be no-op
      expect(ctrl.isReady, true);
      ctrl.dispose();
    });

    test('dispose is idempotent', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.dispose(), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // pauseAllWorkers / resumeAllWorkers on disposed
  // ══════════════════════════════════════════════════════════
  group('ZenController worker methods on disposed', () {
    test('pauseAllWorkers on disposed does nothing', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.pauseAllWorkers(), returnsNormally);
    });

    test('resumeAllWorkers on disposed does nothing', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.resumeAllWorkers(), returnsNormally);
    });

    test('activeWatcherCount is 0 with no workers', () {
      final ctrl = _NoopCtrl();
      expect(ctrl.activeWatcherCount, 0);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenControllerWorkerExtension
  // ══════════════════════════════════════════════════════════
  group('ZenControllerWorkerExtension', () {
    test('createWorkers on disposed throws', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(
        () => ctrl.createWorkers([() => ctrl.ever(0.obs(), (_) {})]),
        throwsStateError,
      );
    });

    test('disposeWorkers disposes the worker handle', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      final handle = ctrl.ever(rx, (_) {});
      expect(handle.isDisposed, false);
      ctrl.disposeWorkers([handle]);
      expect(handle.isDisposed, true);
      ctrl.dispose();
    });

    test('pauseSpecificWorkers on disposed does nothing', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.pauseSpecificWorkers([]), returnsNormally);
    });

    test('resumeSpecificWorkers on disposed does nothing', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.resumeSpecificWorkers([]), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenControllerAdvancedExtension
  // ══════════════════════════════════════════════════════════
  group('ZenControllerAdvancedExtension.limited', () {
    test('limited throws when maxExecutions <= 0', () {
      final ctrl = _NoopCtrl();
      expect(
        () => ctrl.limited(0.obs(), (_) {}, 0),
        throwsArgumentError,
      );
      ctrl.dispose();
    });

    test('limited fires callback exactly N times', () async {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      var count = 0;
      ctrl.limited(rx, (_) => count++, 2);
      rx.value = 1;
      rx.value = 2;
      rx.value = 3; // should not fire
      await Future.delayed(Duration.zero);
      expect(count, 2);
      ctrl.dispose();
    });
  });

  group('ZenControllerAdvancedExtension.autoDispose', () {
    test('auto-disposes handle when condition is met', () async {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      final handle = ctrl.autoDispose(
        rx,
        (v) => v >= 5,
        (_) {}, // callback
      );
      rx.value = 5;
      await Future.delayed(Duration.zero);
      expect(handle.isDisposed, true);
      ctrl.dispose();
    });

    test('handle stays active when condition not met', () async {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      final handle = ctrl.autoDispose(rx, (v) => v >= 100, (_) {});
      rx.value = 1;
      await Future.delayed(Duration.zero);
      expect(handle.isDisposed, false);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // FluentExtension.also
  // ══════════════════════════════════════════════════════════
  group('FluentExtension.also', () {
    test('also executes block and returns self', () {
      var sideEffect = 0;
      final result = 42.also((_) => sideEffect = 1);
      expect(result, 42);
      expect(sideEffect, 1);
    });

    test('also works on strings', () {
      final result = 'hello'.also((s) => expect(s, 'hello'));
      expect(result, 'hello');
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenDIIntegration mixin
  // ══════════════════════════════════════════════════════════
  group('ZenDIIntegration mixin', () {
    test('onDIRegistered does not crash', () {
      final ctrl = _DICtrl();
      expect(() => ctrl.onDIRegistered(), returnsNormally);
    });

    test('onDIDisposing does not crash', () {
      final ctrl = _DICtrl();
      expect(() => ctrl.onDIDisposing(), returnsNormally);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // didChangeAppLifecycleState on disposed controller
  // The top-level guard `if (_disposed) return;` prevents all lifecycle
  // hooks from being called via the normal dispatch path.
  // ══════════════════════════════════════════════════════════
  group(
      'ZenController app lifecycle on disposed (via didChangeAppLifecycleState)',
      () {
    test('disposed controller: resumed does not call onResume', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.dispose();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(ctrl.calls, isEmpty);
    });

    test('disposed controller: paused does not call onPause', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.dispose();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(ctrl.calls, isEmpty);
    });

    test('disposed controller: inactive does not call onInactive', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.dispose();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(ctrl.calls, isEmpty);
    });

    test('disposed controller: detached does not call onDetached', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.dispose();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(ctrl.calls, isEmpty);
    });

    test('disposed controller: hidden does not call onHidden', () {
      final ctrl = _TrackCtrl();
      ctrl.onInit();
      ctrl.onReady();
      ctrl.dispose();
      ctrl.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(ctrl.calls, isEmpty);
    });
  });
}

// ── Test controllers ──
class _NoopCtrl extends ZenController {}

class _TrackCtrl extends ZenController {
  final calls = <String>[];

  @override
  void onResume() {
    calls.add('resume');
    super.onResume();
  }

  @override
  void onPause() {
    calls.add('pause');
    super.onPause();
  }

  @override
  void onInactive() {
    calls.add('inactive');
    super.onInactive();
  }

  @override
  void onDetached() {
    calls.add('detached');
    super.onDetached();
  }

  @override
  void onHidden() {
    calls.add('hidden');
    super.onHidden();
  }
}

class _DICtrl extends ZenController with ZenDIIntegration {}
