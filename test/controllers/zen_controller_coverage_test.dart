import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Targeted tests for uncovered lines in zen_controller.dart:
/// - obsMap/obsSet after successful creation (hits lines 64-65, 75-76, 86-87)
/// - throttle/interval with zero/negative duration (lines 461, 473)
/// - createWorkerGroup on disposed (line 491)
/// - update cleanup at 100 iterations (line 547)
/// - worker error paths (line 773, 779-783)
/// - disposer error does not stop disposal (line 834)
/// - notifyListeners error handling (line 847-849)
/// - child controller error handling during dispose (line 659)
/// - pauseWorkers/resumeWorkers shortcuts (lines 340, 343)
/// - watch convenience method (line 423-424)
/// - getWorkerStats (line 349)
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // obsMap / obsSet successful creation (hits actual factory lines)
  // ══════════════════════════════════════════════════════════
  group('ZenController.obsMap/obsSet successful creation', () {
    test('obsMap with no initial value creates empty map', () {
      final ctrl = _NoopCtrl();
      final m = ctrl.obsMap<String, int>();
      expect(m.value, isEmpty);
      ctrl.dispose();
    });

    test('obsMap with initial value', () {
      final ctrl = _NoopCtrl();
      final m = ctrl.obsMap<String, int>({'a': 1, 'b': 2});
      expect(m.value, {'a': 1, 'b': 2});
      ctrl.dispose();
    });

    test('obsSet with no initial value creates empty set', () {
      final ctrl = _NoopCtrl();
      final s = ctrl.obsSet<String>();
      expect(s.value, isEmpty);
      ctrl.dispose();
    });

    test('obsSet with initial value', () {
      final ctrl = _NoopCtrl();
      final s = ctrl.obsSet<int>({1, 2, 3});
      expect(s.value, {1, 2, 3});
      ctrl.dispose();
    });

    test('obsList with no initial value creates empty list', () {
      final ctrl = _NoopCtrl();
      final l = ctrl.obsList<String>();
      expect(l.value, isEmpty);
      ctrl.dispose();
    });

    test('obsList with initial value', () {
      final ctrl = _NoopCtrl();
      final l = ctrl.obsList<int>([1, 2, 3]);
      expect(l.value, [1, 2, 3]);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // throttle / interval with zero/negative duration
  // ══════════════════════════════════════════════════════════
  group('ZenController zero-duration workers', () {
    test('throttle with zero duration throws ArgumentError', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      expect(
        () => ctrl.throttle(rx, (_) {}, Duration.zero),
        throwsArgumentError,
      );
      rx.dispose();
      ctrl.dispose();
    });

    test('throttle with negative duration throws ArgumentError', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      expect(
        () => ctrl.throttle(rx, (_) {}, const Duration(seconds: -1)),
        throwsArgumentError,
      );
      rx.dispose();
      ctrl.dispose();
    });

    test('interval with zero duration throws ArgumentError', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      expect(
        () => ctrl.interval(rx, (_) {}, Duration.zero),
        throwsArgumentError,
      );
      rx.dispose();
      ctrl.dispose();
    });

    test('interval with negative duration throws ArgumentError', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      expect(
        () => ctrl.interval(rx, (_) {}, const Duration(milliseconds: -100)),
        throwsArgumentError,
      );
      rx.dispose();
      ctrl.dispose();
    });

    test('debounce with zero duration throws ArgumentError', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      expect(
        () => ctrl.debounce(rx, (_) {}, Duration.zero),
        throwsArgumentError,
      );
      rx.dispose();
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // createWorkerGroup on disposed
  // ══════════════════════════════════════════════════════════
  group('ZenController.createWorkerGroup on disposed', () {
    test('createWorkerGroup on disposed throws StateError', () {
      final ctrl = _NoopCtrl();
      ctrl.dispose();
      expect(() => ctrl.createWorkerGroup(), throwsStateError);
    });

    test('createWorkerGroup on live controller works', () {
      final ctrl = _NoopCtrl();
      final group = ctrl.createWorkerGroup();
      expect(group, isNotNull);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // update at 100 iterations (line 547 cleanup trigger)
  // ══════════════════════════════════════════════════════════
  group('ZenController.update periodic cleanup', () {
    test('100 updates triggers cleanup without crash', () {
      final ctrl = _NoopCtrl();
      ctrl.addUpdateListener('a', () {});
      for (var i = 0; i < 101; i++) {
        ctrl.update();
      }
      expect(ctrl.isDisposed, false);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // pauseWorkers/resumeWorkers (convenience aliases)
  // ══════════════════════════════════════════════════════════
  group('ZenController.pauseWorkers / resumeWorkers', () {
    test('pauseWorkers alias works on live controller', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      ctrl.ever(rx, (_) {});
      expect(() => ctrl.pauseWorkers(), returnsNormally);
      rx.dispose();
      ctrl.dispose();
    });

    test('resumeWorkers alias works on live controller', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      ctrl.ever(rx, (_) {});
      ctrl.pauseWorkers();
      expect(() => ctrl.resumeWorkers(), returnsNormally);
      rx.dispose();
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // watch (legacy convenience method)
  // ══════════════════════════════════════════════════════════
  group('ZenController.watch method', () {
    test('watch creates an ever worker by default', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      final handle = ctrl.watch(rx, (_) {});
      expect(handle, isNotNull);
      rx.dispose();
      ctrl.dispose();
    });

    test('watch on disposed throws StateError', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      ctrl.dispose();
      expect(() => ctrl.watch(rx, (_) {}), throwsStateError);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // error handling: disposer throws during dispose
  // ══════════════════════════════════════════════════════════
  group('ZenController error-tolerant dispose', () {
    test('disposer that throws does not prevent dispose', () {
      final ctrl = _NoopCtrl();
      ctrl.addDisposer(() => throw Exception('disposer error'));
      expect(() => ctrl.dispose(), returnsNormally);
      expect(ctrl.isDisposed, true);
    });

    test('onClose() that throws does not prevent disposal', () {
      final ctrl = _ThrowOnCloseCtrl();
      expect(() => ctrl.dispose(), returnsNormally);
      expect(ctrl.isDisposed, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // error handling: child controller throws during dispose
  // ══════════════════════════════════════════════════════════
  group('ZenController child disposal error handling', () {
    test('child that throws on dispose does not prevent parent disposal', () {
      final parent = _NoopCtrl();
      final child = _ThrowOnCloseCtrl();
      parent.trackController(child);
      expect(() => parent.dispose(), returnsNormally);
      expect(parent.isDisposed, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // error handling: listener throws on update
  // ══════════════════════════════════════════════════════════
  group('ZenController update listener error handling', () {
    test('listener that throws does not crash update', () {
      final ctrl = _NoopCtrl();
      ctrl.addUpdateListener('bad', () => throw Exception('listener error'));
      expect(() => ctrl.update(['bad']), returnsNormally);
      ctrl.dispose();
    });

    test('notifyAll: one bad listener does not skip others', () {
      final ctrl = _NoopCtrl();
      var secondCalled = false;
      ctrl.addUpdateListener('bad', () => throw Exception('error'));
      ctrl.addUpdateListener('good', () => secondCalled = true);
      ctrl.update();
      expect(secondCalled, true);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // getWorkerStats
  // ══════════════════════════════════════════════════════════
  group('ZenController.getWorkerStats', () {
    test('getWorkerStats returns a map', () {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      ctrl.ever(rx, (_) {});
      final stats = ctrl.getWorkerStats();
      expect(stats, isA<Map<String, dynamic>>());
      rx.dispose();
      ctrl.dispose();
    });

    test('getWorkerStats on fresh controller', () {
      final ctrl = _NoopCtrl();
      final stats = ctrl.getWorkerStats();
      expect(stats.containsKey('individual_active'), true);
      ctrl.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // condition worker
  // ══════════════════════════════════════════════════════════
  group('ZenController.condition worker', () {
    test('condition worker fires when condition is met', () async {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      var fired = false;
      ctrl.condition(rx, (v) => v > 5, (_) => fired = true);
      rx.value = 10;
      await Future.delayed(Duration.zero);
      expect(fired, true);
      rx.dispose();
      ctrl.dispose();
    });

    test('condition worker does not fire when condition is false', () async {
      final ctrl = _NoopCtrl();
      final rx = 0.obs();
      var fired = false;
      ctrl.condition(rx, (v) => v > 5, (_) => fired = true);
      rx.value = 3; // below threshold
      await Future.delayed(Duration.zero);
      expect(fired, false);
      rx.dispose();
      ctrl.dispose();
    });
  });
}

class _NoopCtrl extends ZenController {}

class _ThrowOnCloseCtrl extends ZenController {
  @override
  void onClose() {
    try {
      throw Exception('onClose error');
    } finally {
      super.onClose();
    }
  }
}
