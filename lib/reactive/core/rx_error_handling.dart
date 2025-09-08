// lib/reactive/core/rx_error_handling.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'rx_value.dart';

/// Exception thrown when reactive value operations fail
class RxException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;
  final DateTime? timestamp; // ← Make nullable

  const RxException(
    this.message, {
    this.originalError,
    this.stackTrace,
    this.timestamp, // ← Remove initializer
  });

  factory RxException.withTimestamp(
    String message, {
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return RxException(
      message,
      originalError: originalError,
      stackTrace: stackTrace,
      timestamp: DateTime.now(), // ← Set timestamp here
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('RxException: $message');
    if (originalError != null) {
      buffer.write('\nCaused by: $originalError');
    }
    if (timestamp != null) {
      buffer.write('\nAt: ${timestamp!.toIso8601String()}');
    }
    return buffer.toString();
  }
}

/// Result wrapper for operations that can fail
sealed class RxResult<T> {
  const RxResult();

  /// Whether this result represents success
  bool get isSuccess => this is RxSuccess<T>;

  /// Whether this result represents failure
  bool get isFailure => this is RxFailure<T>;

  /// Get the value if successful, or null if failed
  T? get valueOrNull => switch (this) {
        RxSuccess<T> success => success.value,
        RxFailure<T> _ => null,
      };

  /// Get the error if failed, or null if successful
  RxException? get errorOrNull => switch (this) {
        RxSuccess<T> _ => null,
        RxFailure<T> failure => failure.error,
      };

  /// Transform the value if successful, or return the failure
  RxResult<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      RxSuccess<T> success => RxResult.success(transform(success.value)),
      RxFailure<T> failure => RxResult.failure(failure.error),
    };
  }

  /// Chain operations that return RxResult
  RxResult<R> flatMap<R>(RxResult<R> Function(T value) transform) {
    return switch (this) {
      RxSuccess<T> success => transform(success.value),
      RxFailure<T> failure => RxResult.failure(failure.error),
    };
  }

  /// Get value or throw exception
  T get value => switch (this) {
        RxSuccess<T> success => success.value,
        RxFailure<T> failure => throw failure.error,
      };

  /// Get value or return fallback
  T valueOr(T fallback) => valueOrNull ?? fallback;

  /// Get value or compute fallback
  T valueOrElse(T Function() fallback) => valueOrNull ?? fallback();

  /// Execute callback if successful
  void onSuccess(void Function(T value) callback) {
    if (this case RxSuccess<T> success) {
      callback(success.value);
    }
  }

  /// Execute callback if failed
  void onFailure(void Function(RxException error) callback) {
    if (this case RxFailure<T> failure) {
      callback(failure.error);
    }
  }

  /// Factory constructors
  static RxResult<T> success<T>(T value) => RxSuccess._(value);
  static RxResult<T> failure<T>(RxException error) => RxFailure._(error);

  /// Try to execute a function and wrap result
  static RxResult<T> tryExecute<T>(T Function() operation, [String? context]) {
    try {
      return RxResult.success(operation());
    } catch (e, stack) {
      final message =
          context != null ? 'Failed to $context' : 'Operation failed';
      return RxResult.failure(RxException.withTimestamp(
        message,
        originalError: e,
        stackTrace: stack,
      ));
    }
  }

  /// Try to execute an async function and wrap result
  static Future<RxResult<T>> tryExecuteAsync<T>(
    Future<T> Function() operation, [
    String? context,
  ]) async {
    try {
      final result = await operation();
      return RxResult.success(result);
    } catch (e, stack) {
      final message =
          context != null ? 'Failed to $context' : 'Async operation failed';
      return RxResult.failure(RxException.withTimestamp(
        message,
        originalError: e,
        stackTrace: stack,
      ));
    }
  }
}

/// Success result
final class RxSuccess<T> extends RxResult<T> {
  @override
  final T value;
  const RxSuccess._(this.value);

  @override
  String toString() => 'RxSuccess($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RxSuccess<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Failure result
final class RxFailure<T> extends RxResult<T> {
  final RxException error;
  const RxFailure._(this.error);

  @override
  String toString() => 'RxFailure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RxFailure<T> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Error handling configuration
class RxErrorConfig {
  /// Whether to log errors automatically
  final bool logErrors;

  /// Whether to throw on critical errors
  final bool throwOnCriticalErrors;

  /// Maximum number of retries for operations
  final int maxRetries;

  /// Default delay between retries
  final Duration retryDelay;

  /// Custom error logger
  final void Function(RxException error)? customLogger;

  const RxErrorConfig({
    this.logErrors = true,
    this.throwOnCriticalErrors = false,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 100),
    this.customLogger,
  });

