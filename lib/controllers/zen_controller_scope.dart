// lib/controllers/zen_controller_scope.dart
import 'package:flutter/material.dart';
import '../core/zen_scope.dart';
import '../di/zen_di.dart';
import '../widgets/zen_scope_widget.dart';
import 'zen_controller.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';

/// A widget that creates and manages a controller's lifecycle.
///
/// ZenControllerScope automatically creates a controller if it doesn't exist,
/// registers it with the appropriate scope, and disposes it when the widget
/// is removed from the tree (unless [permanent] is set to true).
class ZenControllerScope<T extends ZenController> extends StatefulWidget {
  /// Function to create the controller
  final T Function() create;

  /// The child widget
  final Widget child;

  /// Optional tag for the controller
  final String? tag;

  /// Whether the controller should be permanently registered
  final bool permanent;

  /// Explicit scope to use (if null, will use nearest scope from context)
  final ZenScope? scope;

  /// Optional list of dependencies for this controller
  final List<dynamic> dependencies;

  const ZenControllerScope({
    required this.create,
    required this.child,
    this.tag,
    this.permanent = false,
    this.scope,
    this.dependencies = const [],
    super.key,
  });

  @override
  State<ZenControllerScope> createState() => _ZenControllerScopeState<T>();
}

class _ZenControllerScopeState<T extends ZenController> extends State<ZenControllerScope<T>> {
  late T controller;
  late ZenScope _effectiveScope;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Wait for didChangeDependencies for context access
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initController();
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(ZenControllerScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if we need to recreate the controller
    if (widget.key != oldWidget.key) {
      _disposeController(oldWidget);
      _initController();
    }
  }

  void _disposeController(ZenControllerScope<T> widget) {
    if (!widget.permanent) {
      Zen.delete<T>(tag: widget.tag, scope: _effectiveScope);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Disposed controller $T${widget.tag != null ? ' (${widget.tag})' : ''}');
      }
    }
  }

  void _initController() {
    // Get the appropriate scope - first try widget's explicit scope, then context, then root
    _effectiveScope = widget.scope ??
        ZenScopeWidget.maybeOf(context) ??
        Zen.rootScope;

    // First check if controller already exists
    final existingController = Zen.findOrNull<T>(tag: widget.tag, scope: _effectiveScope);

    if (existingController != null) {
      controller = existingController;

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Using existing controller $T${widget.tag != null ? ' (${widget.tag})' : ''} from scope: $_effectiveScope');
      }
    } else {
      // Create and register a new controller
      controller = widget.create();

      // Register with Zen
      Zen.put<T>(
        controller,
        tag: widget.tag,
        permanent: widget.permanent,
        dependencies: widget.dependencies,
        scope: _effectiveScope,
      );

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Created new controller $T${widget.tag != null ? ' (${widget.tag})' : ''} in scope: $_effectiveScope');
      }
    }
  }

  @override
  void dispose() {
    _disposeController(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we have an explicit scope, provide it to children
    if (widget.scope != null) {
      return ZenScopeWidget(
        scope: widget.scope,
        child: widget.child,
      );
    }

    // Otherwise just return the child
    return widget.child;
  }
}