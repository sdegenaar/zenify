// lib/zenify/zen_metrics.dart
import 'dart:async';
import 'zen_config.dart';
import 'zen_logger.dart';

/// Performance and usage metrics for ZenState
class ZenMetrics {
  ZenMetrics._(); // Private constructor

  /// Controller metrics
  static int activeControllers = 0;
  static int totalControllersCreated = 0;
  static int totalControllersDisposed = 0;
  static Map<String, int> controllerCreationCount = {}; // Changed Type to String

  /// Reactive state metrics
  static int totalRxValues = 0;
  static int totalStateUpdates = 0;
  static int totalProviders = 0;

  /// Effect metrics
  static int totalEffectRuns = 0;
  static int totalEffectSuccesses = 0;
  static int totalEffectFailures = 0;
  static Map<String, int> effectSuccessCounts = {};
  static Map<String, int> effectFailureCounts = {};

  /// General metrics counters for tracking events and operations
  static final Map<String, int> _counters = {};

  /// Performance metrics
  static final Map<String, List<Duration>> _operationTimes = {};
  static final Stopwatch _stopwatch = Stopwatch();

  /// Record controller creation
  static void recordControllerCreation(Type controllerType) {
    if (!ZenConfig.enablePerformanceTracking) return;

    activeControllers++;
    totalControllersCreated++;

    final name = controllerType.toString();
    controllerCreationCount[name] = (controllerCreationCount[name] ?? 0) + 1;
  }

  /// Record controller disposal
  static void recordControllerDisposal(Type controllerType) {
    if (!ZenConfig.enablePerformanceTracking) return;

    activeControllers--;
    totalControllersDisposed++;
  }

  /// Record Rx value creation
  static void recordRxCreation() {
    if (!ZenConfig.enablePerformanceTracking) return;

    totalRxValues++;
  }

  /// Record state update
  static void recordStateUpdate() {
    if (!ZenConfig.enablePerformanceTracking) return;

    totalStateUpdates++;
  }

  /// Record provider creation
  static void recordProviderCreation() {
    if (!ZenConfig.enablePerformanceTracking) return;

    totalProviders++;
  }

  /// Record a successful effect execution
  static void recordEffectSuccess(String effectName) {
    if (!ZenConfig.enablePerformanceTracking) return;

    totalEffectRuns++;
    totalEffectSuccesses++;
    effectSuccessCounts[effectName] = (effectSuccessCounts[effectName] ?? 0) + 1;
  }

  /// Record a failed effect execution
  static void recordEffectFailure(String effectName) {
    if (!ZenConfig.enablePerformanceTracking) return;

    totalEffectRuns++;
    totalEffectFailures++;
    effectFailureCounts[effectName] = (effectFailureCounts[effectName] ?? 0) + 1;
  }

  /// Increment a named counter to track occurrences of an event
  static void incrementCounter(String name) {
    if (!ZenConfig.enablePerformanceTracking) return;

    _counters[name] = (_counters[name] ?? 0) + 1;
  }

  /// Record a specific value for a named counter
  static void recordCounterValue(String name, int value) {
    if (!ZenConfig.enablePerformanceTracking) return;

    _counters[name] = value;
  }

  /// Start timing an operation
  static void startTiming(String operation) {
    if (!ZenConfig.enablePerformanceTracking) return;

    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Stop timing an operation and record the result
  static void stopTiming(String operation) {
    if (!ZenConfig.enablePerformanceTracking || !_stopwatch.isRunning) return;

    _stopwatch.stop();
    final duration = _stopwatch.elapsed;

    if (!_operationTimes.containsKey(operation)) {
      _operationTimes[operation] = [];
    }

    _operationTimes[operation]!.add(duration);

    // If the list gets too long, keep only the most recent entries
    if (_operationTimes[operation]!.length > 100) {
      _operationTimes[operation] = _operationTimes[operation]!.sublist(
          _operationTimes[operation]!.length - 100
      );
    }
  }

  /// Get average duration for an operation
  static Duration? getAverageDuration(String operation) {
    if (!_operationTimes.containsKey(operation) || _operationTimes[operation]!.isEmpty) {
      return null;
    }

    final durations = _operationTimes[operation]!;
    final totalMicroseconds = durations.fold<int>(
        0, (sum, duration) => sum + duration.inMicroseconds
    );

    return Duration(microseconds: totalMicroseconds ~/ durations.length);
  }

  /// Get metrics report
  static Map<String, dynamic> getReport() {
    // Calculate average durations
    final avgDurations = <String, String>{};
    _operationTimes.forEach((key, durations) {
      final avg = getAverageDuration(key);
      if (avg != null) {
        avgDurations[key] = '${avg.inMicroseconds / 1000.0}ms';
      }
    });

    return {
      'controllers': {
        'active': activeControllers,
        'created': totalControllersCreated,
        'disposed': totalControllersDisposed,
        'byType': controllerCreationCount,
      },
      'state': {
        'rxValues': totalRxValues,
        'stateUpdates': totalStateUpdates,
        'providers': totalProviders,
      },
      'effects': {
        'totalRuns': totalEffectRuns,
        'successful': totalEffectSuccesses,
        'failed': totalEffectFailures,
        'successByName': effectSuccessCounts,
        'failureByName': effectFailureCounts,
      },
      'counters': Map.from(_counters),
      'performance': {
        'averageDurations': avgDurations,
      }
    };
  }

  /// Reset all metrics
  static void reset() {
    activeControllers = 0;
    totalControllersCreated = 0;
    totalControllersDisposed = 0;
    controllerCreationCount.clear();
    totalRxValues = 0;
    totalStateUpdates = 0;
    totalProviders = 0;
    totalEffectRuns = 0;
    totalEffectSuccesses = 0;
    totalEffectFailures = 0;
    effectSuccessCounts.clear();
    effectFailureCounts.clear();
    _counters.clear();
    _operationTimes.clear();
  }

  /// Periodically log metrics (for monitoring)
  static Timer? _metricsTimer;

  static void startPeriodicLogging(Duration interval) {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(interval, (_) {
      if (ZenConfig.enablePerformanceTracking) {
        final report = getReport();
        ZenLogger.logInfo('ZenMetrics: ${report.toString()}');
      }
    });
  }

  static void stopPeriodicLogging() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }
}