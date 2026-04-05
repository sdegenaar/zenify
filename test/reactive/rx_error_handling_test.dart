import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  // ══════════════════════════════════════════════════════════
  // RxException
  // ══════════════════════════════════════════════════════════
  group('RxException', () {
    test('basic construction stores message', () {
      const e = RxException('something went wrong');
      expect(e.message, 'something went wrong');
      expect(e.originalError, isNull);
      expect(e.stackTrace, isNull);
      expect(e.timestamp, isNull);
    });

    test('construction with optional fields', () {
      final original = Exception('root');
      final stack = StackTrace.current;
      final e = RxException(
        'ops',
        originalError: original,
        stackTrace: stack,
        timestamp: DateTime(2024),
      );
      expect(e.originalError, original);
      expect(e.stackTrace, stack);
      expect(e.timestamp, DateTime(2024));
    });

    test('withTimestamp factory sets timestamp', () {
      final before = DateTime.now();
      final e = RxException.withTimestamp('timed error');
      final after = DateTime.now();
      expect(e.timestamp, isNotNull);
      expect(
          e.timestamp!.isAfter(before) || e.timestamp!.isAtSameMomentAs(before),
          true);
      expect(
          e.timestamp!.isBefore(after) || e.timestamp!.isAtSameMomentAs(after),
          true);
    });

    test('withTimestamp forwards originalError and stackTrace', () {
      final e = RxException.withTimestamp(
        'fail',
        originalError: 'cause',
        stackTrace: StackTrace.empty,
      );
      expect(e.originalError, 'cause');
      expect(e.stackTrace, isNotNull);
    });

    test('toString includes message', () {
      const e = RxException('bad thing');
      expect(e.toString(), contains('bad thing'));
    });

    test('toString includes originalError when present', () {
      final e = RxException('fail', originalError: 'root cause');
      expect(e.toString(), contains('root cause'));
    });

    test('toString includes timestamp when present', () {
      final e = RxException('fail', timestamp: DateTime(2025, 1, 1));
      expect(e.toString(), contains('2025'));
    });

    test('toString omits optional fields when absent', () {
      const e = RxException('minimal');
      final s = e.toString();
      expect(s, contains('minimal'));
      expect(s, isNot(contains('Caused by')));
      expect(s, isNot(contains('At:')));
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxResult basics
  // ══════════════════════════════════════════════════════════
  group('RxResult', () {
    test('success isSuccess true, isFailure false', () {
      final r = RxResult.success(42);
      expect(r.isSuccess, true);
      expect(r.isFailure, false);
    });

    test('failure isSuccess false, isFailure true', () {
      final r = RxResult.failure<int>(const RxException('err'));
      expect(r.isSuccess, false);
      expect(r.isFailure, true);
    });

    test('success: value returns value', () {
      expect(RxResult.success('hello').value, 'hello');
    });

    test('failure: value throws RxException', () {
      final r = RxResult.failure<String>(const RxException('fail'));
      expect(() => r.value, throwsA(isA<RxException>()));
    });

    test('success: valueOrNull returns value', () {
      expect(RxResult.success(1).valueOrNull, 1);
    });

    test('failure: valueOrNull returns null', () {
      expect(RxResult.failure<int>(const RxException('e')).valueOrNull, isNull);
    });

    test('success: errorOrNull returns null', () {
      expect(RxResult.success(1).errorOrNull, isNull);
    });

    test('failure: errorOrNull returns error', () {
      const e = RxException('err');
      expect(RxResult.failure<int>(e).errorOrNull, e);
    });

    test('valueOr returns value on success', () {
      expect(RxResult.success(5).valueOr(99), 5);
    });

    test('valueOr returns fallback on failure', () {
      expect(RxResult.failure<int>(const RxException('e')).valueOr(99), 99);
    });

    test('valueOrElse returns value on success', () {
      expect(RxResult.success(5).valueOrElse(() => 99), 5);
    });

    test('valueOrElse calls fallback on failure', () {
      expect(
          RxResult.failure<int>(const RxException('e')).valueOrElse(() => 99),
          99);
    });

    test('map transforms success value', () {
      final r = RxResult.success(10).map((v) => v * 2);
      expect(r.isSuccess, true);
      expect(r.value, 20);
    });

    test('map propagates failure', () {
      final r = RxResult.failure<int>(const RxException('e')).map((v) => v * 2);
      expect(r.isFailure, true);
    });

    test('flatMap chains success', () {
      final r = RxResult.success(5).flatMap((v) => RxResult.success(v + 1));
      expect(r.value, 6);
    });

    test('flatMap propagates failure from source', () {
      final r = RxResult.failure<int>(const RxException('src'))
          .flatMap((v) => RxResult.success(v + 1));
      expect(r.isFailure, true);
    });

    test('flatMap propagates failure from transform', () {
      final r = RxResult.success(5)
          .flatMap<int>((_) => RxResult.failure(const RxException('chain')));
      expect(r.isFailure, true);
    });

    test('onSuccess called for success', () {
      var called = false;
      RxResult.success(1).onSuccess((_) => called = true);
      expect(called, true);
    });

    test('onSuccess not called for failure', () {
      var called = false;
      RxResult.failure<int>(const RxException('e'))
          .onSuccess((_) => called = true);
      expect(called, false);
    });

    test('onFailure called for failure', () {
      var called = false;
      RxResult.failure<int>(const RxException('e'))
          .onFailure((_) => called = true);
      expect(called, true);
    });

    test('onFailure not called for success', () {
      var called = false;
      RxResult.success(1).onFailure((_) => called = true);
      expect(called, false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxSuccess / RxFailure equality and toString
  // ══════════════════════════════════════════════════════════
  group('RxSuccess / RxFailure structural equality', () {
    test('two successes with same value are equal', () {
      expect(RxResult.success(42), RxResult.success(42));
    });

    test('two successes with different values are not equal', () {
      expect(RxResult.success(1), isNot(RxResult.success(2)));
    });

    test('success toString includes value', () {
      expect(RxResult.success('hi').toString(), contains('hi'));
    });

    test('two failures with same error are equal', () {
      const e = RxException('same');
      expect(RxResult.failure<int>(e), RxResult.failure<int>(e));
    });

    test('failure toString includes error', () {
      const e = RxException('oops');
      expect(RxResult.failure<int>(e).toString(), contains('oops'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxResult.tryExecute and tryExecuteAsync
  // ══════════════════════════════════════════════════════════
  group('RxResult.tryExecute', () {
    test('wraps successful operation in success', () {
      final r = RxResult.tryExecute(() => 42);
      expect(r.isSuccess, true);
      expect(r.value, 42);
    });

    test('wraps throwing operation in failure', () {
      final r = RxResult.tryExecute(() => throw Exception('boom'));
      expect(r.isFailure, true);
      expect(r.errorOrNull!.message, contains('Operation failed'));
    });

    test('uses context in failure message', () {
      final r = RxResult.tryExecute(() => throw Exception('x'), 'save file');
      expect(r.errorOrNull!.message, contains('save file'));
    });

    test('tryExecuteAsync wraps success', () async {
      final r = await RxResult.tryExecuteAsync(() async => 'done');
      expect(r.isSuccess, true);
      expect(r.value, 'done');
    });

    test('tryExecuteAsync wraps failure', () async {
      final r = await RxResult.tryExecuteAsync(
          () async => throw Exception('async boom'));
      expect(r.isFailure, true);
      expect(r.errorOrNull!.message, contains('Async operation failed'));
    });

    test('tryExecuteAsync uses context in failure message', () async {
      final r = await RxResult.tryExecuteAsync(
          () async => throw Exception('x'), 'load data');
      expect(r.errorOrNull!.message, contains('load data'));
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxErrorConfig
  // ══════════════════════════════════════════════════════════
  group('RxErrorConfig', () {
    test('default config has expected values', () {
      const c = RxErrorConfig();
      expect(c.logErrors, true);
      expect(c.throwOnCriticalErrors, false);
      expect(c.maxRetries, 3);
      expect(c.retryDelay, const Duration(milliseconds: 100));
      expect(c.customLogger, isNull);
    });

    test('custom config stores values', () {
      RxException? captured;
      final c = RxErrorConfig(
        logErrors: false,
        throwOnCriticalErrors: true,
        maxRetries: 5,
        retryDelay: const Duration(seconds: 1),
        customLogger: (e) => captured = e,
      );
      expect(c.logErrors, false);
      expect(c.throwOnCriticalErrors, true);
      expect(c.maxRetries, 5);
      expect(c.retryDelay.inSeconds, 1);
      expect(c.customLogger, isNotNull);
      const err = RxException('test');
      c.customLogger!(err);
      expect(captured, err);
    });

    test('setRxErrorConfig and getRxErrorConfig round-trip', () {
      final original = getRxErrorConfig();
      const custom = RxErrorConfig(logErrors: false, maxRetries: 10);
      setRxErrorConfig(custom);
      expect(getRxErrorConfig().logErrors, false);
      expect(getRxErrorConfig().maxRetries, 10);
      setRxErrorConfig(original); // restore
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxErrorHandling extension on Rx<T>
  // ══════════════════════════════════════════════════════════
  group('RxErrorHandling extension', () {
    test('trySetValue succeeds for valid set', () {
      final rx = 0.obs();
      final r = rx.trySetValue(42);
      expect(r.isSuccess, true);
      expect(rx.value, 42);
    });

    test('tryGetValue succeeds', () {
      final rx = 'hello'.obs();
      final r = rx.tryGetValue();
      expect(r.isSuccess, true);
      expect(r.value, 'hello');
    });

    test('tryGetValue accepts context', () {
      final rx = 'x'.obs();
      final r = rx.tryGetValue(context: 'my ctx');
      expect(r.isSuccess, true);
    });

    test('valueOr returns value normally', () {
      expect('data'.obs().valueOr('fallback'), 'data');
    });

    test('valueOrElse returns value normally', () {
      expect(10.obs().valueOrElse(() => 99), 10);
    });

    test('setWithValidation succeeds when validator passes', () {
      final rx = 0.obs();
      final r = rx.setWithValidation(5, (v) => v > 0);
      expect(r.isSuccess, true);
      expect(rx.value, 5);
    });

    test('setWithValidation fails when validator rejects', () {
      final rx = 10.obs();
      final r = rx.setWithValidation(-1, (v) => v >= 0);
      expect(r.isFailure, true);
      expect(rx.value, 10); // unchanged
    });

    test('setWithValidation uses custom validation message', () {
      final rx = 0.obs();
      final r = rx.setWithValidation(
        -5,
        (v) => v >= 0,
        validationMessage: 'Must be non-negative',
      );
      // tryExecute wraps the thrown RxException; the custom msg is in originalError
      expect(r.isFailure, true);
      expect(r.errorOrNull!.originalError.toString(),
          contains('Must be non-negative'));
    });

    test('tryUpdate applies update function', () {
      final rx = 3.obs();
      final r = rx.tryUpdate((v) => v * 4);
      expect(r.isSuccess, true);
      expect(rx.value, 12);
    });

    test('tryUpdate captures thrown exception as failure', () {
      final rx = 0.obs();
      final r = rx.tryUpdate((_) => throw Exception('update err'));
      expect(r.isFailure, true);
    });

    test('updateWithRetry succeeds immediately', () async {
      final rx = 1.obs();
      final r = await rx.updateWithRetry((v) => v + 1);
      expect(r.isSuccess, true);
      expect(rx.value, 2);
    });

    test('updateWithRetry returns failure after max retries', () async {
      final rx = 0.obs();
      final r = await rx.updateWithRetry(
        (_) => throw Exception('always fails'),
        maxRetries: 1,
        retryDelay: Duration.zero,
      );
      expect(r.isFailure, true);
    });

    test('listenSafe fires on change', () {
      final rx = 0.obs();
      int seen = -1;
      rx.listenSafe((v) => seen = v);
      rx.value = 7;
      expect(seen, 7);
    });

    test('listenSafe calls onError when listener throws', () {
      final rx = 0.obs();
      RxException? caught;
      rx.listenSafe((_) => throw Exception('boom'), onError: (e) => caught = e);
      rx.value = 1;
      expect(caught, isNotNull);
      expect(caught!.message, contains('listener callback'));
    });

    test('transformSafe wraps successful transform', () {
      final rx = 4.obs();
      final r = rx.transformSafe((v) => v * v);
      expect(r.isSuccess, true);
      expect(r.value, 16);
    });

    test('transformSafe wraps thrown error as failure', () {
      final rx = 0.obs();
      final r = rx.transformSafe<int>((_) => throw Exception('bad'));
      expect(r.isFailure, true);
    });

    test('chainSafe returns result of operation', () {
      final rx = 5.obs();
      final r = rx.chainSafe((v) => RxResult.success(v + 1));
      expect(r.isSuccess, true);
      expect(r.value, 6);
    });

    test('chainSafe catches thrown exception', () {
      final rx = 0.obs();
      final r = rx.chainSafe<int>((_) => throw Exception('chain'));
      expect(r.isFailure, true);
    });

    test('computeSafe updates result on source change', () {
      final rx = 2.obs();
      final computed = rx.computeSafe((v) => v * 3);
      expect(computed.value, 6);
      rx.value = 4;
      expect(computed.value, 12);
    });

    test('computeSafe sets null on computation error', () {
      final rx = 0.obs();
      final computed = rx.computeSafe<int>((_) => throw Exception('compute'));
      expect(computed.value, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxNullableErrorHandling
  // ══════════════════════════════════════════════════════════
  group('RxNullableErrorHandling', () {
    test('hasValue is true when value is not null', () {
      final rx = Rx<String?>('hello');
      expect(rx.hasValue, true);
    });

    test('hasValue is false when value is null', () {
      final rx = Rx<String?>(null);
      expect(rx.hasValue, false);
    });

    test('orElse returns value when not null', () {
      expect(Rx<int?>(5).orElse(99), 5);
    });

    test('orElse returns fallback when null', () {
      expect(Rx<int?>(null).orElse(99), 99);
    });

    test('orElseGet returns value when not null', () {
      expect(Rx<int?>(5).orElseGet(() => 99), 5);
    });

    test('orElseGet calls factory when null', () {
      expect(Rx<int?>(null).orElseGet(() => 42), 42);
    });

    test('requireValue returns value when not null', () {
      expect(Rx<String?>('data').requireValue(), 'data');
    });

    test('requireValue throws RxException when null', () {
      expect(
          () => Rx<String?>(null).requireValue(), throwsA(isA<RxException>()));
    });

    test('requireValue uses context in error message', () {
      try {
        Rx<int?>(null).requireValue('user id');
        fail('expected throw');
      } catch (e) {
        expect(e, isA<RxException>());
        expect((e as RxException).message, contains('user id'));
      }
    });

    test('tryRequireValue returns success when not null', () {
      final r = Rx<int?>(7).tryRequireValue();
      expect(r.isSuccess, true);
      expect(r.value, 7);
    });

    test('tryRequireValue returns failure when null', () {
      final r = Rx<int?>(null).tryRequireValue();
      expect(r.isFailure, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxAsyncErrorHandling
  // ══════════════════════════════════════════════════════════
  group('RxAsyncErrorHandling', () {
    test('setFromAsync updates value on success', () async {
      final rx = 0.obs();
      final r = await rx.setFromAsync(() async => 99);
      expect(r.isSuccess, true);
      expect(rx.value, 99);
    });

    test('setFromAsync returns failure when operation throws', () async {
      final rx = 0.obs();
      final r = await rx.setFromAsync(() async => throw Exception('net error'));
      expect(r.isFailure, true);
    });

    test('updateFromAsync updates value', () async {
      final rx = 5.obs();
      final r = await rx.updateFromAsync((current) async => current * 2);
      expect(r.isSuccess, true);
      expect(rx.value, 10);
    });

    test('updateFromAsync returns failure when operation throws', () async {
      final rx = 0.obs();
      final r = await rx.updateFromAsync((_) async => throw Exception('fail'));
      expect(r.isFailure, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxErrorUtils
  // ══════════════════════════════════════════════════════════
  group('RxErrorUtils', () {
    test('tryMultiple succeeds when all operations succeed', () {
      final r = RxErrorUtils.tryMultiple([
        () => RxResult.success(1),
        () => RxResult.success(2),
        () => RxResult.success(3),
      ]);
      expect(r.isSuccess, true);
      expect(r.value, [1, 2, 3]);
    });

    test('tryMultiple fails at first failing operation', () {
      final r = RxErrorUtils.tryMultiple([
        () => RxResult.success(1),
        () => RxResult.failure<int>(const RxException('op1 failed')),
        () => RxResult.success(3),
      ]);
      expect(r.isFailure, true);
      expect(r.errorOrNull!.message, contains('Operation 1 failed'));
    });

    test('withTimeout succeeds before deadline', () async {
      final r = await RxErrorUtils.withTimeout(
        () async => 'done',
        const Duration(seconds: 2),
      );
      expect(r.isSuccess, true);
      expect(r.value, 'done');
    });

    test('withTimeout returns failure on timeout', () async {
      final r = await RxErrorUtils.withTimeout(
        () async {
          await Future.delayed(const Duration(seconds: 2));
          return 'late';
        },
        const Duration(milliseconds: 10),
        context: 'my op',
      );
      expect(r.isFailure, true);
      expect(r.errorOrNull!.message, contains('timed out'));
    });

    test('withTimeout returns failure on operation error', () async {
      final r = await RxErrorUtils.withTimeout<int>(
        () async => throw Exception('boom'),
        const Duration(seconds: 1),
      );
      expect(r.isFailure, true);
    });

    test('createCircuitBreaker returns a circuit breaker', () {
      final cb = RxErrorUtils.createCircuitBreaker(failureThreshold: 2);
      expect(cb, isA<RxCircuitBreaker>());
      expect(cb.state['isOpen'], false);
    });
  });

  // ══════════════════════════════════════════════════════════
  // RxCircuitBreaker
  // ══════════════════════════════════════════════════════════
  group('RxCircuitBreaker', () {
    test('starts closed', () {
      final cb = RxCircuitBreaker(
          failureThreshold: 3, resetTimeout: const Duration(minutes: 1));
      expect(cb.state['isOpen'], false);
      expect(cb.state['failureCount'], 0);
    });

    test('allows operations when closed', () {
      final cb = RxCircuitBreaker(
          failureThreshold: 3, resetTimeout: const Duration(minutes: 1));
      final r = cb.execute(() => RxResult.success(42));
      expect(r.isSuccess, true);
    });

    test('opens after failure threshold', () {
      final cb = RxCircuitBreaker(
          failureThreshold: 2, resetTimeout: const Duration(minutes: 1));
      cb.execute(() => RxResult.failure(const RxException('1')));
      cb.execute(() => RxResult.failure(const RxException('2')));
      expect(cb.state['isOpen'], true);
    });

    test('rejects immediately when open', () {
      final cb = RxCircuitBreaker(
          failureThreshold: 1, resetTimeout: const Duration(minutes: 1));
      cb.execute(() => RxResult.failure(const RxException('fail')));
      final r = cb.execute(() => RxResult.success(99));
      expect(r.isFailure, true);
      expect(r.errorOrNull!.message, contains('Circuit breaker'));
    });

    test('resets after timeout elapses', () async {
      final cb = RxCircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(milliseconds: 10),
      );
      cb.execute(() => RxResult.failure(const RxException('fail')));
      expect(cb.state['isOpen'], true);
      await Future.delayed(const Duration(milliseconds: 20));
      final r = cb.execute(() => RxResult.success(1));
      expect(r.isSuccess, true);
      expect(cb.state['isOpen'], false);
    });

    test('success resets failure count', () {
      final cb = RxCircuitBreaker(
          failureThreshold: 5, resetTimeout: const Duration(minutes: 1));
      cb.execute(() => RxResult.failure(const RxException('fail')));
      expect(cb.state['failureCount'], 1);
      cb.execute(() => RxResult.success(1));
      expect(cb.state['failureCount'], 0);
    });

    test('state map returns all fields', () {
      final cb = RxCircuitBreaker(
          failureThreshold: 3, resetTimeout: const Duration(minutes: 1));
      final s = cb.state;
      expect(s.containsKey('isOpen'), true);
      expect(s.containsKey('failureCount'), true);
      expect(s.containsKey('lastFailureTime'), true);
    });
  });
}
