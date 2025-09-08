// lib/reactive/testing/rx_testing.dart
import 'dart:async';

import '../core/rx_value.dart';
import '../core/rx_error_handling.dart';

/// Testing utilities for reactive values
class RxTesting {
  /// Test that an operation throws a specific RxException
  static void expectRxException(
    void Function() operation,
    String expectedMessage, {
    Type? expectedOriginalError,
  }) {
    try {
      operation();
      throw Exception('Expected RxException but none was thrown');
    } catch (e) {
      if (e is! RxException) {
        throw Exception('Expected RxException but got ${e.runtimeType}: $e');
      }

      if (!e.message.contains(expectedMessage)) {
        throw Exception(
            'Expected message containing "$expectedMessage" but got "${e.message}"');
      }

      if (expectedOriginalError != null &&
          e.originalError?.runtimeType != expectedOriginalError) {
        throw Exception(
            'Expected original error of type $expectedOriginalError but got ${e.originalError?.runtimeType}');
      }
    }
  }

  /// Test that an RxResult is failure with specific error
  static void expectRxFailure<T>(
    RxResult<T> result,
    String expectedMessage,
  ) {
    if (result.isSuccess) {
      throw Exception(
          'Expected RxResult.failure but got success with value: ${result.value}');
    }

    final error = result.errorOrNull!;
    if (!error.message.contains(expectedMessage)) {
      throw Exception(
          'Expected error message containing "$expectedMessage" but got "${error.message}"');
    }
  }

  /// Test that an RxResult is success with specific value
  static void expectRxSuccess<T>(
    RxResult<T> result,
    T expectedValue,
  ) {
    if (result.isFailure) {
      throw Exception(
          'Expected RxResult.success but got failure: ${result.errorOrNull}');
    }

    if (result.value != expectedValue) {
      throw Exception(
          'Expected success value $expectedValue but got ${result.value}');
    }
  }

  /// Test that a reactive value changes to expected value
  static Future<void> expectRxChange<T>(
    Rx<T> rx,
    T expectedValue, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final completer = Completer<void>();

    void listener() {
      if (rx.value == expectedValue) {
        completer.complete();
        rx.removeListener(listener);
      }
    }

    rx.addListener(listener);

    try {
      await completer.future.timeout(timeout);
    } catch (e) {
      rx.removeListener(listener);
      throw Exception(
          'Expected Rx value to change to $expectedValue but timeout occurred');
    }
  }

  /// Test that an Rx value does not change within a duration
  static Future<void> expectRxNoChange<T>(
    Rx<T> rx,
    Duration duration,
  ) async {
    final initialValue = rx.value;
    bool changed = false;

    void listener() {
      if (rx.value != initialValue) {
        changed = true;
      }
    }

    rx.addListener(listener);

    await Future.delayed(duration);

    rx.removeListener(listener);

    if (changed) {
      throw Exception(
          'Expected Rx value to remain $initialValue but it changed to ${rx.value}');
    }
  }

  /// Create a mock reactive value for testing
  static Rx<T> createMock<T>(T initialValue) {
    return Rx<T>(initialValue);
  }

  /// Test error configuration
  static void withErrorConfig(
    RxErrorConfig config,
    void Function() test,
  ) {
    final originalConfig = getRxErrorConfig();
    setRxErrorConfig(config);

    try {
      test();
    } finally {
      setRxErrorConfig(originalConfig);
    }
  }

  /// Test with silent error logging
  static void withSilentErrors(void Function() test) {
    withErrorConfig(
      const RxErrorConfig(logErrors: false),
      test,
    );
  }

  /// Test with custom error logger
  static void withErrorLogger(
    void Function(RxException error) logger,
    void Function() test,
  ) {
    withErrorConfig(
      RxErrorConfig(customLogger: logger),
      test,
    );
  }

  /// Verify that a specific number of errors were logged
  static void expectErrorCount(
    int expectedCount,
    void Function() test,
  ) {
    int errorCount = 0;

    withErrorLogger(
      (error) => errorCount++,
      test,
    );

    if (errorCount != expectedCount) {
      throw Exception('Expected $expectedCount errors but got $errorCount');
    }
  }

  /// Test multiple reactive values for consistency
  static void expectAllEqual<T>(List<Rx<T>> rxValues, T expectedValue) {
    for (int i = 0; i < rxValues.length; i++) {
      if (rxValues[i].value != expectedValue) {
        throw Exception(
            'Rx at index $i has value ${rxValues[i].value}, expected $expectedValue');
      }
    }
  }

  /// Test that reactive values are disposed properly
  static void expectDisposed<T>(Rx<T> rx) {
    if (!rx.isDisposed) {
      throw Exception('Expected Rx to be disposed but it was not');
    }
  }

  /// Test that reactive values are not disposed
  static void expectNotDisposed<T>(Rx<T> rx) {
    if (rx.isDisposed) {
      throw Exception('Expected Rx to not be disposed but it was');
    }
  }
}
