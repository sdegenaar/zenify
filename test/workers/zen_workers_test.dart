import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  group('ZenWorkers.ever()', () {
    test('executes on every value change', () {
      final count = 0.obs();
      final executions = <int>[];

      ZenWorkers.ever(count, (value) {
        executions.add(value);
      });

      count.value = 1;
      count.value = 2;
      count.value = 3;

      expect(executions, [1, 2, 3]);
    });

    test('does not execute on same value', () {
      final count = 0.obs();
      int executionCount = 0;

      ZenWorkers.ever(count, (_) {
        executionCount++;
      });

      count.value = 1;
      count.value = 1; // Same value
      count.value = 1; // Same value

      expect(executionCount, 1);
    });

    test('can be disposed', () {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.ever(count, (_) {
        executionCount++;
      });

      count.value = 1;
      expect(executionCount, 1);

      handle.dispose();

      count.value = 2;
      expect(executionCount, 1, reason: 'Should not execute after disposal');
    });

    test('can be paused and resumed', () {
      final count = 0.obs();
      final executions = <int>[];

      final handle = ZenWorkers.ever(count, (value) {
        executions.add(value);
      });

      count.value = 1;
      expect(executions, [1]);

      handle.pause();
      count.value = 2;
      count.value = 3;
      expect(executions, [1], reason: 'Should not execute while paused');

      handle.resume();
      count.value = 4;
      expect(executions, [1, 4]);
    });

    test('handles null values', () {
      final value = Rx<String?>(null);
      final executions = <String?>[];

      ZenWorkers.ever(value, (val) {
        executions.add(val);
      });

      value.value = 'hello';
      value.value = null;
      value.value = 'world';

      expect(executions, ['hello', null, 'world']);
    });

    test('multiple workers on same observable', () {
      final count = 0.obs();
      final executions1 = <int>[];
      final executions2 = <int>[];

      ZenWorkers.ever(count, (value) => executions1.add(value));
      ZenWorkers.ever(count, (value) => executions2.add(value * 2));

      count.value = 1;
      count.value = 2;

      expect(executions1, [1, 2]);
      expect(executions2, [2, 4]);
    });
  });

  group('ZenWorkers.once()', () {
    test('executes only once', () {
      final count = 0.obs();
      int executionCount = 0;

      ZenWorkers.once(count, (_) {
        executionCount++;
      });

      count.value = 1;
      count.value = 2;
      count.value = 3;

      expect(executionCount, 1);
    });

    test('auto-disposes after execution', () {
      final count = 0.obs();
      final executions = <int>[];

      final handle = ZenWorkers.once(count, (value) {
        executions.add(value);
      });

      count.value = 1;
      expect(executions, [1]);

      // Handle should be auto-disposed
      count.value = 2;
      expect(executions, [1]);
      expect(handle.isDisposed, true);
    });

    test('can be disposed before execution', () {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.once(count, (_) {
        executionCount++;
      });

      handle.dispose();

      count.value = 1;
      expect(executionCount, 0);
    });
  });

  group('ZenWorkers.debounce()', () {
    test('executes after debounce duration', () async {
      final count = 0.obs();
      final executions = <int>[];

      ZenWorkers.debounce(
        count,
        (value) => executions.add(value),
        const Duration(milliseconds: 100),
      );

      count.value = 1;
      count.value = 2;
      count.value = 3;

      expect(executions, isEmpty, reason: 'Should not execute immediately');

      await Future.delayed(const Duration(milliseconds: 150));
      expect(executions, [3], reason: 'Should execute with last value');
    });

    test('resets timer on new value', () async {
      final count = 0.obs();
      final executions = <int>[];

      ZenWorkers.debounce(
        count,
        (value) => executions.add(value),
        const Duration(milliseconds: 100),
      );

      count.value = 1;
      await Future.delayed(const Duration(milliseconds: 50));
      count.value = 2;
      await Future.delayed(const Duration(milliseconds: 50));
      count.value = 3;

      expect(executions, isEmpty);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(executions, [3]);
    });

    test('can be disposed', () async {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.debounce(
        count,
        (_) => executionCount++,
        const Duration(milliseconds: 100),
      );

      count.value = 1;
      handle.dispose();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(executionCount, 0);
    });

    test('pause prevents execution', () async {
      final count = 0.obs();
      final executions = <int>[];

      final handle = ZenWorkers.debounce(
        count,
        (value) => executions.add(value),
        const Duration(milliseconds: 100),
      );

      count.value = 1;
      handle.pause();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(executions, isEmpty);

      handle.resume();
      count.value = 2;

      await Future.delayed(const Duration(milliseconds: 150));
      expect(executions, [2]);
    });

    test('throws on negative duration', () {
      final count = 0.obs();

      expect(
        () => ZenWorkers.debounce(
          count,
          (_) {},
          const Duration(milliseconds: -100),
        ),
        throwsArgumentError,
      );
    });
  });

  group('ZenWorkers.throttle()', () {
    test('executes at most once per duration', () async {
      final count = 0.obs();
      final executions = <int>[];

      ZenWorkers.throttle(
        count,
        (value) => executions.add(value),
        const Duration(milliseconds: 100),
      );

      count.value = 1;
      expect(executions, [1], reason: 'First execution is immediate');

      count.value = 2;
      count.value = 3;
      expect(executions, [1], reason: 'Should throttle subsequent calls');

      await Future.delayed(const Duration(milliseconds: 150));
      count.value = 4;
      expect(executions, [1, 4]);
    });

    test('can be disposed', () async {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.throttle(
        count,
        (_) => executionCount++,
        const Duration(milliseconds: 100),
      );

      count.value = 1;
      expect(executionCount, 1);

      handle.dispose();

      await Future.delayed(const Duration(milliseconds: 150));
      count.value = 2;
      expect(executionCount, 1);
    });

    test('pause prevents execution', () async {
      final count = 0.obs();
      final executions = <int>[];

      final handle = ZenWorkers.throttle(
        count,
        (value) => executions.add(value),
        const Duration(milliseconds: 100),
      );

      count.value = 1;
      expect(executions, [1]);

      handle.pause();
      count.value = 2;
      expect(executions, [1]);

      await Future.delayed(const Duration(milliseconds: 150));
      handle.resume();
      count.value = 3;
      expect(executions, [1, 3]);
    });

    test('throws on negative duration', () {
      final count = 0.obs();

      expect(
        () => ZenWorkers.throttle(
          count,
          (_) {},
          const Duration(milliseconds: -100),
        ),
        throwsArgumentError,
      );
    });
  });

  group('ZenWorkers.interval()', () {
    test('executes periodically when observable changes', () async {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.interval(
        count,
        (_) => executionCount++,
        const Duration(milliseconds: 50),
      );

      // Trigger changes
      count.value = 1;
      count.value = 2;

      await Future.delayed(const Duration(milliseconds: 175));
      // Should execute at least once (interval fires every 50ms)
      expect(executionCount, greaterThanOrEqualTo(1));

      handle.dispose();
    });

    test('can be disposed', () async {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.interval(
        count,
        (_) => executionCount++,
        const Duration(milliseconds: 50),
      );

      count.value = 1;

      await Future.delayed(const Duration(milliseconds: 75));
      final countBeforeDispose = executionCount;

      handle.dispose();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, countBeforeDispose);
    });

    test('pause stops interval', () async {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.interval(
        count,
        (_) => executionCount++,
        const Duration(milliseconds: 50),
      );

      count.value = 1;
      count.value = 2;

      await Future.delayed(const Duration(milliseconds: 75));
      final countBeforePause = executionCount;

      handle.pause();

      count.value = 3;
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executionCount, countBeforePause);

      handle.resume();
      count.value = 4;
      await Future.delayed(const Duration(milliseconds: 75));
      expect(executionCount, greaterThan(countBeforePause));

      handle.dispose();
    });

    test('throws on negative duration', () {
      final count = 0.obs();

      expect(
        () => ZenWorkers.interval(
          count,
          (_) {},
          const Duration(milliseconds: -100),
        ),
        throwsArgumentError,
      );
    });
  });

  group('ZenWorkers.condition()', () {
    test('executes only when condition is true', () {
      final count = 0.obs();
      final executions = <int>[];

      ZenWorkers.condition(
        count,
        (value) => value > 5,
        (value) => executions.add(value),
      );

      count.value = 1;
      count.value = 3;
      count.value = 5;
      expect(executions, isEmpty);

      count.value = 6;
      count.value = 10;
      expect(executions, [6, 10]);

      count.value = 3;
      expect(executions, [6, 10]);
    });

    test('can be disposed', () {
      final count = 0.obs();
      int executionCount = 0;

      final handle = ZenWorkers.condition(
        count,
        (value) => value > 5,
        (_) => executionCount++,
      );

      count.value = 10;
      expect(executionCount, 1);

      handle.dispose();

      count.value = 20;
      expect(executionCount, 1);
    });

    test('pause prevents execution', () {
      final count = 0.obs();
      final executions = <int>[];

      final handle = ZenWorkers.condition(
        count,
        (value) => value > 5,
        (value) => executions.add(value),
      );

      count.value = 10;
      expect(executions, [10]);

      handle.pause();
      count.value = 20;
      expect(executions, [10]);

      handle.resume();
      count.value = 30;
      expect(executions, [10, 30]);
    });
  });

  group('ZenWorkerGroup', () {
    test('can add and dispose multiple workers', () {
      final count1 = 0.obs();
      final count2 = 0.obs();
      int executionCount = 0;

      final group = ZenWorkers.group();

      group.add(ZenWorkers.ever(count1, (_) => executionCount++));
      group.add(ZenWorkers.ever(count2, (_) => executionCount++));

      count1.value = 1;
      count2.value = 1;
      expect(executionCount, 2);

      group.dispose();

      count1.value = 2;
      count2.value = 2;
      expect(executionCount, 2);
    });

    test('can pause and resume all workers', () {
      final count1 = 0.obs();
      final count2 = 0.obs();
      final executions = <int>[];

      final group = ZenWorkers.group();

      group.add(ZenWorkers.ever(count1, (value) => executions.add(value)));
      group.add(ZenWorkers.ever(count2, (value) => executions.add(value * 10)));

      count1.value = 1;
      count2.value = 2;
      expect(executions, [1, 20]);

      group.pauseAll();
      count1.value = 3;
      count2.value = 4;
      expect(executions, [1, 20]);

      group.resumeAll();
      count1.value = 5;
      count2.value = 6;
      expect(executions, [1, 20, 5, 60]);

      group.dispose();
    });

    test('tracks active, paused, and total counts', () {
      final group = ZenWorkers.group();
      final count = 0.obs();

      group.add(ZenWorkers.ever(count, (_) {}));
      group.add(ZenWorkers.ever(count, (_) {}));
      group.add(ZenWorkers.ever(count, (_) {}));

      expect(group.length, 3);
      expect(group.activeCount, 3);
      expect(group.pausedCount, 0);

      group.workers[0].pause();
      expect(group.activeCount, 2);
      expect(group.pausedCount, 1);

      group.workers[1].dispose();
      expect(group.length, 2);
      expect(group.activeCount, 1);

      group.dispose();
    });
  });

  group('Worker Edge Cases', () {
    test('disposing already disposed worker is safe', () {
      final count = 0.obs();
      final handle = ZenWorkers.ever(count, (_) {});

      handle.dispose();
      handle.dispose(); // Should not throw
      expect(handle.isDisposed, true);
    });

    test('pausing already paused worker is safe', () {
      final count = 0.obs();
      final handle = ZenWorkers.ever(count, (_) {});

      handle.pause();
      handle.pause(); // Should not throw
      expect(handle.isPaused, true);

      handle.dispose();
    });

    test('resuming already resumed worker is safe', () {
      final count = 0.obs();
      final handle = ZenWorkers.ever(count, (_) {});

      handle.resume();
      handle.resume(); // Should not throw
      expect(handle.isPaused, false);

      handle.dispose();
    });

    test('worker handles exceptions in callback', () {
      final count = 0.obs();
      final executions = <int>[];

      ZenWorkers.ever(count, (value) {
        if (value == 2) {
          throw Exception('Test error');
        }
        executions.add(value);
      });

      count.value = 1;
      expect(executions, [1]);

      count.value = 2; // Should throw but not crash
      count.value = 3;
      expect(executions, [1, 3]);
    });

    test('isActive returns correct state', () {
      final count = 0.obs();
      final handle = ZenWorkers.ever(count, (_) {});

      expect(handle.isActive, true);

      handle.pause();
      expect(handle.isActive, false);

      handle.resume();
      expect(handle.isActive, true);

      handle.dispose();
      expect(handle.isActive, false);
    });
  });

  group('Worker Memory Management', () {
    test('disposed worker releases references', () {
      final count = 0.obs();
      final handle = ZenWorkers.ever(count, (_) {});

      expect(handle.isDisposed, false);
      handle.dispose();
      expect(handle.isDisposed, true);
    });

    test('worker group releases all workers', () {
      final group = ZenWorkers.group();

      for (var i = 0; i < 10; i++) {
        final count = 0.obs();
        group.add(ZenWorkers.ever(count, (_) {}));
      }

      expect(group.length, 10);
      group.dispose();
      expect(group.isDisposed, true);
    });
  });

  group('Worker Combine', () {
    test('combine disposes all workers', () {
      final count1 = 0.obs();
      final count2 = 0.obs();
      int executionCount = 0;

      final worker1 = ZenWorkers.ever(count1, (_) => executionCount++);
      final worker2 = ZenWorkers.ever(count2, (_) => executionCount++);

      final combined = ZenWorkers.combine([worker1, worker2]);

      count1.value = 1;
      count2.value = 1;
      expect(executionCount, 2);

      combined.dispose();

      count1.value = 2;
      count2.value = 2;
      expect(executionCount, 2);
    });
  });
}
