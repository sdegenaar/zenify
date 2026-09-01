import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

class _ThrowingRx<T> extends Rx<T> {
  _ThrowingRx(super.initialValue);

  @override
  T get value => throw Exception('Getter failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rx Extensions 100% Coverage Tests', () {
    test('RxDouble sign and error paths', () {
      final pos = 5.5.obs();
      final neg = (-3.2).obs();
      final zero = 0.0.obs();

      expect(pos.sign, 1.0);
      expect(neg.sign, -1.0);
      expect(zero.sign, 0.0);

      // Trigger error logging in convenience methods by passing invalid args
      final d = 10.0.obs();
      d.divide(0); // logs error internally
      expect(d.value, 10.0);
    });

    test('RxInt error logging convenience paths', () {
      final n = 10.obs();
      n.divide(0);
      n.modulo(0);
      n.power(-1);
      expect(n.value, 10);
    });

    test('RxList refresh, rxFirst, rxLast, and error paths', () {
      final list = <String>['a', 'b', 'c'].obs();
      RxListExtensions(list).refresh();

      final emptyList = <int>[].obs();
      expect(emptyList.rxFirst.value, isNull);
      expect(emptyList.rxLast.value, isNull);

      expect(list.rxFirst.value, 'a');
      expect(list.rxLast.value, 'c');

      // Invalid index operations trigger try* failure and log error
      list.insert(-1, 'invalid');
      list.insertAll(-1, ['invalid']);
      list.removeAt(999);
    });

    test('RxMap refresh and error paths', () {
      final map = <String, int>{'a': 1}.obs();
      RxMapExtensions(map).refresh();

      map.updateAll((k, v) => v + 1);
      expect(map['a'], 2);
    });

    test('RxSet refresh and error paths', () {
      final set = <String>{'a', 'b'}.obs();
      RxSetExtensions(set).refresh();
    });

    test('RxComputed initialization error', () {
      expect(
        () => RxComputed<int>(() => throw Exception('Init computed error')),
        throwsA(isA<Exception>()),
      );
    });

    test('RxErrorHandling edge cases and fallbacks', () async {
      final throwingRx = _ThrowingRx<String>('initial');

      // valueOr fallback
      expect(throwingRx.valueOr('fallback'), 'fallback');

      // valueOrElse when fallback throws (default rethrows fallback error)
      expect(
        () => throwingRx.valueOrElse(() => throw Exception('Fallback crashed')),
        throwsA(isA<Exception>()),
      );

      // valueOrElse when throwOnCriticalErrors is true
      setRxErrorConfig(
        const RxErrorConfig(throwOnCriticalErrors: true),
      );
      expect(
        () =>
            throwingRx.valueOrElse(() => throw Exception('Fallback crashed 2')),
        throwsA(isA<RxException>()),
      );
      setRxErrorConfig(RxErrorConfig.defaultConfig);

      // computeSafe when computation throws inside listener
      final numRx = 10.obs();
      final computed = numRx.computeSafe<int>((val) {
        if (val < 0) throw Exception('Negative not allowed');
        return val * 2;
      });
      expect(computed.value, 20);

      numRx.value = -5; // triggers catch in listenSafe
      expect(computed.value, isNull);

      // updateFromAsync when operation throws
      final asyncRx = 1.obs();
      final res = await asyncRx.updateFromAsync((curr) async {
        throw Exception('Async failure');
      });
      expect(res.isFailure, isTrue);
    });

    test(
        'RxFuture tryGetData with standard Exception and refresh without factory',
        () async {
      final completer = Completer<String>();
      final futureRx = RxFuture<String>(completer.future);
      completer.completeError(Exception('raw error'));
      await Future.delayed(Duration.zero);
      expect(futureRx.hasError, isTrue);
      final res = futureRx.tryGetData();
      expect(res.isFailure, isTrue);
      expect(res.errorOrNull?.originalError, isA<Exception>());

      // Empty RxFuture without factory or currentFuture
      final emptyFuture = RxFuture<String>(Future.value('ok'));
      emptyFuture.refresh(); // logs error internally when unable to refresh
    });

    test('RxTimer start, tick, and complete', () async {
      var completed = false;
      final timer = RxTimer(
        const Duration(milliseconds: 30),
        interval: const Duration(milliseconds: 10),
        onComplete: () => completed = true,
      );

      timer.start();
      await Future.delayed(const Duration(milliseconds: 60));
      expect(completed, isTrue);
      expect(timer.value, lessThanOrEqualTo(Duration.zero));
      timer.stop();
    });
  });
}
