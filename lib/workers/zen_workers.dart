// lib/workers/zen_workers.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/zen_logger.dart';

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
  condition;
}

/// Handle for controlling worker lifecycle
class ZenWorkerHandle {
  final void Function() _disposer;
  final void Function()? _pauseFunction;
  final void Function()? _resumeFunction;
  final bool Function()? _isPausedGetter;
  final bool Function()? _isDisposedGetter;

  bool _disposed = false;
  bool _paused = false;

  ZenWorkerHandle(this._disposer, {
    void Function()? pauseFunction,
    void Function()? resumeFunction,
    bool Function()? isPausedGetter,
    bool Function()? isDisposedGetter,
  }) : _pauseFunction = pauseFunction,
        _resumeFunction = resumeFunction,
        _isPausedGetter = isPausedGetter,
        _isDisposedGetter = isDisposedGetter;

  /// Dispose the worker
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _disposer();
    }
  }

  /// Pause the worker (prevents execution but keeps listening)
  void pause() {
    if (_pauseFunction != null) {
      _pauseFunction!();
    } else {
      _paused = true;
    }
  }

  /// Resume the worker
  void resume() {
    if (_resumeFunction != null) {
      _resumeFunction!();
    } else {
      _paused = false;
    }
  }

  /// Whether the worker is disposed
  bool get isDisposed {
    if (_isDisposedGetter != null) {
      return _isDisposedGetter!();
    }
    return _disposed;
  }

  /// Whether the worker is paused
  bool get isPaused {
    if (_isPausedGetter != null) {
      return _isPausedGetter!();
    }
    return _paused;
  }

  /// Whether the worker is active (not disposed and not paused)
  bool get isActive => !isDisposed && !isPaused;
}

/// Group of workers that can be disposed together
class ZenWorkerGroup {
  final List<ZenWorkerHandle> _handles = [];
  bool _disposed = false;

  /// Add a worker to this group
  void add(ZenWorkerHandle handle) {
    if (_disposed) return;
    _handles.add(handle);
  }

  /// Get all workers in this group (for statistics)
  List<ZenWorkerHandle> get workers => List.unmodifiable(_handles);

  /// Pause all workers in the group
  void pauseAll() {
    for (final handle in _handles) {
      if (!handle.isDisposed) {
        handle.pause();
      }
    }
  }

  /// Resume all workers in the group
  void resumeAll() {
    for (final handle in _handles) {
      if (!handle.isDisposed) {
        handle.resume();
      }
    }
  }

  /// Dispose all workers in the group
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final handle in _handles) {
      handle.dispose();
    }
    _handles.clear();
  }

  /// Whether the group is disposed
  bool get isDisposed => _disposed;

  /// Number of active workers in the group (not disposed, not paused)
  int get activeCount => _handles.where((h) => h.isActive).length;

  /// Number of total workers in the group (not disposed)
  int get length => _handles.where((h) => !h.isDisposed).length;

  /// Number of paused workers in the group
  int get pausedCount => _handles.where((h) => !h.isDisposed && h.isPaused).length;
}

/// Core worker implementation with improved type safety and pause/resume support
class _ZenWorker<T> {
  final WorkerType type;
  final void Function(T) callback;
  final Duration? duration;
  final bool Function(T)? condition;

  Timer? _timer;
  DateTime? _lastRun;
  bool _disposed = false;
  bool _paused = false;
  void Function()? _disposer;
  bool _hasExecutedOnce = false; // Track if 'once' worker has executed
  ZenWorkerHandle? _handle; // Reference to the handle for auto-disposal

  _ZenWorker({
    required this.type,
    required this.callback,
    this.duration,
    this.condition,
  });

  /// Set the handle reference for auto-disposal
  void setHandle(ZenWorkerHandle handle) {
    _handle = handle;
  }

  /// Whether the worker is paused
  bool get isPaused => _paused;

  /// Whether the worker is disposed
  bool get isDisposed => _disposed;

  /// Pause the worker
  void pause() {
    _paused = true;
  }

  /// Resume the worker
  void resume() {
    _paused = false;
  }

  void listenTo(ValueNotifier<T> observable) {
    if (_disposed) return;

    switch (type) {
      case WorkerType.ever:
        _setupEver(observable);
      case WorkerType.once:
        _setupOnce(observable);
      case WorkerType.debounce:
        _setupDebounce(observable);
      case WorkerType.throttle:
        _setupThrottle(observable);
      case WorkerType.interval:
        _setupInterval(observable);
      case WorkerType.condition:
        _setupCondition(observable);
    }
  }

  void _setupEver(ValueNotifier<T> obs) {
    T? previous = obs.value;
    void listener() {
      if (_disposed || previous == obs.value || _paused) return;
      previous = obs.value;
      _execute(obs.value);
    }
    obs.addListener(listener);
    _disposer = () => obs.removeListener(listener);
  }

  void _setupOnce(ValueNotifier<T> obs) {
    void listener() {
      if (_disposed || _paused || _hasExecutedOnce) return;
      _hasExecutedOnce = true;
      _execute(obs.value);
      obs.removeListener(listener);
      // Auto-dispose the handle which will trigger worker disposal
      _handle?.dispose();
    }
    obs.addListener(listener);
    _disposer = () => obs.removeListener(listener);
  }

