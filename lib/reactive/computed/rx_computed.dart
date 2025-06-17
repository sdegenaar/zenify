// lib/reactive/computed/rx_computed.dart
import 'package:flutter/foundation.dart';
import '../core/rx_value.dart';
import '../core/rx_tracking.dart';
import '../core/rx_error_handling.dart';

/// A computed reactive value that automatically updates when its dependencies change
class RxComputed<T> extends ValueNotifier<T> {
  final T Function() _computation;
  final Set<ValueNotifier> _dependencies = {};
  bool _disposed = false;
  bool _computing = false;
  RxException? _lastError; // ← Add error tracking

  RxComputed._(super.initialValue, this._computation);

  factory RxComputed(T Function() computation) {
    final trackedDeps = <ValueNotifier>{};

    RxTracking.setTrackerWithoutRebuild((notifier) {
      trackedDeps.add(notifier);
    });

    late T initialValue;
    RxException? initError;

    try {
      initialValue = computation();
    } catch (e, stack) {
      initError = RxException.withTimestamp(
        'Error in computed value initialization',
        originalError: e,
        stackTrace: stack,
      );
      rethrow;
    } finally {
      RxTracking.clearTracker();
    }

    final instance = RxComputed._(initialValue, computation);
    instance._lastError = initError;

    for (final dep in trackedDeps) {
      instance._dependencies.add(dep);
      dep.addListener(instance._onDependencyChanged);
    }

    return instance;
  }

  /// Whether this computed value has been disposed
  bool get isDisposed => _disposed;

  /// Get the dependencies this computed value relies on
  Set<ValueNotifier> get dependencies => Set.unmodifiable(_dependencies);

  /// Get the last error that occurred during computation
  RxException? get lastError => _lastError;

  /// Whether the computed value has an error
  bool get hasError => _lastError != null;

  static (T, Set<ValueNotifier>) _computeAndTrackDependencies<T>(T Function() computation) {
    final trackedDeps = <ValueNotifier>{};

    RxTracking.setTrackerWithoutRebuild((notifier) {
      trackedDeps.add(notifier);
    });

    try {
      final result = computation();
      return (result, trackedDeps);
    } finally {
      RxTracking.clearTracker();
    }
  }

  void _onDependencyChanged() {
    if (_disposed || _computing) return;

    _computing = true;
    try {
      final result = _computeAndTrackDependencies(_computation);
      final newValue = result.$1;
      final newDeps = result.$2;

      // Clear any previous error
      _lastError = null;

      // Remove old listeners
      for (final dep in _dependencies) {
        dep.removeListener(_onDependencyChanged);
      }
      _dependencies.clear();

      // Add new dependencies
      for (final dep in newDeps) {
        _dependencies.add(dep);
        dep.addListener(_onDependencyChanged);
      }

      super.value = newValue;
    } catch (e, stack) {
      _lastError = RxException.withTimestamp(
        'Error in computed value update',
        originalError: e,
        stackTrace: stack,
      );

      // Log but don't throw - computed values should be resilient
      if (getRxErrorConfig().logErrors) {
        debugPrint('RxComputed Error: $_lastError');
      }
    } finally {
      _computing = false;
    }
  }

  @override
  T get value {
    RxTracking.track(this);
    return super.value;
  }

  /// Get value with error handling
  RxResult<T> tryGetValue() {
    if (_lastError != null) {
      return RxResult.failure(_lastError!);
    }
    return RxResult.success(value);
  }

  /// Get value or fallback if there's an error
  T valueOr(T fallback) {
    if (_lastError != null) {
      return fallback;
    }
    return value;
  }

  @override
  set value(T newValue) {
    throw UnsupportedError('Cannot set value of computed reactive. Use dependencies instead.');
  }

  /// Force recomputation of the value
  void refresh() {
    _onDependencyChanged();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    for (final dep in _dependencies) {
      dep.removeListener(_onDependencyChanged);
    }
    _dependencies.clear();

    super.dispose();
  }

  @override
  String toString() => 'RxComputed<$T>($value, deps: ${_dependencies.length}, disposed: $_disposed, hasError: $hasError)';
}

// Rest of the file remains the same...
RxComputed<T> computed<T>(T Function() computation) {
  return RxComputed<T>(computation);
}

extension RxComputedExtensions<T> on Rx<T> {
  RxComputed<R> map<R>(R Function(T value) mapper) {
    return computed(() => mapper(value));
  }

  RxComputed<T?> where(bool Function(T value) predicate) {
    return computed(() => predicate(value) ? value : null);
  }

  RxComputed<R> combineWith<U, R>(Rx<U> other, R Function(T a, U b) combiner) {
    return computed(() => combiner(value, other.value));
  }
}

extension RxCombine on Never {
  static RxComputed<R> combine2<T1, T2, R>(
      Rx<T1> rx1,
      Rx<T2> rx2,
      R Function(T1, T2) combiner,
      ) {
    return computed(() => combiner(rx1.value, rx2.value));
  }

  static RxComputed<R> combine3<T1, T2, T3, R>(
      Rx<T1> rx1,
      Rx<T2> rx2,
      Rx<T3> rx3,
      R Function(T1, T2, T3) combiner,
      ) {
    return computed(() => combiner(rx1.value, rx2.value, rx3.value));
  }

  static RxComputed<R> combine4<T1, T2, T3, T4, R>(
      Rx<T1> rx1,
      Rx<T2> rx2,
      Rx<T3> rx3,
      Rx<T4> rx4,
      R Function(T1, T2, T3, T4) combiner,
      ) {
    return computed(() => combiner(rx1.value, rx2.value, rx3.value, rx4.value));
  }
}