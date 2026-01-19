import 'package:flutter/material.dart';
import '../../reactive/core/rx_tracking.dart';
import '../../core/zen_logger.dart';
import '../../core/zen_config.dart';
import '../../core/zen_metrics.dart';

/// A widget that automatically rebuilds when any Rx value used in the builder changes
///
/// This widget tracks which Rx values are accessed within its builder function
/// and automatically rebuilds when any of those values change.
class Obx extends StatefulWidget {
  final Widget Function() builder;

  const Obx(this.builder, {super.key});

  @override
  State<Obx> createState() => _ObxState();
}

class _ObxState extends State<Obx> {
  // Track ValueNotifiers (Rx values) accessed in the build method
  final Set<ValueNotifier> _trackedValues = {};

  // For performance optimization
  bool _needsRebuild = false;
  Widget? _lastBuildResult;
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    ZenLogger.logRxTracking("Obx widget initialized");
  }

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }

  void _removeListeners() {
    for (final value in _trackedValues) {
      value.removeListener(_onValueChanged);
    }
    _trackedValues.clear();
  }

  void _onValueChanged() {
    if (mounted) {
      // Instead of immediately rebuilding, flag for rebuild
      _needsRebuild = true;

      ZenLogger.logRxTracking("Obx widget scheduling rebuild");

      setState(() {});
    }
  }

  // Add a value to track for reactivity
  void _trackValue(ValueNotifier value) {
    if (!_trackedValues.contains(value)) {
      _trackedValues.add(value);
      value.addListener(_onValueChanged);

      ZenLogger.logRxTracking("Tracking a new value: ${value.runtimeType}");
    }
  }

  // Track values without triggering rebuilds (for dependency collection)
  void _trackValueWithoutRebuild(ValueNotifier value) {
    if (!_trackedValues.contains(value)) {
      _trackedValues.add(value);
      value.addListener(_onValueChanged);

      ZenLogger.logRxTracking("Silently tracking value: ${value.runtimeType}");
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no rebuild needed and we have a previous result, reuse it
    if (!_needsRebuild && _lastBuildResult != null) {
      // We still need to execute the builder to track dependencies
      // but we don't need to use its result

      // Use the public method instead of accessing private field directly
      RxTracking.setTrackerWithoutRebuild(_trackValueWithoutRebuild);
      widget.builder(); // Just for tracking, we ignore the result
      RxTracking.clearTracker();

      if (ZenConfig.enablePerformanceMetrics) {
        ZenMetrics.incrementCounter('obx.skippedRebuilds');
      }

      return _lastBuildResult!;
    }

    // Reset tracking between actual rebuilds
    _removeListeners();

    // Track performance
    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.startTiming('obx.build');
      _buildCount++;
      ZenMetrics.recordCounterValue('obx.buildCount', _buildCount);
    }

    // Set the tracker to capture Rx values used in the build
    RxTracking.setTracker(_trackValue);

    Widget result;
    try {
      // Build the widget (any Rx values used will call _trackValue)
      result = widget.builder();
      _lastBuildResult = result;
      _needsRebuild = false;
    } finally {
      // Always clear the tracker when done
      RxTracking.clearTracker();

      if (ZenConfig.enablePerformanceMetrics) {
        ZenMetrics.stopTiming('obx.build');
      }
    }

    // Check if tracking was successful
    if (_trackedValues.isEmpty) {
      ZenLogger.logWarning(
          "No tracked values found in Obx widget. Reactivity won't work.");
    }

    return result;
  }
}

/// Alias for [Obx] that follows Zenify naming conventions.
///
/// A widget that automatically rebuilds when any reactive value (`.obs()`)
/// used in the builder changes.
///
/// Example:
/// ```dart
/// final count = 0.obs();
///
/// ZenObserver(() => Text('Count: $count'))
/// ```
///
/// This is identical to [Obx] but uses the `Zen*` naming convention
/// for consistency with other Zenify APIs.
class ZenObserver extends Obx {
  const ZenObserver(super.builder, {super.key});
}