  void _setupDebounce(ValueNotifier<T> obs) {
    void listener() {
      if (_disposed || _paused) return;
      _timer?.cancel();
      _timer = Timer(duration!, () {
        if (!_disposed && !_paused) {
          _execute(obs.value);
        }
      });
    }
    obs.addListener(listener);
    _disposer = () {
      obs.removeListener(listener);
      _timer?.cancel();
    };
  }

  void _setupThrottle(ValueNotifier<T> obs) {
    void listener() {
      if (_disposed || _paused) return;
      final now = DateTime.now();
      if (_lastRun == null || now.difference(_lastRun!) > duration!) {
        _lastRun = now;
        _execute(obs.value);
      }
    }
    obs.addListener(listener);
    _disposer = () => obs.removeListener(listener);
  }

  void _setupInterval(ValueNotifier<T> obs) {
    T? lastProcessed;
    bool hasPendingChange = false;

    _timer = Timer.periodic(duration!, (_) {
      if (_disposed || _paused) return;
      final current = obs.value;
      if (hasPendingChange || lastProcessed != current) {
        lastProcessed = current;
        _execute(current);
        hasPendingChange = false;
      }
    });

    void listener() {
      if (_disposed) return;
      hasPendingChange = true;
    }
    obs.addListener(listener);
    _disposer = () {
      obs.removeListener(listener);
      _timer?.cancel();
    };
  }

  void _setupCondition(ValueNotifier<T> obs) {
    T? previous = obs.value;
    void listener() {
      if (_disposed || previous == obs.value || _paused) return;
      previous = obs.value;
      if (condition?.call(obs.value) ?? true) {
        _execute(obs.value);
      }
    }
    obs.addListener(listener);
    _disposer = () => obs.removeListener(listener);
  }

  void _execute(T value) {
    if (_disposed || _paused) return;
    try {
      callback(value);
    } catch (e, stack) {
      ZenLogger.logError('Worker execution error', e, stack);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _disposer?.call();
  }
}

/// Clean, composable ZenWorkers API with improved type inference and pause/resume support
class ZenWorkers {
  /// Universal worker creation method with explicit generic type preservation
  static ZenWorkerHandle watch<T>(
      ValueNotifier<T> observable,
      void Function(T) callback, {
        WorkerType type = WorkerType.ever,
        Duration? duration,
        bool Function(T)? condition,
      }) {
    // Validate configuration
    if ((type == WorkerType.debounce ||
        type == WorkerType.throttle ||
        type == WorkerType.interval) &&
        duration == null) {
      throw ArgumentError('Duration required for ${type.name}');
    }

    // Validate duration is not negative
    if (duration != null && duration.isNegative) {
      throw ArgumentError('Duration cannot be negative');
    }

    // Create worker first
    final worker = _ZenWorker<T>(
      type: type,
      callback: callback,
      duration: duration,
      condition: condition,
    );

    // Create handle with proper delegation
    final handle = ZenWorkerHandle(
          () => worker.dispose(),
      pauseFunction: () => worker.pause(),
      resumeFunction: () => worker.resume(),
      isPausedGetter: () => worker.isPaused,
      isDisposedGetter: () => worker.isDisposed,
    );

    // Set handle reference in worker for auto-disposal
    worker.setHandle(handle);

    worker.listenTo(observable);
    return handle;
  }

  /// Convenience methods with improved type inference
  static ZenWorkerHandle ever<T>(
      ValueNotifier<T> obs,
      void Function(T) callback,
      ) {
    return watch<T>(obs, callback, type: WorkerType.ever);
  }

  static ZenWorkerHandle once<T>(
      ValueNotifier<T> obs,
      void Function(T) callback,
      ) {
    return watch<T>(obs, callback, type: WorkerType.once);
  }

  static ZenWorkerHandle debounce<T>(
      ValueNotifier<T> obs,
      void Function(T) callback,
      Duration duration,
      ) {
    if (duration.isNegative) {
      throw ArgumentError('Duration cannot be negative');
    }
    return watch<T>(obs, callback, type: WorkerType.debounce, duration: duration);
  }

  static ZenWorkerHandle throttle<T>(
      ValueNotifier<T> obs,
      void Function(T) callback,
      Duration duration,
      ) {
    if (duration.isNegative) {
      throw ArgumentError('Duration cannot be negative');
    }
    return watch<T>(obs, callback, type: WorkerType.throttle, duration: duration);
  }

  static ZenWorkerHandle interval<T>(
      ValueNotifier<T> obs,
      void Function(T) callback,
      Duration duration,
      ) {
    if (duration.isNegative) {
      throw ArgumentError('Duration cannot be negative');
    }
    return watch<T>(obs, callback, type: WorkerType.interval, duration: duration);
  }

  static ZenWorkerHandle condition<T>(
      ValueNotifier<T> obs,
      bool Function(T) condition,
      void Function(T) callback,
      ) {
    return watch<T>(obs, callback, type: WorkerType.condition, condition: condition);
  }

  /// Composable worker for multiple observables
  static ZenWorkerHandle combine(List<ZenWorkerHandle> workers) {
    return ZenWorkerHandle(() {
      for (final worker in workers) {
        worker.dispose();
      }
    });
  }

  /// Create a worker group for batch operations
  static ZenWorkerGroup group() => ZenWorkerGroup();
}