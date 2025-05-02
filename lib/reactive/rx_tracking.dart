// lib/zen_state/rx_tracking.dart
import 'package:flutter/foundation.dart';

/// Internal tracking system for Rx values
/// This allows Obx widgets to track which Rx values are used in their build methods
class RxTracking {
  RxTracking._(); // Private constructor to prevent instantiation

  // The current tracker function set by Obx widget
  static void Function(ValueNotifier)? _tracker;

  /// Set the current tracker, called by Obx before building
  static void setTracker(void Function(ValueNotifier) trackFunc) {
    _tracker = trackFunc;
    print("RxTracking: Tracker set"); // Debug logging
  }

  /// Clear the tracker, called by Obx after building
  static void clearTracker() {
    _tracker = null;
    print("RxTracking: Tracker cleared"); // Debug logging
  }

  /// Track an Rx value, called by the Rx.call() operator
  static void track(ValueNotifier value) {
    if (_tracker != null) {
      print("RxTracking: Tracking ${value.runtimeType}"); // Debug logging
      _tracker!(value);
    } else {
      print("RxTracking: No tracker available for ${value.runtimeType}"); // Debug when failing
    }
  }
}