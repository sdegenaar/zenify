import 'package:flutter/material.dart';
import '../../reactive/core/rx_tracking.dart';
import '../../core/zen_logger.dart';
import '../../core/zen_config.dart';
import '../../core/zen_metrics.dart';

/// The canonical Zenify reactive observer widget.
///
/// Automatically rebuilds when any reactive value (`.obs()`) accessed inside
/// [builder] changes. Tracks dependencies automatically — no manual subscription
/// management needed.
///
/// Example:
/// ```dart
/// final count = 0.obs();
///
/// ZenObserver(() => Text('Count: ${count.value}'))
/// ```
///
/// For multi-controller granular rebuilds use [ZenBuilder] instead.
/// [ZenObserver] is a deprecated alias kept for GetX migration compatibility.
class ZenObserver extends StatefulWidget {
  final Widget Function() builder;

  /// When `true`, suppresses the "No tracked values" warning that fires when
  /// the builder contains only null-guarded Rx accesses (e.g. `ctrl?.value`).
  ///
  /// Use this in widgets where the controller may legitimately be null during
  /// an early build (e.g. a ZenProvider is still initialising).
  final bool suppressEmptyWarning;

  const ZenObserver(this.builder, {super.key, this.suppressEmptyWarning = false});

  @override
  State<ZenObserver> createState() => _ZenObserverState();
}

class _ZenObserverState extends State<ZenObserver> {
  // Track ValueNotifiers (Rx values) accessed in the build method
  final Set<ValueNotifier> _trackedValues = {};

  // For performance optimization
  bool _needsRebuild = false;
  Widget? _lastBuildResult;
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    ZenLogger.logRxTracking("ZenObserver widget initialized");
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

      ZenLogger.logRxTracking("ZenObserver widget scheduling rebuild");

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
  // coverage:ignore-start
  void _trackValueWithoutRebuild(ValueNotifier value) {
    if (!_trackedValues.contains(value)) {
      _trackedValues.add(value);
      value.addListener(_onValueChanged);

      ZenLogger.logRxTracking("Silently tracking value: ${value.runtimeType}");
    }
  }
  // coverage:ignore-end

  @override
  void didUpdateWidget(covariant ZenObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent rebuilds this widget, we must rebuild our child
    // to capture any scope or closure changes.
    _needsRebuild = true;
  }

  @override
  Widget build(BuildContext context) {
    // If no rebuild needed and we have a previous result, reuse it
    // coverage:ignore-start
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
    // coverage:ignore-end

    // Reset tracking between actual rebuilds
    _removeListeners();

    // Track performance
    if (ZenConfig.enablePerformanceMetrics) {
      ZenMetrics.startTiming('obx.build'); // coverage:ignore-line
      _buildCount++; // coverage:ignore-line
      ZenMetrics.recordCounterValue(
          'obx.buildCount', _buildCount); // coverage:ignore-line
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
        ZenMetrics.stopTiming('obx.build'); // coverage:ignore-line
      }
    }

    // Check if tracking was successful.
    // Suppress the warning when the caller has explicitly opted out —
    // this is common for widgets where the reactive source (e.g. a
    // ZenController) may be null during the first build frame because
    // the ZenProvider is still registering its module. The null-safe
    // `?.value` idiom silently skips tracking in that case, but the widget
    // will still react correctly once the controller is available and a
    // real Rx value is accessed on the next rebuild.
    if (_trackedValues.isEmpty && !widget.suppressEmptyWarning) {
      ZenLogger.logWarning(// coverage:ignore-line
          "No tracked values found in ZenObserver widget. Reactivity won't work.");
    }

    return result;
  }
}


