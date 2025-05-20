// lib/zenify/workers/rx_workers.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_logger.dart';
import '../core/zen_metrics.dart';
import '../core/zen_config.dart';

/// Defines the different types of reactive workers
enum WorkerType {
  /// Executes whenever the value changes
  ever,

  /// Executes only once on the first change
  once,

  /// Executes after a delay, resets the timer on each change
  debounce,

  /// Executes at most once per specified duration
  throttle,

  /// Executes periodically while a condition is true
  interval,

  /// Conditionally executes based on value changes
  condition,
}

/// A worker that reacts to changes in an observable value
///
/// Workers provide a way to execute callbacks in response to changes
/// in reactive state, with different timing and filtering options.
class ZenWorker<T> {
  final WorkerType type;
  final void Function(T) callback;
  final Duration? duration;
  final String? name;

  Timer? _timer;
  DateTime? _lastRun;
  bool _disposed = false;
  void Function()? _disposer;

  /// Creates a worker with the specified configuration
  ///
  /// [type] - The type of worker (ever, once, debounce, etc)
  /// [callback] - Function to execute when the worker triggers
  /// [duration] - Required for debounce, throttle, and interval types
  /// [name] - Optional name for logging and metrics
  ZenWorker({
    required this.type,
    required this.callback,
    this.duration,
    this.name,
  }) {
    _validateConfig();

    if (name != null && ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Worker "$name" created with type ${type.name}');
    }
  }

  void _validateConfig() {
    if ((type == WorkerType.debounce ||
        type == WorkerType.throttle ||
        type == WorkerType.interval) &&
        duration == null) {
      throw ArgumentError('Duration must be provided for ${type.name} worker');
    }
  }

  /// Sets up this worker to listen to a ValueNotifier (like Rx or RxCollection)
  void listenToValueNotifier(ValueNotifier<T> value) {
    if (_disposed) return;

    switch (type) {
      case WorkerType.ever:
        _setupEverRx(value);
        break;
      case WorkerType.once:
        _setupOnceRx(value);
        break;
      case WorkerType.debounce:
        _setupDebounceRx(value);
        break;
      case WorkerType.throttle:
        _setupThrottleRx(value);
        break;
      case WorkerType.interval:
        _setupIntervalRx(value);
        break;
      case WorkerType.condition:
        _setupConditionRx(value);
        break;
    }

    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.incrementCounter('worker.created');
      ZenMetrics.incrementCounter('worker.type.${type.name}');
    }
  }

  // Implementation for ValueNotifier-based reactivity

  void _setupEverRx(ValueNotifier<T> rx) {
    void listener() {
      if (_disposed) return;

      _executeCallback(rx.value);
    }

    rx.addListener(listener);
    _disposer = () => rx.removeListener(listener);
  }

  void _setupOnceRx(ValueNotifier<T> rx) {
    void oneTimeListener() {
      if (_disposed) return;

      _executeCallback(rx.value);
      // Remove listener after first execution
      rx.removeListener(oneTimeListener);
    }

    rx.addListener(oneTimeListener);
    _disposer = () => rx.removeListener(oneTimeListener);
  }

  void _setupDebounceRx(ValueNotifier<T> rx) {
    void listener() {
      if (_disposed) return;

      _timer?.cancel();
      _timer = Timer(duration!, () {
        if (!_disposed) {
          _executeCallback(rx.value);
        }
      });
    }

    rx.addListener(listener);
    _disposer = () {
      rx.removeListener(listener);
      _timer?.cancel();
    };
  }

  void _setupThrottleRx(ValueNotifier<T> rx) {
    void listener() {
      if (_disposed) return;

      final now = DateTime.now();
      if (_lastRun == null || now.difference(_lastRun!) > duration!) {
        _lastRun = now;
        _executeCallback(rx.value);
      }
    }

    rx.addListener(listener);
    _disposer = () => rx.removeListener(listener);
  }

  void _setupIntervalRx(ValueNotifier<T> rx) {
    // Store initial value for comparison
    T lastValue = rx.value;
    bool valueChanged = false;

    void listener() {
      if (_disposed) return;
      valueChanged = true;
      lastValue = rx.value;
    }

    rx.addListener(listener);

    // Set up periodic timer
    _timer = Timer.periodic(duration!, (_) {
      if (_disposed) return;

      if (valueChanged) {
        _executeCallback(lastValue);
        valueChanged = false;
      }
    });

    _disposer = () {
      rx.removeListener(listener);
      _timer?.cancel();
    };
  }

  void _setupConditionRx(ValueNotifier<T> rx) {
    void listener() {
      if (_disposed) return;

      // For condition type, we assume the callback does its own filtering
      _executeCallback(rx.value);
    }

    rx.addListener(listener);
    _disposer = () => rx.removeListener(listener);
  }

  /// Safely executes the callback with performance tracking
  void _executeCallback(T value) {
    if (_disposed) return;

    try {
      if (ZenConfig.enablePerformanceMetrics) {
        final metricName = name != null
            ? 'worker.$name.execution'
            : 'worker.${type.name}.execution';
        ZenMetrics.startTiming(metricName);
      }

      callback(value);

      if (ZenConfig.enablePerformanceMetrics) {
        final metricName = name != null
            ? 'worker.$name.execution'
            : 'worker.${type.name}.execution';
        ZenMetrics.stopTiming(metricName);
        ZenMetrics.incrementCounter('worker.executions');
      }
    } catch (e, stack) {
      ZenLogger.logError(
          'Error in worker ${name ?? type.name} callback',
          e,
          stack
      );

      if (ZenConfig.enablePerformanceMetrics) {
        ZenMetrics.incrementCounter('worker.errors');
      }
    }
  }

  /// Disposes this worker, cancelling any active timers or subscriptions
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _timer?.cancel();
    _disposer?.call();

    if (ZenConfig.enableDebugLogs && name != null) {
      ZenLogger.logDebug('Worker "$name" disposed');
    }

    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.incrementCounter('worker.disposed');
    }
  }
}

