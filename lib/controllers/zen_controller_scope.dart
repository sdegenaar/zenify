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
  ZenScope? _storedScope; // Store the scope reference when stable
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Wait for didChangeDependencies for context access
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ Store the scope reference while the widget tree is stable
    _storedScope = widget.scope ?? ZenScopeWidget.maybeOf(context) ?? Zen.rootScope;

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
      // Use the stored scope instead of calling _getCurrentScope()
      final scopeToUse = widget.scope ?? _storedScope ?? Zen.rootScope;

      try {
        scopeToUse.delete<T>(tag: widget.tag, force: true);

        if (ZenConfig.enableDebugLogs) {
          ZenLogger.logDebug('Disposed controller $T${widget.tag != null ? ' (${widget.tag})' : ''}');
        }
      } catch (e) {
        if (ZenConfig.enableDebugLogs) {
          ZenLogger.logError('Error disposing controller $T: $e');
        }
      }
    }
  }

  ZenScope _getCurrentScope() {
    // Use stored scope when available, fallback to lookup only if necessary
    return _storedScope ??
        widget.scope ??
        ZenScopeWidget.maybeOf(context) ??
        Zen.rootScope;
  }

  void _initController() {
    // Get the appropriate scope
    _effectiveScope = _getCurrentScope();

    // First check if controller already exists
    T? existingController;

    if (widget.scope != null) {
      // Check in specific scope only (not hierarchy)
      existingController = widget.scope!.findInThisScope<T>(tag: widget.tag);
    } else {
      // Check in current scope hierarchy
      existingController = _effectiveScope.find<T>(tag: widget.tag);
    }

    if (existingController != null) {
      controller = existingController;

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Using existing controller $T${widget.tag != null ? ' (${widget.tag})' : ''} from scope: ${_effectiveScope.name ?? _effectiveScope.id}');
      }
    } else {
      // Create and register a new controller
      controller = widget.create();

      // Register with appropriate scope
      if (widget.scope != null) {
        // Register in specific scope
        widget.scope!.put<T>(
          controller,
          tag: widget.tag,
          permanent: widget.permanent,
        );
      } else {
        // Register in current effective scope
        _effectiveScope.put<T>(
          controller,
          tag: widget.tag,
          permanent: widget.permanent,
        );
      }

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Created and registered controller $T${widget.tag != null ? ' (${widget.tag})' : ''} in scope: ${_effectiveScope.name ?? _effectiveScope.id}');
      }
    }
  }

  @override
  void dispose() {
    // Call dispose using the current widget configuration
    _disposeController(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}