  static const RxErrorConfig defaultConfig = RxErrorConfig();
}

/// Global error configuration
RxErrorConfig _globalErrorConfig = RxErrorConfig.defaultConfig;

/// Set global error handling configuration
void setRxErrorConfig(RxErrorConfig config) {
  _globalErrorConfig = config;
}

/// Get current error configuration
RxErrorConfig getRxErrorConfig() => _globalErrorConfig;

/// Error handling extensions for reactive values
extension RxErrorHandling<T> on Rx<T> {
  /// Set value with error handling
  RxResult<void> trySetValue(T newValue, {String? context}) {
    return RxResult.tryExecute(() {
      value = newValue;
    }, context ?? 'set value');
  }

  /// Get value with error handling
  RxResult<T> tryGetValue({String? context}) {
    return RxResult.tryExecute(() => value, context ?? 'get value');
  }

  /// Get value or return fallback
  T valueOr(T fallback) {
    try {
      return value;
    } catch (e) {
      _logError(RxException.withTimestamp(
        'Failed to get value, using fallback',
        originalError: e,
      ));
      return fallback;
    }
  }

  /// Get value or compute fallback
  T valueOrElse(T Function() fallback) {
    try {
      return value;
    } catch (e) {
      try {
        return fallback();
      } catch (fallbackError) {
        final error = RxException.withTimestamp(
          'Failed to get value and fallback computation failed',
          originalError: {'original': e, 'fallback': fallbackError},
        );
        _logError(error);
        if (_globalErrorConfig.throwOnCriticalErrors) {
          throw error;
        }
        rethrow;
      }
    }
  }

  /// Set value with validation
  RxResult<void> setWithValidation(
    T newValue,
    bool Function(T value) validator, {
    String? validationMessage,
  }) {
    return RxResult.tryExecute(() {
      if (!validator(newValue)) {
        throw RxException(
          validationMessage ?? 'Validation failed for value: $newValue',
        );
      }
      value = newValue;
    }, 'set validated value');
  }

  /// Update value with error handling
  RxResult<void> tryUpdate(T Function(T current) updater, {String? context}) {
    return RxResult.tryExecute(() {
      final currentValue = value;
      final newValue = updater(currentValue);
      value = newValue;
    }, context ?? 'update value');
  }

  /// Update value with retry logic
  Future<RxResult<void>> updateWithRetry(
    T Function(T current) updater, {
    int? maxRetries,
    Duration? retryDelay,
    String? context,
  }) async {
    final retries = maxRetries ?? _globalErrorConfig.maxRetries;
    final delay = retryDelay ?? _globalErrorConfig.retryDelay;

    for (int attempt = 0; attempt <= retries; attempt++) {
      final result = tryUpdate(updater, context: context);
      if (result.isSuccess) {
        return result;
      }

      if (attempt < retries) {
        await Future.delayed(delay);
      }
    }

    return RxResult.failure(RxException.withTimestamp(
      'Failed to update value after $retries retries',
    ));
  }

  /// Listen with error handling
  void listenSafe(
    void Function(T value) listener, {
    void Function(RxException error)? onError,
  }) {
    addListener(() {
      try {
        listener(value);
      } catch (e, stack) {
        final error = RxException.withTimestamp(
          'Error in listener callback',
          originalError: e,
          stackTrace: stack,
        );
        if (onError != null) {
          onError(error);
        } else {
          _logError(error);
        }
      }
    });
  }

  /// Transform value with error handling
  RxResult<R> transformSafe<R>(
    R Function(T value) transformer, {
    String? context,
  }) {
    return RxResult.tryExecute(
      () => transformer(value),
      context ?? 'transform value',
    );
  }

  /// Chain operations with error handling
  RxResult<R> chainSafe<R>(
    RxResult<R> Function(T value) operation, {
    String? context,
  }) {
    try {
      return operation(value);
    } catch (e, stack) {
      return RxResult.failure(RxException.withTimestamp(
        context ?? 'Chain operation failed',
        originalError: e,
        stackTrace: stack,
      ));
    }
  }

  /// Create error-safe computed value
  Rx<R?> computeSafe<R>(R Function(T value) computation) {
    final result = Rx<R?>(null);

    // Listen for changes and update safely
    listenSafe((value) {
      try {
        result.value = computation(value);
      } catch (e, stack) {
        _logError(RxException.withTimestamp(
          'Error in safe computation',
          originalError: e,
          stackTrace: stack,
        ));
        result.value = null;
      }
    });

    // Initial computation
    try {
      result.value = computation(value);
    } catch (e, stack) {
      _logError(RxException.withTimestamp(
        'Error in initial safe computation',
        originalError: e,
        stackTrace: stack,
      ));
    }

    return result;
  }
}

/// Error handling for nullable reactive values
extension RxNullableErrorHandling<T> on Rx<T?> {
  /// Get non-null value or throw with context
  T requireValue([String? context]) {
    final val = value;
    if (val == null) {
      final error = RxException.withTimestamp(
        context != null
            ? 'Required value is null: $context'
            : 'Required value is null',
      );
      _logError(error);
      throw error;
    }
    return val;
  }

