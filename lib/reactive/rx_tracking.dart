// lib/zenify/rx_tracking.dart
import 'package:flutter/foundation.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';

/// Internal tracking system for Rx values
/// This allows Obx widgets to track which Rx values are used in their build methods
class RxTracking {
  RxTracking._(); // Private constructor to prevent instantiation

  // The current tracker function set by Obx widget
  static void Function(ValueNotifier)? _tracker;

  /// Set the current tracker, called by Obx before building
  static void setTracker(void Function(ValueNotifier) trackFunc) {
    _tracker = trackFunc;
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug("RxTracking: Tracker set");
    }
  }

  /// Set a tracker that doesn't log tracking events
  ///
  /// This method is specifically designed for the optimized Obx widget to silently
  /// track dependencies without logging or triggering additional rebuilds.
  /// It's used when we need to collect dependencies but don't want to rebuild
  /// the widget if the output hasn't changed.
  ///
  /// [trackFunc] - Function that will be called when an Rx value is accessed
  static void setTrackerWithoutRebuild(void Function(ValueNotifier) trackFunc) {
    _tracker = trackFunc;
    // No logging here to avoid cluttering logs during dependency collection
  }

  /// Clear the tracker, called by Obx after building
  static void clearTracker() {
    _tracker = null;
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug("RxTracking: Tracker cleared");
    }
  }

  /// Track an Rx value, called by the Rx.call() operator
  static void track(ValueNotifier value) {
    if (_tracker != null) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug("RxTracking: Tracking ${value.runtimeType}");
      }
      _tracker!(value);
    } else {
      if (ZenConfig.enableDebugLogs) {
        //ZenLogger.logDebug("RxTracking: No tracker available for ${value.runtimeType}");
      }
    }
  }
}