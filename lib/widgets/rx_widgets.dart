import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../reactive/rx_tracking.dart';

/// A widget that automatically rebuilds when any Rx value used in the builder changes
class Obx extends StatefulWidget {
  final Widget Function() builder;

  const Obx(this.builder, {super.key});

  @override
  State<Obx> createState() => _ObxState();
}

class _ObxState extends State<Obx> {
  // Track ValueNotifiers (Rx values) accessed in the build method
  final Set<ValueNotifier> _trackedValues = {};

  @override
  void initState() {
    super.initState();
    // For debugging
    print("Obx widget initialized");
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
      setState(() {
        // For debugging
        print("Obx widget rebuilding on state change");
      });
    }
  }

  // Add a value to track for reactivity
  void _trackValue(ValueNotifier value) {
    if (!_trackedValues.contains(value)) {
      _trackedValues.add(value);
      value.addListener(_onValueChanged);
      // For debugging
      print("Tracking a new value: ${value.runtimeType}");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reset tracking between builds to prevent stale listeners
    for (final value in _trackedValues) {
      value.removeListener(_onValueChanged);
    }
    _trackedValues.clear();

    // Set the tracker to capture Rx values used in the build
    RxTracking.setTracker(_trackValue);

    Widget result;
    try {
      // Build the widget (any Rx values used will call _trackValue)
      result = widget.builder();
    } finally {
      // Always clear the tracker when done
      RxTracking.clearTracker();
    }

    // Manually track all Rx objects in the controller for Level 1
    // This is a workaround to ensure reactivity
    if (_trackedValues.isEmpty) {
      print("WARNING: No tracked values found in Obx widget. Reactivity won't work.");
    }

    return result;
  }
}

/// For integration with Riverpod - a Consumer wrapper
class RiverpodObx extends ConsumerWidget {
  final Widget Function(WidgetRef ref) builder;

  const RiverpodObx(this.builder, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return builder(ref);
  }
}