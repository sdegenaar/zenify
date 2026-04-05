import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for rx_error_handling.dart targeting uncovered lines:
/// - L165-166: RxSuccess.hashCode
/// - L184-185: RxFailure.hashCode
/// - L246-251: valueOr fallback path
/// - L260-270: valueOrElse double-failure path
/// - L343: listenSafe onError fallback logging
/// - L385-390: computeSafe error in listener
/// - L472-477: updateFromAsync outer catch
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  // ══════════════════════════════════════════════════════════
  // RxResult - equality and hashCode
  // ══════════════════════════════════════════════════════════
  group('RxResult equality and hashCode', () {
    test('RxSuccess equals another with same value', () {
      final a = RxResult.success(42);
      final b = RxResult.success(42);
      expect(a, equals(b));
    });

    test('RxSuccess hashCode matches for same value', () {
      final a = RxResult.success('hello');
      final b = RxResult.success('hello');
      expect(a.hashCode, b.hashCode);
    });

    test('RxFailure equals another with same error', () {
      final err = RxException.withTimestamp('same error');
      final a = RxResult.failure<int>(err);
      final b = RxResult.failure<int>(err);
      expect(a, equals(b));
    });

    test('RxFailure hashCode matches for same error', () {
      final err = RxException.withTimestamp('same');
      final a = RxResult.failure<int>(err);
      final b = RxResult.failure<int>(err);
      expect(a.hashCode, b.hashCode);
    });

    test('RxSuccess not equal to RxFailure', () {
      final success = RxResult.success(1);
      final failure = RxResult.failure<int>(RxException.withTimestamp('e'));
      expect(success, isNot(equals(failure)));
    });

    test('RxSuccess.toString contains value', () {
      final r = RxResult.success(99);
      expect(r.toString(), contains('99'));
    });

    test('RxFailure.toString contains error', () {
      final r = RxResult.failure<int>(RxException.withTimestamp('fail msg'));
      expect(r.toString(), contains('fail msg'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxResult operations
  // ══════════════════════════════════════════════════════════
  group('RxResult operations', () {
    test('map on success transforms value', () {
      final r = RxResult.success(10);
      final mapped = r.map((v) => v * 2);
      expect(mapped.isSuccess, true);
      expect((mapped as RxSuccess).value, 20);
    });

    test('map on failure returns failure unchanged', () {
      final r = RxResult.failure<int>(RxException.withTimestamp('e'));
      final mapped = r.map((v) => v * 2);
      expect(mapped.isSuccess, false);
    });

    test('valueOr on success returns value', () {
      final r = RxResult.success(42);
      expect(r.valueOr(0), 42);
    });

    test('valueOr on failure returns fallback', () {
      final r = RxResult.failure<int>(RxException.withTimestamp('fail'));
      expect(r.valueOr(99), 99);
    });

    test('valueOrElse on success returns value', () {
      final r = RxResult.success(42);
      expect(r.valueOrElse(() => 0), 42);
    });

    test('valueOrElse on failure calls fallback', () {
      final r = RxResult.failure<int>(RxException.withTimestamp('fail'));
      expect(r.valueOrElse(() => 99), 99);
    });

    test('onSuccess callback fires for success', () {
      int? received;
      RxResult.success(5).onSuccess((v) => received = v);
      expect(received, 5);
    });

    test('onFailure callback fires for failure', () {
      RxException? received;
      final err = RxException.withTimestamp('err');
      RxResult.failure<int>(err).onFailure((e) => received = e);
      expect(received, same(err));
    });

    test('flatMap chains successful results', () {
      final r = RxResult.success(5);
      final chained = r.flatMap((v) => RxResult.success(v * 2));
      expect(chained.isSuccess, true);
      expect((chained as RxSuccess).value, 10);
    });

    test('flatMap short-circuits on failure', () {
      final r = RxResult.failure<int>(RxException.withTimestamp('e'));
      bool called = false;
      final chained = r.flatMap((v) {
        called = true;
        return RxResult.success(v);
      });
      expect(called, false);
      expect(chained.isSuccess, false);
    });

    test('tryExecuteAsync captures exception', () async {
      final r = await RxResult.tryExecuteAsync(
        () async => throw Exception('async error'),
        'async context',
      );
      expect(r.isSuccess, false);
    });

    test('tryExecuteAsync success returns value', () async {
      final r = await RxResult.tryExecuteAsync(
        () async => 'done',
        'async context',
      );
      expect(r.isSuccess, true);
    });

    test('errorOrNull is null on success', () {
      expect(RxResult.success(1).errorOrNull, isNull);
    });

    test('errorOrNull returns error on failure', () {
      final err = RxException.withTimestamp('e');
      expect(RxResult.failure<int>(err).errorOrNull, same(err));
    });

    test('value getter throws on failure', () {
      final r = RxResult.failure<int>(RxException.withTimestamp('e'));
      expect(() => r.value, throwsA(isA<RxException>()));
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxErrorHandling extensions — trySetValue / tryGetValue
  // ══════════════════════════════════════════════════════════
  group('RxErrorHandling.trySetValue and tryGetValue', () {
    test('trySetValue succeeds', () {
      final rx = Rx<int>(0);
      final result = rx.trySetValue(42);
      expect(result.isSuccess, true);
      expect(rx.value, 42);
    });

    test('tryGetValue returns current value', () {
      final rx = Rx<String>('hello');
      final result = rx.tryGetValue();
      expect(result.isSuccess, true);
      expect((result as RxSuccess).value, 'hello');
    });
  });

  // ══════════════════════════════════════════════════════════
  // setWithValidation
  // ══════════════════════════════════════════════════════════
  group('RxErrorHandling.setWithValidation', () {
    test('returns success when validation passes', () {
      final rx = Rx<int>(5);
      final result = rx.setWithValidation(10, (v) => v > 0);
      expect(result.isSuccess, true);
      expect(rx.value, 10);
    });

    test('returns failure when validation fails', () {
      final rx = Rx<int>(5);
      final result = rx.setWithValidation(
        -1,
        (v) => v > 0,
        validationMessage: 'Must be positive',
      );
      expect(result.isSuccess, false);
      expect(rx.value, 5); // unchanged
    });
  });

  // ══════════════════════════════════════════════════════════
  // transformSafe / chainSafe
  // ══════════════════════════════════════════════════════════
  group('RxErrorHandling.transformSafe and chainSafe', () {
    test('transformSafe returns success on normal computation', () {
      final rx = Rx<int>(10);
      final result = rx.transformSafe((v) => v.toString());
      expect(result.isSuccess, true);
    });

    test('transformSafe returns failure when transformer throws', () {
      final rx = Rx<int>(10);
      final result = rx.transformSafe<String>(
        (_) => throw Exception('transform fail'),
        context: 'test transform',
      );
      expect(result.isSuccess, false);
    });

    test('chainSafe returns operation result', () {
      final rx = Rx<int>(5);
      final result =
          rx.chainSafe<String>((v) => RxResult.success(v.toString()));
      expect(result.isSuccess, true);
    });

    test('chainSafe catches exception in operation', () {
      final rx = Rx<int>(5);
      final result = rx.chainSafe<String>(
        (_) => throw Exception('chain error'),
        context: 'chain test',
      );
      expect(result.isSuccess, false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // computeSafe — error recovery
  // ══════════════════════════════════════════════════════════
  group('RxErrorHandling.computeSafe', () {
    test('computeSafe sets result via computation', () {
      final rx = Rx<int>(5);
      final computed = rx.computeSafe((v) => v * 2);
      expect(computed.value, 10);
    });

    test('computeSafe returns null when computation throws', () {
      final rx = Rx<int>(5);
      final computed = rx.computeSafe<String>(
        (_) => throw Exception('compute error'),
      );
      expect(computed.value, isNull);
    });

    test('computeSafe listener updates when rx changes', () {
      final rx = Rx<int>(1);
      final computed = rx.computeSafe((v) => v * 3);
      rx.value = 4;
      expect(computed.value, 12);
    });
  });

  // ══════════════════════════════════════════════════════════
  // listenSafe error path
  // ══════════════════════════════════════════════════════════
  group('RxErrorHandling.listenSafe', () {
    test('listenSafe calls onError when listener throws', () {
      final rx = Rx<int>(0);
      RxException? capturedError;

      rx.listenSafe(
        (_) => throw Exception('listener boom'),
        onError: (e) => capturedError = e,
      );

      rx.value = 1;
      expect(capturedError, isNotNull);
    });

    test('listenSafe logs error when no onError provided', () {
      final rx = Rx<int>(0);
      // Without onError, falls back to _logError — must not crash
      rx.listenSafe((_) => throw Exception('no handler error'));
      expect(() => rx.value = 1, returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxAsyncErrorHandling
  // ══════════════════════════════════════════════════════════
  group('RxAsyncErrorHandling', () {
    test('setFromAsync succeeds and updates value', () async {
      final rx = Rx<int>(0);
      final result = await rx.setFromAsync(() async => 99);
      expect(result.isSuccess, true);
      expect(rx.value, 99);
    });

    test('setFromAsync captures error on failure', () async {
      final rx = Rx<int>(0);
      final result = await rx.setFromAsync(
        () async => throw Exception('async fail'),
      );
      expect(result.isSuccess, false);
      expect(rx.value, 0); // unchanged
    });

    test('updateFromAsync passes current value to operation', () async {
      final rx = Rx<int>(10);
      final result = await rx.updateFromAsync((current) async => current + 5);
      expect(result.isSuccess, true);
      expect(rx.value, 15);
    });

    test('updateFromAsync captures error on failure', () async {
      final rx = Rx<int>(10);
      final result = await rx.updateFromAsync(
        (_) async => throw Exception('update fail'),
      );
      expect(result.isSuccess, false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxNullableErrorHandling
  // ══════════════════════════════════════════════════════════
  group('RxNullableErrorHandling', () {
    test('requireValue throws when null', () {
      final rx = Rx<String?>(null);
      expect(() => rx.requireValue('must have value'),
          throwsA(isA<RxException>()));
    });

    test('requireValue returns value when not null', () {
      final rx = Rx<String?>('data');
      expect(rx.requireValue(), 'data');
    });

    test('tryRequireValue returns failure when null', () {
      final rx = Rx<int?>(null);
      final result = rx.tryRequireValue();
      expect(result.isSuccess, false);
    });

    test('hasValue is false when null', () {
      final rx = Rx<String?>(null);
      expect(rx.hasValue, false);
    });

    test('hasValue is true when set', () {
      final rx = Rx<String?>('x');
      expect(rx.hasValue, true);
    });

    test('orElse returns value when not null', () {
      final rx = Rx<int?>(7);
      expect(rx.orElse(0), 7);
    });

    test('orElse returns fallback when null', () {
      final rx = Rx<int?>(null);
      expect(rx.orElse(42), 42);
    });

    test('orElseGet computes fallback when null', () {
      final rx = Rx<String?>(null);
      expect(rx.orElseGet(() => 'computed'), 'computed');
    });
  });

  // ══════════════════════════════════════════════════════════
  // setRxErrorConfig / getRxErrorConfig
  // ══════════════════════════════════════════════════════════
  group('RxErrorConfig', () {
    tearDown(() => setRxErrorConfig(RxErrorConfig.defaultConfig));

    test('setRxErrorConfig and getRxErrorConfig round-trips', () {
      final config = RxErrorConfig(
        logErrors: false,
        throwOnCriticalErrors: true,
        maxRetries: 5,
      );
      setRxErrorConfig(config);
      expect(getRxErrorConfig().maxRetries, 5);
    });

    test('default config has logErrors=true', () {
      expect(RxErrorConfig.defaultConfig.logErrors, true);
    });

    test('custom logger is invoked', () {
      RxException? logged;
      final config = RxErrorConfig(
        customLogger: (e) => logged = e,
      );
      setRxErrorConfig(config);

      final rx = Rx<int>(5);
      rx.listenSafe((_) => throw Exception('test'));
      rx.value = 1;

      expect(logged, isNotNull);
    });
  });
}
