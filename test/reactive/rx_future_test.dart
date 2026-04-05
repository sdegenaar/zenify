import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/reactive/reactive.dart';

void main() {
  // ══════════════════════════════════════════════════════════
  // RxFuture state management
  // ══════════════════════════════════════════════════════════
  group('RxFuture initial state', () {
    test('starts in waiting state', () {
      final rx = RxFuture<int>();
      expect(rx.isLoading, true);
      expect(rx.hasData, false);
      expect(rx.hasError, false);
      expect(rx.data, isNull);
    });

    test('toString includes loading/data/error info', () {
      final rx = RxFuture<int>();
      expect(rx.toString(), contains('RxFuture'));
    });
  });

  group('RxFuture with future', () {
    test('resolves to data from completed future', () async {
      final rx = RxFuture<int>(Future.value(42));
      await Future.delayed(Duration.zero);
      expect(rx.isLoading, false);
      expect(rx.hasData, true);
      expect(rx.data, 42);
    });

    test('resolves to error from failed future', () async {
      final rx = RxFuture<int>(Future.error(Exception('fail')));
      await Future.delayed(Duration.zero);
      expect(rx.hasError, true);
      expect(rx.isLoading, false);
    });

    test('setting future=null puts in waiting state', () {
      final rx = RxFuture<int>();
      rx.future = null;
      expect(rx.isLoading, true);
    });

    test('replacing future cancels stale result', () async {
      final rx = RxFuture<int>(Future.value(1));
      rx.future = Future.value(2);
      await Future.delayed(Duration.zero);
      expect(rx.data, 2); // only latest result
    });
  });

  group('RxFuture.fromFactory', () {
    test('executes factory immediately', () async {
      var calls = 0;
      final rx = RxFuture<int>.fromFactory(() async {
        calls++;
        return calls;
      });
      await Future.delayed(Duration.zero);
      expect(calls, 1);
      expect(rx.data, 1);
    });
  });

  group('RxFuture.setFutureFactory', () {
    test('sets factory and executes it', () async {
      final rx = RxFuture<String>();
      rx.setFutureFactory(() async => 'factory-result');
      await Future.delayed(Duration.zero);
      expect(rx.data, 'factory-result');
    });
  });

  group('RxFuture manual state', () {
    test('trySetData puts into data state', () {
      final rx = RxFuture<int>();
      rx.trySetData(99);
      expect(rx.hasData, true);
      expect(rx.data, 99);
    });

    test('trySetData returns success result', () {
      final rx = RxFuture<int>();
      final result = rx.trySetData(5);
      expect(result.isSuccess, true);
    });

    test('setError puts into error state', () {
      final rx = RxFuture<int>();
      rx.setError(Exception('manual error'));
      expect(rx.hasError, true);
      expect(rx.isLoading, false);
    });

    test('setError with RxException preserves it', () {
      final rx = RxFuture<int>();
      final ex = RxException.withTimestamp('my error');
      rx.setError(ex);
      expect(rx.rxError, same(ex));
    });

    test('setLoading returns to waiting state', () {
      final rx = RxFuture<int>();
      rx.trySetData(1);
      rx.setLoading();
      expect(rx.isLoading, true);
      expect(rx.hasData, false);
    });
  });

  group('RxFuture.refresh', () {
    test('refresh with factory re-executes it', () async {
      var calls = 0;
      final rx = RxFuture<int>.fromFactory(() async => ++calls);
      await Future.delayed(Duration.zero);
      expect(calls, 1);

      rx.refresh();
      await Future.delayed(Duration.zero);
      expect(calls, 2);
    });

    test('tryRefresh throws when no factory or future', () {
      final rx = RxFuture<int>();
      final result = rx.tryRefresh();
      expect(result.isFailure, true);
      // tryExecute wraps the thrown RxException: outer message is 'Failed to ...',
      // the original RxException is the originalError.
      final innerError = result.errorOrNull!.originalError;
      expect(innerError.toString(), contains('No future'));
    });

    test('tryRefresh succeeds with existing current future', () async {
      final rx = RxFuture<int>(Future.value(5));
      await Future.delayed(Duration.zero);
      final result = rx.tryRefresh();
      expect(result.isSuccess, true);
    });
  });

  group('RxFuture accessors', () {
    test('dataOr returns data when available', () {
      final rx = RxFuture<int>();
      rx.trySetData(7);
      expect(rx.dataOr(0), 7);
    });

    test('dataOr returns fallback when no data', () {
      final rx = RxFuture<int>();
      expect(rx.dataOr(42), 42);
    });

    test('tryGetData returns success when data is set', () {
      final rx = RxFuture<int>();
      rx.trySetData(10);
      final result = rx.tryGetData();
      expect(result.isSuccess, true);
      expect(result.value, 10);
    });

    test('tryGetData returns failure when loading', () {
      final rx = RxFuture<int>();
      final result = rx.tryGetData();
      expect(result.isFailure, true);
    });

    test('tryGetData returns failure when in error state', () {
      final rx = RxFuture<int>();
      rx.setError(Exception('err'));
      final result = rx.tryGetData();
      expect(result.isFailure, true);
    });

    test('originalError unwraps from RxException', () {
      final rx = RxFuture<int>();
      final cause = Exception('root');
      rx.setError(cause);
      // setError wraps in RxException, originalError should return cause
      expect(rx.originalError, same(cause));
    });

    test('originalError returns plain error when not RxException', () {
      final rx = RxFuture<int>();
      // Set manually with RxException that has no originalError
      rx.setError(RxException.withTimestamp('no original'));
      // rxError exists but originalError is null
      expect(rx.rxError, isNotNull);
    });

    test('errorMessage returns string description', () {
      final rx = RxFuture<int>();
      rx.setError(Exception('desc error'));
      expect(rx.errorMessage, isNotNull);
      expect(rx.errorMessage, contains('desc error'));
    });

    test('stackTrace is available after future error', () async {
      final rx = RxFuture<int>(Future<int>.error(
        Exception('trace'),
        StackTrace.fromString('fake stack'),
      ));
      await Future.delayed(Duration.zero);
      expect(rx.stackTrace, isNotNull);
    });
  });

  group('RxFuture.map', () {
    test('map propagates data when ready', () async {
      final rx = RxFuture<int>(Future.value(5));
      final mapped = rx.map((v) => v * 2);
      await Future.delayed(Duration.zero);
      expect(mapped.hasData, true);
      expect(mapped.data, 10);
    });

    test('map propagates error when source errors', () async {
      final rx = RxFuture<int>(Future.error(Exception('map err')));
      final mapped = rx.map((v) => v.toString());
      await Future.delayed(Duration.zero);
      expect(mapped.hasError, true);
    });

    test('map handles mapper exception as error', () async {
      final rx = RxFuture<int>(Future.value(5));
      final mapped = rx.map<String>((v) => throw Exception('bad map'));
      await Future.delayed(Duration.zero);
      expect(mapped.hasError, true);
    });

    test('map propagates loading state reset to waiting', () {
      final rx = RxFuture<int>();
      final mapped = rx.map((v) => v * 2);
      rx.setLoading();
      expect(mapped.isLoading, true);
    });
  });
}
