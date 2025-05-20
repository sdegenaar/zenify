// lib/controllers/zen_controller_scope.dart
import 'package:flutter/material.dart';
import '../core/zen_scope.dart';
import '../di/di.dart';
import '../widgets/zen_scope_widget.dart';
import '../controllers/zen_controller.dart';
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
  final bool permanent;
  final ZenScope? scope; // Add explicit scope parameter

  const ZenControllerScope({
    required this.child,
    required this.create,
    this.tag,
    this.autoDisposeOnEmptyUseCount = true,
    this.dependencies = const [],
    this.permanent = false,
    this.scope, // Allow passing a specific scope
    super.key,
  });

  @override
  State<ZenControllerScope<T>> createState() => _ZenControllerScopeState<T>();
}

class _ZenControllerScopeState<T extends ZenController> extends State<ZenControllerScope<T>> {
  late T controller;
  // Store the scope reference when we initialize
  late ZenScope _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initController();
  }

  void _initController() {
    // Use provided scope or get from context or use root scope
    _scope = widget.scope ?? ZenScopeWidget.maybeOf(context) ?? Zen.rootScope;

    // Check if controller already exists in this scope
    T? existingController = Zen.find<T>(tag: widget.tag, scope: _scope);

    if (existingController != null) {
      controller = existingController;
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Using existing controller $T${widget.tag != null ? ' (${widget.tag})' : ''} from scope: $_scope');
      }
    } else {
      // Create and register new controller
      controller = widget.create();
      controller = Zen.put<T>(
        controller,
        tag: widget.tag,
        dependencies: widget.dependencies,
        scope: _scope,
        permanent: widget.permanent,
      );

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Controller $T${widget.tag != null ? ' (${widget.tag})' : ''} created in scope: $_scope');
      }
    }

    // Increment use count
    Zen.incrementUseCount<T>(tag: widget.tag, scope: _scope);
  }

  @override
  void dispose() {
    // Decrement use count
    final useCount = Zen.decrementUseCount<T>(tag: widget.tag, scope: _scope);

    // Auto-dispose if needed and not permanent
    if (widget.autoDisposeOnEmptyUseCount && useCount <= 0 && !widget.permanent) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Auto-disposing controller $T${widget.tag != null ? ' (${widget.tag})' : ''}');
      }

      // Use stored scope reference
      Zen.delete<T>(tag: widget.tag, scope: _scope);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we have a specific scope, use ZenScopeWidget to provide it to children
    if (widget.scope != null) {
      return ZenScopeWidget(
        scope: _scope,
        child: widget.child,
      );
    }
    return widget.child;
  }
}