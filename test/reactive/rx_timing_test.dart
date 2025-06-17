
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  setUp(() {
    // Clear timing data before each test to avoid interference
    RxTimingUtils.clearAllTimingData();
  });

  tearDown(() {
    // Clean up after each test
    RxTimingUtils.clearAllTimingData();
  });

  group('RxTiming', () {
    test('should debounce value changes', () async {
      final value = 0.obs();
      var callCount = 0;
      String? lastValue;

      value.debounce(Duration(milliseconds: 100), (val) {
        callCount++;
        lastValue = val.toString();
      });

      // Rapid changes
      value.value = 1;
      value.value = 2;
      value.value = 3;

      expect(callCount, 0); // Should not be called yet

      // Wait for debounce
      await Future.delayed(Duration(milliseconds: 150));

      expect(callCount, 1);
      expect(lastValue, '3'); // Only last value
    });

    test('should throttle value changes', () async {
      final value = 0.obs();
      var callCount = 0;
      final receivedValues = <int>[];

      value.throttle(Duration(milliseconds: 100), (val) {
        callCount++;
        receivedValues.add(val);
      });

      // Rapid changes
      value.value = 1; // Should be called immediately
      value.value = 2; // Should be throttled
      value.value = 3; // Should be throttled

      expect(callCount, 1);
      expect(receivedValues, [1]);

      // Wait for throttle to reset
      await Future.delayed(Duration(milliseconds: 150));

      value.value = 4; // Should be called again
      expect(callCount, 2);
      expect(receivedValues, [1, 4]);
    });

    test('should track performance stats', () {
      final value = 0.obs();

      value.trackChange();
      value.trackChange();
      value.trackChange();

      final stats = value.performanceStats;
      expect(stats['changeCount'], 3);
      expect(stats['lastChangeTime'], isNotNull);
    });

    test('should reset performance stats', () {
      final value = 0.obs();

      value.trackChange();
      value.trackChange();

      value.resetPerformanceStats();

      final stats = value.performanceStats;
      expect(stats['changeCount'], 0);
      expect(stats['lastChangeTime'], isNull);
    });

    test('should cleanup timing resources', () {
      final value = 0.obs();

      value.debounce(Duration(milliseconds: 100), (val) {});
      value.throttle(Duration(milliseconds: 100), (val) {});

      // Should not throw
      expect(() => value.cleanupTiming(), returnsNormally);
    });
  });

  group('RxTimingUtils', () {
    test('should track multiple Rx instances', () {
      final value1 = 0.obs();
      final value2 = 1.obs();

      value1.debounce(Duration(milliseconds: 100), (val) {});
      value2.throttle(Duration(milliseconds: 100), (val) {});

      expect(RxTimingUtils.trackedInstanceCount, 2);

      RxTimingUtils.clearAllTimingData();
      expect(RxTimingUtils.trackedInstanceCount, 0);
    });
  });
}