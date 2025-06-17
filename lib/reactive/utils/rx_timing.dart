// lib/reactive/utils/rx_timing.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/rx_value.dart';

/// Global timing utilities for reactive values
class RxTimingUtils {
  static final Map<Rx, _TimingData> _timingRegistry = {};

  /// Get the number of tracked instances
  static int get trackedInstanceCount => _timingRegistry.length;

  /// Clear all timing data and cleanup resources
  static void clearAllTimingData() {
    for (final data in _timingRegistry.values) {
      data.cleanup();
    }
    _timingRegistry.clear();
  }

  /// Register a reactive value for timing tracking
  static void _register(Rx rx) {
    _timingRegistry[rx] ??= _TimingData();
  }

  /// Unregister a reactive value
  static void _unregister(Rx rx) {
    final data = _timingRegistry.remove(rx);
    data?.cleanup();
  }

  /// Get timing data for a reactive value
  static _TimingData? _getTimingData(Rx rx) {
    return _timingRegistry[rx];
  }
}

/// Internal timing data storage
class _TimingData {
  int changeCount = 0;
  DateTime? lastChangeTime;
  final List<Timer> _timers = [];
  final List<StreamSubscription> _subscriptions = [];

  void trackChange() {
    changeCount++;
    lastChangeTime = DateTime.now();
  }

  void reset() {
    changeCount = 0;
    lastChangeTime = null;
  }

  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void cleanup() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  Map<String, dynamic> get stats => {
    'changeCount': changeCount,
    'lastChangeTime': lastChangeTime,
  };
}

/// Performance tracking extensions for reactive values
extension RxPerformanceExtensions<T> on Rx<T> {
  /// Track a change for performance monitoring
  void trackChange() {
    RxTimingUtils._register(this);
    RxTimingUtils._getTimingData(this)?.trackChange();
  }

  /// Get performance statistics
  Map<String, dynamic> get performanceStats {
    final data = RxTimingUtils._getTimingData(this);
    return data?.stats ?? {'changeCount': 0, 'lastChangeTime': null};
  }

  /// Reset performance statistics
  void resetPerformanceStats() {
    final data = RxTimingUtils._getTimingData(this);
    data?.reset();
  }

  /// Cleanup timing resources for this instance
  void cleanupTiming() {
    RxTimingUtils._unregister(this);
  }
}

/// Timing extensions for reactive values
extension RxTimingExtensions<T> on Rx<T> {
  /// Debounce value changes - callback is called after duration of inactivity
  void debounce(Duration duration, void Function(T value) callback) {
    RxTimingUtils._register(this);
    Timer? timer;

    void listener() {
      timer?.cancel();
      timer = Timer(duration, () {
        callback(value);
      });

      // Track the timer for cleanup
      if (timer != null) {
        RxTimingUtils._getTimingData(this)?.addTimer(timer!);
      }
    }

    addListener(listener);
  }

  /// Throttle value changes - callback is called at most once per duration
  void throttle(Duration duration, void Function(T value) callback) {
    RxTimingUtils._register(this);
    bool canCall = true;

    void listener() {
      if (canCall) {
        canCall = false;
        callback(value); // Use current value, not previous
        final timer = Timer(duration, () {
          canCall = true;
        });

        // Track the timer for cleanup
        RxTimingUtils._getTimingData(this)?.addTimer(timer);
      }
    }

    addListener(listener);
  }

  /// Sample value changes at regular intervals
  StreamSubscription<T> sample(Duration interval, void Function(T value) callback) {
    RxTimingUtils._register(this);
    late StreamController<T> controller;
    Timer? timer;

    void listener() {
      if (!controller.isClosed) {
        controller.add(value);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        addListener(listener);
        timer = Timer.periodic(interval, (_) {
          if (!controller.isClosed) {
            controller.add(value);
          }
        });

        // Track the timer for cleanup
        if (timer != null) {
          RxTimingUtils._getTimingData(this)?.addTimer(timer!);
        }
      },
      onCancel: () {
        removeListener(listener);
        timer?.cancel();
      },
    );

    final subscription = controller.stream.listen(callback);
    RxTimingUtils._getTimingData(this)?.addSubscription(subscription);
    return subscription;
  }

