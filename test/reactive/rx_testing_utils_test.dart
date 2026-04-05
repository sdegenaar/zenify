import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  // ══════════════════════════════════════════════════════════
  // RxTesting.expectRxException
  // ══════════════════════════════════════════════════════════
  group('RxTesting.expectRxException', () {
    test('passes when RxException has expected message', () {
      RxTesting.expectRxException(
        () => throw const RxException('boom'),
        'boom',
      );
    });

    test('throws if no exception thrown', () {
      expect(
        () => RxTesting.expectRxException(() {}, 'expected'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws if wrong exception type thrown', () {
      expect(
        () => RxTesting.expectRxException(
          () => throw Exception('not rx'),
          'not rx',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws if message does not match', () {
      expect(
        () => RxTesting.expectRxException(
          () => throw const RxException('actual message'),
          'different message',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('checks originalError type when provided', () {
      RxTesting.expectRxException(
        () => throw RxException('err', originalError: 42),
        'err',
        expectedOriginalError: int,
      );
    });

    test('throws if originalError type does not match', () {
      expect(
        () => RxTesting.expectRxException(
          () => throw RxException('err', originalError: 'string'),
          'err',
          expectedOriginalError: int,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.expectRxFailure and expectRxSuccess
  // ══════════════════════════════════════════════════════════
  group('RxTesting.expectRxFailure', () {
    test('passes for failure with matching message', () {
      final r = RxResult.failure<int>(const RxException('database error'));
      RxTesting.expectRxFailure(r, 'database');
    });

    test('throws if result is success', () {
      expect(
        () => RxTesting.expectRxFailure(RxResult.success(1), 'anything'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws if error message does not match', () {
      final r = RxResult.failure<int>(const RxException('actual'));
      expect(
        () => RxTesting.expectRxFailure(r, 'expected'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('RxTesting.expectRxSuccess', () {
    test('passes for success with matching value', () {
      RxTesting.expectRxSuccess(RxResult.success(42), 42);
    });

    test('throws if result is failure', () {
      expect(
        () => RxTesting.expectRxSuccess(
          RxResult.failure<int>(const RxException('err')),
          1,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws if value does not match', () {
      expect(
        () => RxTesting.expectRxSuccess(RxResult.success(1), 99),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.expectRxChange
  // ══════════════════════════════════════════════════════════
  group('RxTesting.expectRxChange', () {
    test('completes when value changes to expected', () async {
      final rx = 0.obs();
      Future.delayed(const Duration(milliseconds: 10), () => rx.value = 5);
      await RxTesting.expectRxChange(rx, 5);
      expect(rx.value, 5);
    });

    test('throws on timeout if value never reaches expected', () async {
      final rx = 0.obs();
      expect(
        () => RxTesting.expectRxChange(
          rx,
          999,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.expectRxNoChange
  // ══════════════════════════════════════════════════════════
  group('RxTesting.expectRxNoChange', () {
    test('passes if value does not change', () async {
      final rx = 'stable'.obs();
      await RxTesting.expectRxNoChange(rx, const Duration(milliseconds: 20));
    });

    test('throws if value changes during duration', () async {
      final rx = 0.obs();
      Future.delayed(const Duration(milliseconds: 10), () => rx.value = 1);
      expect(
        () => RxTesting.expectRxNoChange(rx, const Duration(milliseconds: 30)),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.createMock
  // ══════════════════════════════════════════════════════════
  group('RxTesting.createMock', () {
    test('creates Rx with given initial value', () {
      final mock = RxTesting.createMock(100);
      expect(mock.value, 100);
    });

    test('mock is mutable', () {
      final mock = RxTesting.createMock('hello');
      mock.value = 'world';
      expect(mock.value, 'world');
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.withErrorConfig, withSilentErrors, withErrorLogger
  // ══════════════════════════════════════════════════════════
  group('RxTesting error config helpers', () {
    test('withErrorConfig restores original config', () {
      final original = getRxErrorConfig();
      RxTesting.withErrorConfig(
        const RxErrorConfig(logErrors: false),
        () => expect(getRxErrorConfig().logErrors, false),
      );
      expect(getRxErrorConfig().logErrors, original.logErrors);
    });

    test('withSilentErrors disables logging inside', () {
      RxTesting.withSilentErrors(
        () => expect(getRxErrorConfig().logErrors, false),
      );
    });

    test('withErrorLogger routes errors to custom logger', () {
      final errors = <RxException>[];
      RxTesting.withErrorLogger(
        (e) => errors.add(e),
        () {
          final cfg = getRxErrorConfig();
          cfg.customLogger!(const RxException('captured'));
        },
      );
      expect(errors.length, 1);
      expect(errors.first.message, 'captured');
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.expectErrorCount
  // ══════════════════════════════════════════════════════════
  group('RxTesting.expectErrorCount', () {
    test('passes when error count matches', () {
      RxTesting.expectErrorCount(2, () {
        final cfg = getRxErrorConfig();
        cfg.customLogger!(const RxException('e1'));
        cfg.customLogger!(const RxException('e2'));
      });
    });

    test('throws when error count does not match', () {
      expect(
        () => RxTesting.expectErrorCount(1, () {}),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.expectAllEqual
  // ══════════════════════════════════════════════════════════
  group('RxTesting.expectAllEqual', () {
    test('passes when all values match', () {
      final rxs = [1.obs(), 1.obs(), 1.obs()];
      RxTesting.expectAllEqual(rxs, 1);
    });

    test('throws when one value differs', () {
      final rxs = [1.obs(), 2.obs(), 1.obs()];
      expect(
        () => RxTesting.expectAllEqual(rxs, 1),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxTesting.expectDisposed / expectNotDisposed
  // ══════════════════════════════════════════════════════════
  group('RxTesting.expectDisposed / expectNotDisposed', () {
    test('expectDisposed passes for disposed Rx', () {
      final rx = 0.obs();
      rx.dispose();
      RxTesting.expectDisposed(rx);
    });

    test('expectDisposed throws for live Rx', () {
      final rx = 0.obs();
      expect(() => RxTesting.expectDisposed(rx), throwsA(isA<Exception>()));
    });

    test('expectNotDisposed passes for live Rx', () {
      final rx = 'alive'.obs();
      RxTesting.expectNotDisposed(rx);
    });

    test('expectNotDisposed throws for disposed Rx', () {
      final rx = 0.obs();
      rx.dispose();
      expect(() => RxTesting.expectNotDisposed(rx), throwsA(isA<Exception>()));
    });
  });
}
