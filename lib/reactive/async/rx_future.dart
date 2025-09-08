// lib/reactive/async/rx_future.dart
import 'package:flutter/widgets.dart';
import '../core/rx_tracking.dart';
import '../core/rx_error_handling.dart';
import '../utils/rx_logger.dart';

/// A reactive wrapper for Future operations with state management
class RxFuture<T> extends ValueNotifier<AsyncSnapshot<T>> {
  Future<T>? _currentFuture;
  Future<T> Function()? _futureFactory;

  RxFuture([Future<T>? initialFuture]) : super(const AsyncSnapshot.waiting()) {
    if (initialFuture != null) {
      future = initialFuture;
    }
  }

  /// Create RxFuture with a factory function that can be refreshed
  RxFuture.fromFactory(Future<T> Function() futureFactory)
      : _futureFactory = futureFactory,
        super(const AsyncSnapshot.waiting()) {
    _executeFuture();
  }

  /// Get the current future
  Future<T>? get future => _currentFuture;

  /// Set a new future to watch
  set future(Future<T>? newFuture) {
    _futureFactory = null;
    _currentFuture = newFuture;

    if (newFuture == null) {
      value = const AsyncSnapshot.waiting();
      return;
    }

    value = const AsyncSnapshot.waiting();
    _watchFuture(newFuture);
  }

  /// Set future from a factory function (enables refresh)
  void setFutureFactory(Future<T> Function() futureFactory) {
    _futureFactory = futureFactory;
    _executeFuture();
  }

  void _executeFuture() {
    if (_futureFactory == null) return;

    final newFuture = _futureFactory!();
    _currentFuture = newFuture;
    value = const AsyncSnapshot.waiting();
    _watchFuture(newFuture);
  }

  void _watchFuture(Future<T> future) {
    future.then(
      (data) {
        if (_currentFuture == future) {
          value = AsyncSnapshot.withData(ConnectionState.done, data);
        }
      },
      onError: (error, stackTrace) {
        if (_currentFuture == future) {
          // Enhanced error handling with centralized logging
          final rxError = error is RxException
              ? error
              : RxException.withTimestamp(
                  'Future operation failed',
                  originalError: error,
                  stackTrace: stackTrace,
                );

          RxLogger.logError(rxError, context: 'Future');
          value = AsyncSnapshot.withError(
              ConnectionState.done, rxError, stackTrace);
        }
      },
    );
  }

  /// Manually set data state with error handling
  RxResult<void> trySetData(T data) {
    return RxResult.tryExecute(() {
      value = AsyncSnapshot.withData(ConnectionState.done, data);
    }, 'set future data');
  }

  /// Manually set error state with enhanced error info
  void setError(Object error, [StackTrace? stackTrace]) {
    final rxError = error is RxException
        ? error
        : RxException.withTimestamp(
            'Manual error set',
            originalError: error,
            stackTrace: stackTrace,
          );

    value = AsyncSnapshot.withError(
      ConnectionState.done,
      rxError,
      stackTrace ?? StackTrace.current,
    );
  }

  /// Manually set loading state
  void setLoading() {
    value = const AsyncSnapshot.waiting();
  }

  /// Refresh the future - re-executes if factory is available, otherwise restarts current future
  void refresh() {
    final result = tryRefresh();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Future');
    }
  }

  /// Refresh with error handling
  RxResult<void> tryRefresh() {
    return RxResult.tryExecute(() {
      if (_futureFactory != null) {
        // If we have a factory, call it to create a new future
        _executeFuture();
      } else if (_currentFuture != null) {
        // If we only have a current future, restart it by setting loading and re-watching
        // Note: This won't actually re-execute the future logic, just reset the state
        value = const AsyncSnapshot.waiting();
        _watchFuture(_currentFuture!);
      } else {
        throw const RxException('No future or factory available to refresh');
      }
    }, 'refresh future');
  }

  // Enhanced getters with error handling
  bool get isLoading {
    RxTracking.track(this);
    return value.connectionState == ConnectionState.waiting;
  }

  bool get hasData {
    RxTracking.track(this);
    return value.hasData;
  }

  bool get hasError {
    RxTracking.track(this);
    return value.hasError;
  }

  T? get data {
    RxTracking.track(this);
    return value.data;
  }

  Object? get error {
    RxTracking.track(this);
    return value.error;
  }

  StackTrace? get stackTrace {
    RxTracking.track(this);
    return value.stackTrace;
  }

  /// Get error as RxException if available
  RxException? get rxError {
    RxTracking.track(this);
    final err = value.error;
    return err is RxException ? err : null;
  }

  /// Get the original error (unwrapped from RxException if applicable)
  Object? get originalError {
    RxTracking.track(this);
    final err = value.error;
    if (err is RxException) {
      return err.originalError;
    }
    return err;
  }

  /// Get error message as string
  String? get errorMessage {
    RxTracking.track(this);
    final err = originalError;
    return err?.toString();
  }

  /// Get data with fallback
  T dataOr(T fallback) {
    RxTracking.track(this);
    return data ?? fallback;
  }

  /// Get data with error handling
  RxResult<T> tryGetData() {
    RxTracking.track(this);
    if (hasError) {
      final err = error;
      final rxError = err is RxException
          ? err
          : RxException.withTimestamp(
              'Future has error state',
              originalError: err,
            );
      return RxResult.failure(rxError);
    }

    if (!hasData) {
      return RxResult.failure(
        RxException.withTimestamp('Future has no data available'),
      );
    }

    return RxResult.success(data as T);
  }

  /// Transform data if available
  RxFuture<R> map<R>(R Function(T data) mapper) {
    final result = RxFuture<R>();

    addListener(() {
      if (hasData) {
        try {
          result.trySetData(mapper(data as T));
        } catch (e, stack) {
          result.setError(e, stack);
        }
      } else if (hasError) {
        result.setError(error!, stackTrace);
      } else {
        result.setLoading();
      }
    });

    return result;
  }

  @override
  String toString() =>
      'RxFuture<$T>(loading: $isLoading, hasData: $hasData, hasError: $hasError)';
}
