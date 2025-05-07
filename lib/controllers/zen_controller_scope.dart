// lib/controllers/zen_controller_scope.dart
import 'package:flutter/material.dart';
import '../widgets/zen_scope_widget.dart';
import '../controllers/zen_controller.dart';
import '../controllers/zen_di.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';

/// Widget that automatically manages controller lifecycle
/// The controller will be disposed when this widget is removed from the tree
class ZenControllerScope<T extends ZenController> extends StatefulWidget {
  final Widget child;
  final T Function() create;
  final String? tag;
  final bool autoDisposeOnEmptyUseCount;
  final List<dynamic> dependencies;

  const ZenControllerScope({
    required this.child,
    required this.create,
    this.tag,
    this.autoDisposeOnEmptyUseCount = true,
    this.dependencies = const [],
    super.key,
  });

  @override
  State<ZenControllerScope<T>> createState() => _ZenControllerScopeState<T>();
}

class _ZenControllerScopeState<T extends ZenController> extends State<ZenControllerScope<T>> {
  late T controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initController();
  }

  void _initController() {
    // Get the current scope from context or use the root scope
    final scope = ZenScopeWidget.maybeOf(context) ?? Zen.rootScope;

    // Check if controller already exists in this scope or parent scopes
    T? existingController = Zen.find<T>(tag: widget.tag, scope: scope);

    if (existingController != null) {
      controller = existingController;
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Using existing controller $T${widget.tag != null ? ' (${widget.tag})' : ''} from scope: $scope');
      }
    } else {
      // Create and register new controller
      controller = widget.create();
      controller = Zen.put<T>(
        controller,
        tag: widget.tag,
        dependencies: widget.dependencies,
        scope: scope,
      );

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Controller $T${widget.tag != null ? ' (${widget.tag})' : ''} created in scope: $scope');
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

      final scope = ZenScopeWidget.maybeOf(context) ?? Zen.rootScope;
      Zen.delete<T>(tag: widget.tag, scope: scope);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}