/// ZenWorkers API that mimics GetX workers with enhanced functionality
class ZenWorkers {
  /// For ValueNotifier/Rx<T> based reactivity - runs callback every time value changes
  static void Function() ever<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.ever,
      callback: callback,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    return () => worker.dispose();
  }

  /// For ValueNotifier/Rx<T> based reactivity - runs callback only on first change
  static void Function() once<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.once,
      callback: callback,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    return () => worker.dispose();
  }

  /// For ValueNotifier/Rx<T> based reactivity - runs callback after value stops changing for duration
  static void Function() debounce<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        Duration duration = const Duration(milliseconds: 800),
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.debounce,
      callback: callback,
      duration: duration,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    return () => worker.dispose();
  }

  /// For ValueNotifier/Rx<T> based reactivity - limits how frequently the callback can run
  static void Function() interval<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        Duration duration = const Duration(milliseconds: 800),
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.interval,
      callback: callback,
      duration: duration,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    return () => worker.dispose();
  }

  /// For ValueNotifier/Rx<T> based reactivity - runs callback at most once per specified time period
  static void Function() throttle<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        Duration duration = const Duration(milliseconds: 800),
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.throttle,
      callback: callback,
      duration: duration,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    return () => worker.dispose();
  }

  /// Conditional worker - only executes when a specific condition is met
  static void Function() condition<T>(
      ValueNotifier<T> reactive,
      bool Function(T) condition,
      void Function(T) callback, {
        String? name,
      }) {
    // Create a callback that checks the condition first
    void conditionalCallback(T value) {
      if (condition(value)) {
        callback(value);
      }
    }

    final worker = ZenWorker<T>(
      type: WorkerType.condition,
      callback: conditionalCallback,
      name: name,
    );

    worker.listenToValueNotifier(reactive);
    return () => worker.dispose();
  }

  /// Create a worker that can be configured and started later
  static ZenWorker<T> create<T>({
    required WorkerType type,
    required void Function(T) callback,
    Duration? duration,
    String? name,
  }) {
    return ZenWorker<T>(
      type: type,
      callback: callback,
      duration: duration,
      name: name,
    );
  }
}

/// Extension for ZenController to easily add workers
extension ZenWorkersControllerExtension on ZenController {
  /// Add a worker that will be auto-disposed when the controller is disposed
  void addWorker<T>(
      ZenWorker<T> worker,
      ValueNotifier<T> reactive) {
    worker.listenToValueNotifier(reactive);

    // Auto-dispose the worker when the controller is disposed
    addDisposer(() => worker.dispose());
  }

  // Convenience methods for common worker types

  /// Add an "ever" worker that will be auto-disposed
  void ever<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.ever,
      callback: callback,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    addDisposer(() => worker.dispose());
  }

  /// Add a "debounce" worker that will be auto-disposed
  void debounce<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        Duration duration = const Duration(milliseconds: 800),
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.debounce,
      callback: callback,
      duration: duration,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    addDisposer(() => worker.dispose());
  }

  /// Add a "throttle" worker that will be auto-disposed
  void throttle<T>(
      ValueNotifier<T> rx,
      void Function(T) callback, {
        Duration duration = const Duration(milliseconds: 800),
        String? name,
      }) {
    final worker = ZenWorker<T>(
      type: WorkerType.throttle,
      callback: callback,
      duration: duration,
      name: name,
    );

    worker.listenToValueNotifier(rx);
    addDisposer(() => worker.dispose());
  }
}