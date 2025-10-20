import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/core/zen_config.dart';
import 'package:zenify/core/zen_log_level.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  group('RxFuture', () {
    test('should handle successful futures', () async {
      final future = Future.delayed(const Duration(milliseconds: 10), () => 42);
      final rxFuture = RxFuture<int>(future);

      // Initially loading
      expect(rxFuture.isLoading, true);
      expect(rxFuture.hasData, false);
      expect(rxFuture.hasError, false);

      // Wait for completion
      await future;
      await Future.delayed(
          const Duration(milliseconds: 20)); // Give it time to update

      expect(rxFuture.isLoading, false);
      expect(rxFuture.hasData, true);
      expect(rxFuture.data, 42);
    });

    test('should handle future errors', () async {
      // we don't need to log this
      ZenConfig.logLevel = ZenLogLevel.none;

      final future = Future.delayed(
          const Duration(milliseconds: 10), () => throw 'Test error');
      final rxFuture = RxFuture<int>(future);

      // Wait for error
      try {
        await future;
      } catch (e) {
        // Expected error
      }
      await Future.delayed(const Duration(milliseconds: 20));

      expect(rxFuture.isLoading, false);
      expect(rxFuture.hasError, true);
      expect(rxFuture.originalError, 'Test error'); // ✅ Now works!
    });

    test('should allow setting new futures', () async {
      final rxFuture = RxFuture<String>();

      final future1 =
          Future.delayed(const Duration(milliseconds: 10), () => 'first');
      rxFuture.future = future1;

      await future1;
      await Future.delayed(const Duration(milliseconds: 20));
      expect(rxFuture.data, 'first');

      final future2 =
          Future.delayed(const Duration(milliseconds: 10), () => 'second');
      rxFuture.future = future2;

      await future2;
      await Future.delayed(const Duration(milliseconds: 20));
      expect(rxFuture.data, 'second');
    });

    test('should support manual state setting', () {
      final rxFuture = RxFuture<int>();

      rxFuture.trySetData(100);
      expect(rxFuture.hasData, true);
      expect(rxFuture.data, 100);

      rxFuture.setError('Manual error');
      expect(rxFuture.hasError, true);
      expect(rxFuture.originalError, 'Manual error'); // ✅ Now works!

      rxFuture.setLoading();
      expect(rxFuture.isLoading, true);
    });

    test('should refresh current future', () {
      var callCount = 0;
      Future<int> future() {
        callCount++;
        return Future.delayed(
            const Duration(milliseconds: 10), () => callCount);
      }

      final rxFuture = RxFuture<int>.fromFactory(future);

      rxFuture.refresh();
      expect(callCount, 2); // Original + refresh
    });

    test('should provide both wrapped and original errors', () async {
      final future = Future.delayed(
          const Duration(milliseconds: 10), () => throw 'Test error');
      final rxFuture = RxFuture<int>(future);

      try {
        await future;
      } catch (e) {
        // Expected error
      }
      await Future.delayed(const Duration(milliseconds: 20));

      expect(rxFuture.hasError, true);
      expect(rxFuture.originalError, 'Test error');
      expect(rxFuture.error, isA<RxException>());
      expect(rxFuture.rxError?.originalError, 'Test error');
      expect(rxFuture.errorMessage, 'Test error');
    });
  });
}
