import 'package:flutter/widgets.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart' show ZenScope;
import '../di/zen_di.dart';

/// A widget that automatically rebuilds when a controller calls update()
class ZenBuilder<T extends ZenController> extends StatefulWidget {
  /// The builder function that creates the widget tree
  final Widget Function(T controller) builder;

  /// Optional tag for the controller
  final String? tag;

  /// Optional ID for targeting specific updates
  final String? id;

  /// Optional scope to look for the controller
  final ZenScope? scope;

  /// Whether to auto-increment the controller use count
  final bool autoManage;

  /// Optional factory function to create the controller if it doesn't exist
  final T Function()? create;

  /// Whether to dispose the controller when this widget is disposed
  final bool disposeOnRemove;

  const ZenBuilder({
    required this.builder,
    this.tag,
    this.id,
    this.scope,
    this.autoManage = true,
    this.create,
    this.disposeOnRemove = false,
    super.key,
  }) : assert(disposeOnRemove == false || create != null,
  'disposeOnRemove can only be true when create is provided');

  @override
  State<ZenBuilder> createState() => _ZenBuilderState<T>();
}

class _ZenBuilderState<T extends ZenController> extends State<ZenBuilder<T>> {
  late T _controller;
  bool _initialized = false;
  bool _locallyCreated = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    // Try to find existing controller
    T? existingController = Zen.find<T>(tag: widget.tag, scope: widget.scope);

    if (existingController == null) {
      if (widget.create != null) {
        // Create and register controller using provided factory
        _controller = widget.create!();
        Zen.put<T>(_controller, tag: widget.tag, scope: widget.scope);
        _locallyCreated = true;
      } else {
        // Try to get from registered factory
        _controller = Zen.get<T>(tag: widget.tag, scope: widget.scope);
      }
    } else {
      // Use existing controller
      _controller = existingController;
    }

    // Increment use count if auto-management is enabled
    if (widget.autoManage) {
      Zen.incrementUseCount<T>(tag: widget.tag, scope: widget.scope);
    }

    // Register for updates
    if (widget.id != null) {
      _controller.addUpdateListener(widget.id!, _update);
    } else {
      // Register for all updates from this controller
      _controller.addUpdateListener('_all_', _update);
    }

    _initialized = true;
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Remove the update listener
    if (widget.id != null) {
      _controller.removeUpdateListener(widget.id!, _update);
    } else {
      _controller.removeUpdateListener('_all_', _update);
    }

    // Decrement use count if auto-management is enabled
    if (widget.autoManage) {
      Zen.decrementUseCount<T>(tag: widget.tag, scope: widget.scope);
    }

    // If this widget created the controller and should dispose it
    if (_locallyCreated && widget.disposeOnRemove) {
      Zen.delete<T>(tag: widget.tag, scope: widget.scope);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _initializeController();
    }
    return widget.builder(_controller);
  }
}

/// A simplified builder that provides the controller and automatically rebuilds on update()
class SimpleBuilder<T extends ZenController> extends StatelessWidget {
  /// The builder function that creates the widget tree
  final Widget Function(T controller) builder;

  /// Optional tag for the controller
  final String? tag;

  /// Optional scope to look for the controller
  final ZenScope? scope;

  /// Optional factory function to create the controller if it doesn't exist
  final T Function()? create;

  const SimpleBuilder({
    required this.builder,
    this.tag,
    this.scope,
    this.create,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ZenBuilder<T>(
      builder: builder,
      tag: tag,
      scope: scope,
      create: create,
    );
  }
}