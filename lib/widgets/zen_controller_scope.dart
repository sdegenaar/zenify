// lib/zen_state/zen_controller_scope.dart
import 'package:flutter/material.dart';
import '../controllers/zen_controller.dart';
import '../controllers/zen_di.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';

/// Widget that automatically manages controller lifecycle
/// The controller will be disposed when this widget is removed from the tree
class ZenControllerScope<T extends ZenController> extends StatefulWidget {
  final Widget child;
  final T Function() create;
  final String? tag;
  final bool autoDisposeOnEmptyUseCount;

  const ZenControllerScope({
    required this.child,
    required this.create,
    this.tag,
    this.autoDisposeOnEmptyUseCount = true,
    super.key,
  });

  @override
  State<ZenControllerScope<T>> createState() => _ZenControllerScopeState<T>();
}

class _ZenControllerScopeState<T extends ZenController> extends State<ZenControllerScope<T>> {
  late T controller;
  String? controllerKey;

  @override
  void initState() {
    super.initState();

    // Check if controller already exists
    if (widget.tag != null) {
      controller = Zen.find<T>(tag: widget.tag) ?? widget.create();
      controllerKey = widget.tag;
    } else {
      controller = Zen.find<T>() ?? widget.create();
      controllerKey = T.toString();
    }

    // Register the controller if it doesn't exist
    if (Zen.find<T>(tag: widget.tag) == null) {
      controller = Zen.put<T>(widget.create(), tag: widget.tag);

      // Track metrics
      ZenMetrics.recordControllerCreation(T);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Controller $T${widget.tag != null ? ' (${widget.tag})' : ''} created');
      }
    }

    // Increment use count
    Zen.incrementUseCount<T>(tag: widget.tag);
  }

  @override
  void dispose() {
    // Decrement use count
    final useCount = Zen.decrementUseCount<T>(tag: widget.tag);

    // Auto-dispose if needed
    if (widget.autoDisposeOnEmptyUseCount && useCount <= 0) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Auto-disposing controller $T${widget.tag != null ? ' (${widget.tag})' : ''}');
      }

      Zen.delete<T>(tag: widget.tag);

      // Track metrics
      ZenMetrics.recordControllerDisposal(T);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}