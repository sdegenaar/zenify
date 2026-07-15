// lib/core/zen_metrics.dart
import 'dart:async';
import 'zen_config.dart';
import 'zen_logger.dart';

/// Performance and usage metrics for Zenify.
///
/// All recording methods are no-ops unless [ZenConfig.enablePerformanceMetrics]
/// is `true`. Read metrics via [getReport] or individual counter accessors.
class ZenMetrics {
  ZenMetrics._(); // Private constructor // coverage:ignore-line

  /// Controller lifecycle counters
  static int activeControllers = 0;
  static int totalControllersCreated = 0;
  static int totalControllersDisposed = 0;
  static Map<String, int> controllerCreationCount = {};

  /// General event counters — keyed by arbitrary string names.
  static final Map<String, int> _counters = {};

  /// Per-operation timing samples (capped at 100 per operation).
  static final Map<String, List<Duration>> _operationTimes = {};
  static final Stopwatch _stopwatch = Stopwatch();

  // ── Write-side (called internally by the library) ──────────────────────────

  /// Record controller creation.
  static void recordControllerCreation(Type controllerType) {
    if (!ZenConfig.enablePerformanceMetrics) return;

    activeControllers++;
    totalControllersCreated++;

    final name = controllerType.toString();
    controllerCreationCount[name] = (controllerCreationCount[name] ?? 0) + 1;
  }

  /// Record controller disposal.
  static void recordControllerDisposal(Type controllerType) {
    if (!ZenConfig.enablePerformanceMetrics) return;

    if (activeControllers > 0) activeControllers--;
    totalControllersDisposed++;
  }

  /// Increment a named event counter.
  static void incrementCounter(String name) {
    if (!ZenConfig.enablePerformanceMetrics) return;
    _counters[name] = (_counters[name] ?? 0) + 1;
  }

  /// Set a named counter to a specific value.
  static void recordCounterValue(String name, int value) {
    if (!ZenConfig.enablePerformanceMetrics) return;
    _counters[name] = value;
  }

  /// Begin timing an operation. Call [stopTiming] to record the sample.
  static void startTiming(String operation) {
    if (!ZenConfig.enablePerformanceMetrics) return;
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Stop timing an operation and record the elapsed duration.
  static void stopTiming(String operation) {
    if (!ZenConfig.enablePerformanceMetrics || !_stopwatch.isRunning) return;

    _stopwatch.stop();
    final duration = _stopwatch.elapsed;
    final samples = _operationTimes.putIfAbsent(operation, () => []);
    samples.add(duration);

    // Keep only the 100 most recent samples to bound memory usage.
    if (samples.length > 100) {
      _operationTimes[operation] = samples.sublist(samples.length - 100);
    }
  }

  // ── Read-side (user-facing) ─────────────────────────────────────────────────

  /// Get the average duration recorded for [operation], or `null` if no samples.
  static Duration? getAverageDuration(String operation) {
    final samples = _operationTimes[operation];
    if (samples == null || samples.isEmpty) return null;

    final totalMicroseconds =
        samples.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ samples.length);
  }

  /// Return a full snapshot of all recorded metrics.
  static Map<String, dynamic> getReport() {
    final avgDurations = <String, String>{};
    _operationTimes.forEach((key, _) {
      final avg = getAverageDuration(key);
      if (avg != null) avgDurations[key] = '${avg.inMicroseconds / 1000.0}ms';
    });

    return {
      'controllers': {
        'active': activeControllers,
        'created': totalControllersCreated,
        'disposed': totalControllersDisposed,
        'byType': Map.from(controllerCreationCount),
      },
      'counters': Map.from(_counters),
      'performance': {
        'averageDurations': avgDurations,
      },
    };
  }

  /// Reset all metrics to zero.
  static void reset() {
    activeControllers = 0;
    totalControllersCreated = 0;
    totalControllersDisposed = 0;
    controllerCreationCount.clear();
    _counters.clear();
    _operationTimes.clear();
  }

  // ── Periodic logging ────────────────────────────────────────────────────────

  static Timer? _metricsTimer;

  /// Log a [getReport] snapshot on [interval] until [stopPeriodicLogging] is called.
  static void startPeriodicLogging(Duration interval) {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(interval, (_) {
      if (ZenConfig.enablePerformanceMetrics) {
        ZenLogger.logInfo('ZenMetrics: ${getReport()}');
      }
    });
  }

  /// Stop periodic metric logging started by [startPeriodicLogging].
  static void stopPeriodicLogging() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }
}