  /// Delay value changes by specified duration
  void delay(Duration duration, void Function(T value) callback) {
    RxTimingUtils._register(this);

    void listener() {
      final timer = Timer(duration, () {
        callback(value);
      });

      // Track the timer for cleanup
      RxTimingUtils._getTimingData(this)?.addTimer(timer);
    }

    addListener(listener);
  }

  /// Buffer value changes for specified duration
  void buffer(Duration duration, void Function(List<T> values) callback) {
    RxTimingUtils._register(this);
    final buffer = <T>[];
    Timer? timer;

    void listener() {
      buffer.add(value);
      timer?.cancel();
      timer = Timer(duration, () {
        if (buffer.isNotEmpty) {
          callback(List.from(buffer));
          buffer.clear();
        }
      });

      // Track the timer for cleanup
      if (timer != null) {
        RxTimingUtils._getTimingData(this)?.addTimer(timer!);
      }
    }

    addListener(listener);
  }

  /// Take only first n value changes
  void take(int count, void Function(T value) callback) {
    var callCount = 0;
    late VoidCallback listener;

    listener = () {
      if (callCount < count) {
        callCount++;
        callback(value);
        if (callCount >= count) {
          removeListener(listener);
        }
      }
    };

    addListener(listener);
  }

  /// Skip first n value changes
  void skip(int count, void Function(T value) callback) {
    var skipCount = 0;

    void listener() {
      if (skipCount < count) {
        skipCount++;
      } else {
        callback(value);
      }
    }

    addListener(listener);
  }

  /// Only call callback when value meets condition
  void where(bool Function(T value) condition, void Function(T value) callback) {
    void listener() {
      if (condition(value)) {
        callback(value);
      }
    }

    addListener(listener);
  }

  /// Transform value before calling callback
  void map<R>(R Function(T value) transformer, void Function(R value) callback) {
    void listener() {
      final transformed = transformer(value);
      callback(transformed);
    }

    addListener(listener);
  }

  /// Only call callback when value actually changes (distinct)
  void distinct(void Function(T value) callback, [bool Function(T previous, T current)? equals]) {
    T? previousValue;
    bool hasBeenSet = false;

    void listener() {
      final currentValue = value;
      if (!hasBeenSet) {
        hasBeenSet = true;
        previousValue = currentValue;
        callback(currentValue);
        return;
      }

      final areEqual = equals?.call(previousValue as T, currentValue) ??
          (previousValue == currentValue);

      if (!areEqual) {
        previousValue = currentValue;
        callback(currentValue);
      }
    }

    addListener(listener);
  }
}

/// Reactive interval that emits values at regular intervals
class RxInterval extends Rx<int> {
  Timer? _timer;
  final Duration _interval;

  RxInterval(this._interval) : super(0);

  void start() {
    stop();
    _timer = Timer.periodic(_interval, (timer) {
      value++;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    value = 0;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Create a reactive timer that counts down
class RxTimer extends Rx<Duration> {
  Timer? _timer;
  final Duration _interval;
  Duration _remaining;
  final VoidCallback? _onComplete;

  RxTimer(super.duration, {VoidCallback? onComplete, Duration? interval})
      : _remaining = duration,
        _onComplete = onComplete,
        _interval = interval ?? const Duration(seconds: 1);

  void start() {
    stop();
    _timer = Timer.periodic(_interval, (timer) {
      _remaining -= _interval;
      value = _remaining;

      if (_remaining <= Duration.zero) {
        stop();
        _onComplete?.call();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset(Duration? newDuration) {
    stop();
    _remaining = newDuration ?? value;
    value = _remaining;
  }

  bool get isRunning => _timer?.isActive ?? false;

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}