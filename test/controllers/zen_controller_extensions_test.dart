import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for ZenController extension methods (uncovered lines):
/// - L321: pauseAllWorkers group.pauseAll()
/// - L333: resumeAllWorkers group.resumeAll()
/// - L631,632: worker group creation
/// - L659,660: worker group disposal
/// - L773,779,781,783: ZenControllerWorkerExtension.createWorkers on disposed
/// - L801,810,822: disposeWorkers error, pauseSpecificWorkers, resumeSpecificWorkers
/// - L879,888,897+: autoDispose error and limited worker
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // pauseAllWorkers / resumeAllWorkers with worker groups
  // ══════════════════════════════════════════════════════════
  group('ZenController.pauseAllWorkers / resumeAllWorkers with groups', () {
    test('pauseAllWorkers pauses individual workers', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx = Rx<int>(0);
      int calls = 0;
      ctrl.ever<int>(rx, (_) => calls++);

      ctrl.pauseAllWorkers();
      rx.value = 1;
      expect(calls, 0); // paused, should not fire

      ctrl.resumeAllWorkers();
      rx.value = 2;
      expect(calls, 1); // resumed, fires once
    });

    test('pauseAllWorkers / resumeAllWorkers on disposed controller is safe',
        () {
      final ctrl = _WorkerCtrl();
      ctrl.dispose();
      expect(() => ctrl.pauseAllWorkers(), returnsNormally);
      expect(() => ctrl.resumeAllWorkers(), returnsNormally);
    });

    test('pauseWorkers convenience alias works', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      expect(() => ctrl.pauseWorkers(), returnsNormally);
      expect(() => ctrl.resumeWorkers(), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenControllerWorkerExtension
  // ══════════════════════════════════════════════════════════
  group('ZenControllerWorkerExtension', () {
    test('createWorkers creates multiple workers', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx1 = Rx<int>(0);
      final rx2 = Rx<int>(0);
      int total = 0;

      final workers = ctrl.createWorkers([
        () => ctrl.ever<int>(rx1, (_) => total++),
        () => ctrl.ever<int>(rx2, (_) => total++),
      ]);

      rx1.value = 1;
      rx2.value = 1;
      expect(total, 2);
      expect(workers.length, 2);
    });

    test('createWorkers throws StateError on disposed controller', () {
      final ctrl = _WorkerCtrl();
      ctrl.dispose();
      expect(
        () => ctrl.createWorkers([() => ctrl.ever<int>(Rx<int>(0), (_) {})]),
        throwsA(isA<StateError>()),
      );
    });

    test('disposeWorkers disposes all workers', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx = Rx<int>(0);
      int calls = 0;

      final workers = ctrl.createWorkers([
        () => ctrl.ever<int>(rx, (_) => calls++),
      ]);

      ctrl.disposeWorkers(workers);
      rx.value = 1;
      expect(calls, 0); // disposed, should not fire
    });

    test('pauseSpecificWorkers pauses subset of workers', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx1 = Rx<int>(0);
      final rx2 = Rx<int>(0);
      int count1 = 0, count2 = 0;

      final w1 = ctrl.ever<int>(rx1, (_) => count1++);
      ctrl.ever<int>(rx2, (_) => count2++); // w2 runs independently

      ctrl.pauseSpecificWorkers([w1]);
      rx1.value = 1;
      rx2.value = 1;
      expect(count1, 0); // paused
      expect(count2, 1); // still running

      ctrl.resumeSpecificWorkers([w1]);
      rx1.value = 2;
      expect(count1, 1); // resumed
    });

    test('pauseSpecificWorkers is safe on disposed controller', () {
      final ctrl = _WorkerCtrl();
      final rx = Rx<int>(0);
      final w = ctrl.ever<int>(rx, (_) {});
      ctrl.dispose();
      expect(() => ctrl.pauseSpecificWorkers([w]), returnsNormally);
    });

    test('resumeSpecificWorkers is safe on disposed controller', () {
      final ctrl = _WorkerCtrl();
      final rx = Rx<int>(0);
      final w = ctrl.ever<int>(rx, (_) {});
      ctrl.dispose();
      expect(() => ctrl.resumeSpecificWorkers([w]), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenControllerAdvancedExtension.autoDispose
  // ══════════════════════════════════════════════════════════
  group('ZenControllerAdvancedExtension.autoDispose', () {
    test('autoDispose disposes handle when condition is met', () async {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx = Rx<int>(0);
      int calls = 0;

      final handle = ctrl.autoDispose<int>(
        rx,
        (v) => v >= 3, // dispose when v >= 3
        (_) => calls++,
      );

      rx.value = 1;
      rx.value = 2;
      rx.value = 3; // should auto-dispose after this

      expect(calls, 3);
      expect(handle.isDisposed, true);
    });

    test('autoDispose disposes handle on error', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx = Rx<int>(0);

      final handle = ctrl.autoDispose<int>(
        rx,
        (_) => false,
        (_) => throw Exception('callback boom'),
      );

      rx.value = 1;
      // After error, handle is disposed
      expect(handle.isDisposed, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenControllerAdvancedExtension.limited
  // ══════════════════════════════════════════════════════════
  group('ZenControllerAdvancedExtension.limited', () {
    test('limited executes at most maxExecutions times', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx = Rx<int>(0);
      int calls = 0;

      final handle = ctrl.limited<int>(rx, (_) => calls++, 2);
      rx.value = 1;
      rx.value = 2;
      rx.value = 3; // no-op after 2 executions

      expect(calls, 2);
      expect(handle.isDisposed, true);
    });

    test('limited throws ArgumentError when maxExecutions <= 0', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      expect(
        () => ctrl.limited<int>(Rx<int>(0), (_) {}, 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('limited disposes handle on callback error', () {
      final ctrl = _WorkerCtrl();
      Zen.put<_WorkerCtrl>(ctrl);
      final rx = Rx<int>(0);

      final handle = ctrl.limited<int>(
        rx,
        (_) => throw Exception('limited error'),
        3,
      );

      rx.value = 1;
      expect(handle.isDisposed, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // FluentExtension.also
  // ══════════════════════════════════════════════════════════
  group('FluentExtension.also', () {
    test('also applies block and returns self', () {
      final ctrl = _WorkerCtrl();
      bool applied = false;
      final result = ctrl.also((_) => applied = true);
      expect(applied, true);
      expect(result, same(ctrl));
    });
  });
}

class _WorkerCtrl extends ZenController {}
