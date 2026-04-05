import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for rx_timing.dart targeting uncovered lines:
/// - L59-60: addSubscription
/// - L70: subscription cleanup
/// - L151-184: sample() (StreamSubscription, onListen/onCancel, timer tracking)
/// - L157-168: sample internals
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // RxTimingData.addSubscription / cleanup
  // ══════════════════════════════════════════════════════════
  group('RxPerformanceExtensions', () {
    test('trackChange increments stats', () {
      final rx = Rx<int>(0);
      rx.trackChange();
      rx.trackChange();
      expect(rx.performanceStats['changeCount'], 2);
      rx.cleanupTiming();
    });

    test('resetPerformanceStats resets to 0', () {
      final rx = Rx<int>(0);
      rx.trackChange();
      rx.trackChange();
      rx.resetPerformanceStats();
      expect(rx.performanceStats['changeCount'], 0);
      rx.cleanupTiming();
    });

    test('performanceStats returns defaults when never tracked', () {
      final rx = Rx<int>(0);
      final stats = rx.performanceStats;
      expect(stats['changeCount'], 0);
      expect(stats['lastChangeTime'], isNull);
    });

    test('cleanupTiming unregisters the rx instance', () {
      final rx = Rx<int>(0);
      rx.trackChange();
      rx.cleanupTiming();
      // After cleanup, stats should reset to defaults
      expect(rx.performanceStats['changeCount'], 0);
    });
  });

  // ══════════════════════════════════════════════════════════
  // debounce
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.debounce', () {
    test('debounce fires after inactivity period', () async {
      final rx = Rx<int>(0);
      int calls = 0;
      rx.debounce(const Duration(milliseconds: 30), (_) => calls++);

      rx.value = 1;
      rx.value = 2;
      rx.value = 3;
      expect(calls, 0); // not fired yet

      await Future.delayed(const Duration(milliseconds: 60));
      expect(calls, 1); // fired once after inactivity
      rx.cleanupTiming();
    });

    test('debounce does not fire if rx is not updated again', () async {
      final rx = Rx<int>(0);
      int calls = 0;
      rx.debounce(const Duration(milliseconds: 50), (_) => calls++);

      await Future.delayed(const Duration(milliseconds: 80));
      expect(calls, 0); // no change = no debounce fire
      rx.cleanupTiming();
    });
  });

  // ══════════════════════════════════════════════════════════
  // throttle
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.throttle', () {
    test('throttle limits calls within duration window', () async {
      final rx = Rx<int>(0);
      int calls = 0;
      rx.throttle(const Duration(milliseconds: 50), (_) => calls++);

      rx.value = 1; // fires
      rx.value = 2; // throttled
      rx.value = 3; // throttled
      expect(calls, 1);

      await Future.delayed(const Duration(milliseconds: 80));
      rx.value = 4; // window reset, fires again
      expect(calls, 2);
      rx.cleanupTiming();
    });
  });

  // ══════════════════════════════════════════════════════════
  // sample — covers L151-184 almost entirely
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.sample', () {
    test('sample delivers values at specified interval', () async {
      final rx = Rx<int>(0);
      final received = <int>[];

      final sub = rx.sample(
        const Duration(milliseconds: 30),
        (v) => received.add(v),
      );

      rx.value = 1;
      await Future.delayed(const Duration(milliseconds: 50));
      rx.value = 2;
      await Future.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      expect(received, isNotEmpty);
      rx.cleanupTiming();
    });

    test('sample subscription can be cancelled without crashing', () async {
      final rx = Rx<int>(0);
      final sub = rx.sample(const Duration(milliseconds: 20), (_) {});
      rx.value = 1;
      await Future.delayed(const Duration(milliseconds: 10));
      await expectLater(sub.cancel(), completes);
      rx.cleanupTiming();
    });
  });

  // ══════════════════════════════════════════════════════════
  // delay
  // ══════════════════════════════════════════════════════════
  group('RxTimingExtensions.delay', () {
    test('delay fires callback after specified duration', () async {
      final rx = Rx<int>(0);
      int? received;
      rx.delay(const Duration(milliseconds: 30), (v) => received = v);

      rx.value = 42;
      expect(received, isNull); // not immediate

      await Future.delayed(const Duration(milliseconds: 60));
      expect(received, 42);
      rx.cleanupTiming();
    });
  });
}