  /// Get non-null value or return result
  RxResult<T> tryRequireValue([String? context]) {
    return RxResult.tryExecute(
      () => requireValue(context),
      context ?? 'require non-null value',
    );
  }

  /// Check if value is not null
  bool get hasValue => value != null;

  /// Get value if not null, otherwise return fallback
  T orElse(T fallback) => value ?? fallback;

  /// Get value if not null, otherwise compute fallback
  T orElseGet(T Function() fallback) => value ?? fallback();
}

/// Async error handling extensions
extension RxAsyncErrorHandling<T> on Rx<T> {
  /// Set value from async operation with error handling
  Future<RxResult<void>> setFromAsync(
    Future<T> Function() operation, {
    String? context,
  }) async {
    final result = await RxResult.tryExecuteAsync(operation, context);
    return result.map((newValue) {
      value = newValue;
    });
  }

  /// Update value from async operation
  Future<RxResult<void>> updateFromAsync(
    Future<T> Function(T current) operation, {
    String? context,
  }) async {
    try {
      final currentValue = value;
      final result = await RxResult.tryExecuteAsync(
        () => operation(currentValue),
        context,
      );
      return result.map((newValue) {
        value = newValue;
      });
    } catch (e, stack) {
      return RxResult.failure(RxException.withTimestamp(
        context ?? 'Async update failed',
        originalError: e,
        stackTrace: stack,
      ));
    }
  }
}

/// Utility functions for error handling
class RxErrorUtils {
  /// Wrap multiple reactive operations in a try-catch
  static RxResult<List<T>> tryMultiple<T>(
      List<RxResult<T> Function()> operations) {
    final results = <T>[];
    for (int i = 0; i < operations.length; i++) {
      final result = operations[i]();
      if (result.isFailure) {
        return RxResult.failure(RxException.withTimestamp(
          'Operation $i failed in batch',
          originalError: result.errorOrNull,
        ));
      }
      results.add(result.value);
    }
    return RxResult.success(results);
  }

  /// Execute operation with timeout
  static Future<RxResult<T>> withTimeout<T>(
    Future<T> Function() operation,
    Duration timeout, {
    String? context,
  }) async {
    try {
      final result = await operation().timeout(timeout);
      return RxResult.success(result);
    } on TimeoutException {
      return RxResult.failure(RxException.withTimestamp(
        context != null
            ? 'Operation timed out: $context'
            : 'Operation timed out',
      ));
    } catch (e, stack) {
      return RxResult.failure(RxException.withTimestamp(
        context ?? 'Operation failed',
        originalError: e,
        stackTrace: stack,
      ));
    }
  }

  /// Create a circuit breaker for reactive operations
  static RxCircuitBreaker createCircuitBreaker({
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(minutes: 1),
  }) {
    return RxCircuitBreaker(
      failureThreshold: failureThreshold,
      resetTimeout: resetTimeout,
    );
  }
}

/// Circuit breaker for reactive operations
class RxCircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;

  int _failureCount = 0;
  DateTime? _lastFailureTime;
  bool _isOpen = false;

  RxCircuitBreaker({
    required this.failureThreshold,
    required this.resetTimeout,
  });

  /// Execute operation with circuit breaker protection
  RxResult<T> execute<T>(RxResult<T> Function() operation) {
    if (_isOpen && _shouldAttemptReset()) {
      _reset();
    }

    if (_isOpen) {
      return RxResult.failure(RxException.withTimestamp(
        'Circuit breaker is open',
      ));
    }

    final result = operation();
    if (result.isFailure) {
      _recordFailure();
    } else {
      _recordSuccess();
    }

    return result;
  }

  bool _shouldAttemptReset() {
    return _lastFailureTime != null &&
        DateTime.now().difference(_lastFailureTime!) > resetTimeout;
  }

  void _recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    if (_failureCount >= failureThreshold) {
      _isOpen = true;
    }
  }

  void _recordSuccess() {
    _failureCount = 0;
    _lastFailureTime = null;
  }

  void _reset() {
    _isOpen = false;
    _failureCount = 0;
    _lastFailureTime = null;
  }

  /// Get current state
  Map<String, dynamic> get state => {
        'isOpen': _isOpen,
        'failureCount': _failureCount,
        'lastFailureTime': _lastFailureTime?.toIso8601String(),
      };
}

/// Internal error logging
void _logError(RxException error) {
  if (_globalErrorConfig.logErrors) {
    if (_globalErrorConfig.customLogger != null) {
      _globalErrorConfig.customLogger!(error);
    } else {
      debugPrint('RxError: $error');
    }
  }
}
