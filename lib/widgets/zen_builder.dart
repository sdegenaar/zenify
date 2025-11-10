import 'package:flutter/widgets.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart';
import '../di/zen_di.dart';
import 'zen_route.dart';

/// Widget that automatically manages a ZenController's lifecycle
///
/// Features:
/// - Finds existing controller or creates new one
/// - Handles initialization and disposal
/// - Rebuilds on controller updates
/// - Supports scoped controllers
/// - Automatically uses scope from context (e.g., ZenRoute)
///
/// Example:
/// ```dart
/// ZenBuilder<MyController>(
///   create: () => MyController(),
///   builder: (context, controller) {
///     return Text('Count: ${controller.count}');
///   },
/// )
/// ```
class ZenBuilder<T extends ZenController> extends StatefulWidget {
  /// Factory function to create the controller if not found
  final T Function()? create;

  /// Builder function that receives the controller
  final Widget Function(BuildContext context, T controller) builder;

  /// Optional tag for finding/storing the controller
  final String? tag;

  /// Optional scope for the controller
  /// If not provided, uses context scope (from ZenRoute) or root scope
  final ZenScope? scope;

  /// Whether to dispose the controller when this widget is removed
  /// Default: true if controller is created by this widget, false otherwise
  final bool? disposeOnRemove;

  /// Initialization callback called after controller is found/created
  final void Function(T controller)? init;

  /// Error handler for build errors
  final Widget Function(Object error)? onError;

  /// Optional update ID for selective rebuilds
  final String? id;

  const ZenBuilder({
    super.key,
    this.create,
    required this.builder,
    this.tag,
    this.scope,
    this.disposeOnRemove,
    this.init,
    this.onError,
    this.id,
  });

  @override
  State<ZenBuilder<T>> createState() => _ZenBuilderState<T>();
}

class _ZenBuilderState<T extends ZenController> extends State<ZenBuilder<T>> {
  T? _controller;
  bool _isControllerOwner = false;
  bool _shouldDispose = false;
  bool _initialized = false;
  Object? _error;
  ZenScope? _resolvedScope;
  String? _internalTag; // Track internal tag for uniqueness

  @override
  void initState() {
    super.initState();
    // Initialize in didChangeDependencies to have access to context
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize once, or if scope changed
    final contextScope = context.zenScope;
    if (_controller == null || _resolvedScope != contextScope) {
      _initializeController();
    }
  }

  @override
  void didUpdateWidget(ZenBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reinitialize if scope or tag changed
    if (oldWidget.scope != widget.scope || oldWidget.tag != widget.tag) {
      _cleanupController();
      _initializeController();
    }
  }

  void _initializeController() {
    try {
      // Resolve target scope: explicit > context > root
      _resolvedScope = widget.scope ?? context.zenScope ?? Zen.rootScope;

      // Determine if we want a local controller (disposeOnRemove + no tag = local)
      final wantsLocalController =
          widget.disposeOnRemove == true && widget.tag == null;

      // Try to find existing controller (skip if we want a local controller)
      if (!wantsLocalController) {
        _controller = _resolvedScope!.find<T>(tag: widget.tag);
      }

      if (_controller == null) {
        // Controller not found - try to create it
        if (widget.create != null) {
          _controller = widget.create!();
          _isControllerOwner = true;

          // Generate internal tag if disposeOnRemove and no explicit tag
          if (wantsLocalController) {
            _internalTag = '_zen_builder_${hashCode}_${T.toString()}';
          } else {
            _internalTag = widget.tag;
          }

          // Register in DI - add null safety check
          if (_resolvedScope != null) {
            _resolvedScope!.put<T>(_controller!, tag: _internalTag);
          } else {
            throw StateError(
                'Unable to resolve scope for controller registration');
          }

          // Determine if we should dispose on remove
          _shouldDispose = widget.disposeOnRemove ?? true;
        } else {
          throw StateError(
              'Controller of type $T not found and no create function provided');
        }
      } else {
        // Found existing controller
        _isControllerOwner = false;
        _shouldDispose = widget.disposeOnRemove ?? false;
        _internalTag = widget.tag;
      }

      // Call initialization callback if provided
      if (widget.init != null && !_initialized) {
        widget.init!(_controller!);
        _initialized = true;
      }

      // Register listener for controller updates
      final listenerId = widget.id ?? '_zen_builder_$hashCode';
      _controller!.addUpdateListener(listenerId, _onControllerUpdate);

      _error = null;
    } catch (e) {
      _error = e;
      _controller = null;
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _cleanupController() {
    if (_controller != null) {
      // Remove listener
      final listenerId = widget.id ?? '_zen_builder_$hashCode';
      _controller!.removeUpdateListener(listenerId, _onControllerUpdate);

      // Dispose from DI if we own it and should dispose
      if (_shouldDispose && _isControllerOwner && _resolvedScope != null) {
        _resolvedScope!.delete<T>(tag: _internalTag, force: true);
      }

      _controller = null;
      _isControllerOwner = false;
      _shouldDispose = false;
      _initialized = false;
      _internalTag = null;
    }
  }

  @override
  void dispose() {
    _cleanupController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle error state
    if (_error != null) {
      if (widget.onError != null) {
        return widget.onError!(_error!);
      }
      return _buildDefaultError();
    }

    // Handle no controller state
    if (_controller == null) {
      return _buildDefaultError();
    }

    // Try to build with controller
    try {
      return widget.builder(context, _controller!);
    } catch (e) {
      if (widget.onError != null) {
        return widget.onError!(e);
      }
      return _buildDefaultError();
    }
  }

  Widget _buildDefaultError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Use a simple container instead of Icon to avoid Material dependency
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE57373),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Controller Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
            ),
          ],
        ],
      ),
    );
  }
}
