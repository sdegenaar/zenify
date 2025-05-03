// lib/reactive/rx_bridge.dart

import 'rx_value.dart';
import 'rx_notifier.dart';
import 'rx_common.dart';

/// Bridge extensions for converting between Rx and RxNotifier
extension RxToRxNotifierBridge<T> on Rx<T> {
  /// Create an RxNotifier linked to this Rx value
  RxNotifier<T> asGlobal({String? debugName}) {
    final rxNotifier = RxNotifier<T>(value);

    // Listen to changes in this Rx and update RxNotifier
    addListener(() {
      rxNotifier.value = value;
    });

    // Create provider if debug name is provided
    if (debugName != null) {
      rxNotifier.createProvider(debugName: debugName);
    }

    return rxNotifier;
  }
}

/// Bridge extension for RxNotifier to connect to local Rx values
extension RxNotifierToRxBridge<T> on RxNotifier<T> {
  /// Bind this RxNotifier to update a local Rx value
  void bindToRx(Rx<T> rx) {
    // Correct listener type for StateNotifier
    final listener = (T value) {
      rx.value = value;
    };

    // Update immediately and add listener
    rx.value = value;
    addListener(listener);
  }
}