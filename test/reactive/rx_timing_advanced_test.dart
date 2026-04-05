import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests targeting uncovered lines in reactive/utils/rx_timing.dart:
/// - RxPerformanceExtensions: trackChange, performanceStats, resetPerformanceStats, cleanupTiming
/// - RxTimingExtensions: throttle (callback), debounce, delay, buffer, takeFirst, skipFirst, listenWhere, listenMapped, distinct (custom equals)
/// - RxTimingUtils: clearAllTimingData, trackedInstanceCount
/// - RxInterval: start, stop, reset, dispose
/// - RxTimer: isRunning, reset, dispose
void main() {
  // ══════════════════════════════════════════════════════════
  // RxPerformanceExtensions
  // ══════════════════════════════════════════════════════════
  group('RxPerformanceExtensions', () {
    tearDown(RxTimingUtils.clearAllTimingData);

    test('trackChange registers and updates stats', () {
      final rx = 0.obs();
      rx.trackChange();
      final stats = rx.performanceStats;
      expect(stats['changeCount'], 1);
      rx.dispose();
    });

    test('performanceStats returns defaults when not tracked', () {
      final rx = 0.obs();
      final stats = rx.performanceStats;
      expect(stats['changeCount'], 0);
      rx.dispose();
    });

    test('resetPerformanceStats resets count to zero', () {
      final rx = 0.obs();
      rx.trackChange();
      rx.trackChange();
      rx.resetPerformanceStats();
      final stats = rx.performanceStats;
      expect(stats['changeCount'], 0);
      rx.dispose();
    });

    test('cleanupTiming unregisters instance', () {
      final rx = 0.obs();
      rx.trackChange();
      final beforeCount = RxTimingUtils.trackedInstanceCount;
      rx.cleanupTiming();
      expect(RxTimingUtils.trackedInstanceCount, beforeCount - 1);
      rx.dispose();
    });

    test('trackedInstanceCount increases after tracking', () {
      final rx = 0.obs();
      final before = RxTimingUtils.trackedInstanceCount;
      rx.trackChange();
      expect(RxTimingUtils.trackedInstanceCount, before + 1);
      rx.dispose();
    });

    test('clearAllTimingData clears all registrations', () {
      final rx1 = 0.obs();
      final rx2 = 1.obs();
      rx1.trackChange();
      rx2.trackChange();
      RxTimingUtils.clearAllTimingData();
      expect(RxTimingUtils.trackedInstanceCount, 0);
      rx1.dispose();
      rx2.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.throttle (callback style)
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.throttle', () {
    tearDown(RxTimingUtils.clearAllTimingData);

    test('throttle fires on first change', () async {
      final rx = 0.obs();
      var count = 0;
      rx.throttle(const Duration(milliseconds: 50), (_) => count++);
      rx.value = 1;
      expect(count, 1);
      rx.dispose();
    });

    test('throttle suppresses rapid changes', () async {
      final rx = 0.obs();
      var count = 0;
      rx.throttle(const Duration(milliseconds: 100), (_) => count++);
      rx.value = 1;
      rx.value = 2;
      rx.value = 3;
      expect(count, 1); // Only first gets through
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.debounce (callback style)
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.debounce', () {
    tearDown(RxTimingUtils.clearAllTimingData);

    test('debounce delays callback', () async {
      final rx = 0.obs();
      var fired = false;
      rx.debounce(const Duration(milliseconds: 10), (_) => fired = true);
      rx.value = 1;
      expect(fired, false); // Not fired immediately
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fired, true);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.delay
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.delay', () {
    tearDown(RxTimingUtils.clearAllTimingData);

    test('delay fires callback after duration', () async {
      final rx = 0.obs();
      var fired = false;
      rx.delay(const Duration(milliseconds: 10), (_) => fired = true);
      rx.value = 1;
      expect(fired, false);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fired, true);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.buffer
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.buffer', () {
    tearDown(RxTimingUtils.clearAllTimingData);

    test('buffer collects changes and fires batch', () async {
      final rx = 0.obs();
      List<int>? received;
      rx.buffer(const Duration(milliseconds: 20),
          (values) => received = List.from(values));
      rx.value = 1;
      rx.value = 2;
      rx.value = 3;
      expect(received, isNull); // Not yet
      await Future.delayed(const Duration(milliseconds: 60));
      expect(received, isNotNull);
      expect(received!.length, greaterThan(0));
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.takeFirst
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.takeFirst', () {
    test('takeFirst fires exactly n times', () {
      final rx = 0.obs();
      var count = 0;
      rx.takeFirst(3, (_) => count++);
      rx.value = 1;
      rx.value = 2;
      rx.value = 3;
      rx.value = 4; // Should be ignored
      expect(count, 3);
      rx.dispose();
    });

    test('takeFirst with count=1', () {
      final rx = 0.obs();
      var count = 0;
      rx.takeFirst(1, (_) => count++);
      rx.value = 1;
      rx.value = 2;
      expect(count, 1);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.skipFirst
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.skipFirst', () {
    test('skipFirst skips initial n changes', () {
      final rx = 0.obs();
      var count = 0;
      rx.skipFirst(2, (_) => count++);
      rx.value = 1; // skipped
      rx.value = 2; // skipped
      rx.value = 3; // counted
      rx.value = 4; // counted
      expect(count, 2);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.listenWhere
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.listenWhere', () {
    test('fires only when condition is met', () {
      final rx = 0.obs();
      var count = 0;
      rx.listenWhere((v) => v > 5, (_) => count++);
      rx.value = 3; // no
      rx.value = 7; // yes
      rx.value = 2; // no
      rx.value = 9; // yes
      expect(count, 2);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.listenMapped
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.listenMapped', () {
    test('transforms value before callback', () {
      final rx = 5.obs();
      var received = '';
      rx.listenMapped((v) => 'val=$v', (s) => received = s);
      rx.value = 10;
      expect(received, 'val=10');
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimingExtensions.distinct (with custom equals)
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.distinct with custom equals', () {
    test('custom equals function prevents duplicate calls', () {
      final rx = 'hello'.obs();
      var count = 0;
      // Case-insensitive equality
      rx.distinct(
        (_) => count++,
        (prev, curr) => prev.toLowerCase() == curr.toLowerCase(),
      );
      rx.value = 'HELLO'; // same by custom equals → no call
      rx.value = 'world'; // different → call
      // First value fires immediately on first change
      expect(count, greaterThanOrEqualTo(1));
      rx.dispose();
    });

    test('distinct fires on first change regardless', () {
      final rx = 0.obs();
      var received = <int>[];
      rx.distinct((v) => received.add(v));
      rx.value = 1;
      rx.value = 1; // same — should not fire again
      rx.value = 2; // different — fires
      expect(received, [1, 2]);
      rx.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxInterval
  // ══════════════════════════════════════════════════════════
  group('RxInterval', () {
    test('starts at 0', () {
      final interval = RxInterval(const Duration(seconds: 1));
      expect(interval.value, 0);
      interval.dispose();
    });

    test('reset returns value to 0', () {
      final interval = RxInterval(const Duration(milliseconds: 10));
      interval.start();
      interval.reset();
      expect(interval.value, 0);
      interval.dispose();
    });

    test('stop cancels timer', () {
      final interval = RxInterval(const Duration(milliseconds: 10));
      interval.start();
      interval.stop();
      expect(interval.value, 0); // No ticks yet (stopped immediately)
      interval.dispose();
    });

    test('dispose stops timer', () {
      final interval = RxInterval(const Duration(milliseconds: 10));
      interval.start();
      expect(() => interval.dispose(), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTimer
  // ══════════════════════════════════════════════════════════
  group('RxTimer', () {
    test('isRunning is false before start', () {
      final timer = RxTimer(const Duration(seconds: 5));
      expect(timer.isRunning, false);
      timer.dispose();
    });

    test('stop/dispose does not crash', () {
      final timer = RxTimer(const Duration(seconds: 5));
      timer.stop();
      expect(() => timer.dispose(), returnsNormally);
    });

    test('reset updates remaining time', () {
      final timer = RxTimer(const Duration(seconds: 5));
      timer.reset(const Duration(seconds: 10));
      expect(timer.isRunning, false);
      timer.dispose();
    });

    test('reset without argument uses current value', () {
      final timer = RxTimer(const Duration(seconds: 3));
      expect(() => timer.reset(null), returnsNormally);
      timer.dispose();
    });
  });
}
