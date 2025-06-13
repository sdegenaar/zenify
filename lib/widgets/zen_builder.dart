import 'package:flutter/widgets.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart' show ZenScope;
import '../di/zen_di.dart';

/// A widget that automatically rebuilds when a controller calls update()
class ZenBuilder<T extends ZenController> extends StatefulWidget {
  /// The builder function that creates the widget tree
  final Widget Function(BuildContext context, T controller) builder;

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

  /// Optional initialization callback
  final void Function(T controller)? init;

  /// Whether to dispose the controller when this widget is disposed
  final bool disposeOnRemove;

  const ZenBuilder({
    required this.builder,
    this.tag,
    this.id,
    this.scope,
    this.autoManage = true,
    this.create,
    this.init,
    this.disposeOnRemove = false,
    super.key,
  }) : assert(disposeOnRemove == false || create != null,
  'disposeOnRemove can only be true when create is provided');

  @override
  State<ZenBuilder> createState() => _ZenBuilderState<T>();
}

class _ZenBuilderState<T extends ZenController> extends State<ZenBuilder<T>> {
  T? _controller;
  bool _locallyCreated = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    try {
      // If scope is provided, use scope-specific lookup
      if (widget.scope != null) {
        // Try to find existing controller in the specific scope
        _controller = widget.scope!.find<T>(tag: widget.tag);

        if (_controller == null && widget.create != null) {
          // Create and register controller in the specific scope
          _controller = widget.create!();
          widget.scope!.put<T>(_controller!, tag: widget.tag);
          _locallyCreated = true;
        }
      } else {
        // Use the Zen API for root scope lookup
        _controller = Zen.findOrNull<T>(tag: widget.tag);

        if (_controller == null && widget.create != null) {
          // Create and register controller using Zen API
          _controller = widget.create!();
          Zen.put<T>(_controller!, tag: widget.tag);
          _locallyCreated = true;
        } else {
          _controller ??= Zen.find<T>(tag: widget.tag);
        }
      }

      // Call init callback if provided
      if (_controller != null && widget.init != null) {
        widget.init!(_controller!);
      }

      // Register for updates using the controller's update system
      if (_controller != null) {
        if (widget.id != null) {
          _controller!.addUpdateListener(widget.id!, _onControllerUpdate);
        } else {
          // Register for all updates from this controller
          _controller!.addUpdateListener('_all_', _onControllerUpdate);
        }
      }
    } catch (e) {
      // Log error and rethrow for proper error handling
      debugPrint('ZenBuilder: Failed to initialize controller of type $T: $e');
      rethrow;
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ZenBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the tag, scope, or create function changed, reinitialize
    if (oldWidget.tag != widget.tag ||
        oldWidget.scope != widget.scope ||
        oldWidget.create != widget.create) {
      _dispose();
      _initializeController();
    }
  }

  void _dispose() {
    if (_controller != null) {
      // Remove the update listener
      if (widget.id != null) {
        _controller!.removeUpdateListener(widget.id!, _onControllerUpdate);
      } else {
        _controller!.removeUpdateListener('_all_', _onControllerUpdate);
      }

      // If this widget created the controller and should dispose it
      if (_locallyCreated && widget.disposeOnRemove) {
        try {
          if (widget.scope != null) {
            widget.scope!.delete<T>(tag: widget.tag, force: true);
          } else {
            Zen.delete<T>(tag: widget.tag, force: true);
          }
        } catch (e) {
          debugPrint('ZenBuilder: Failed to dispose controller: $e');
        }
      }

      _controller = null;
      _locallyCreated = false;
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox.shrink(); // Return empty widget if no controller
    }

    return widget.builder(context, _controller!);
  }
}

/// A simplified builder that provides the controller and automatically rebuilds on update()
class SimpleBuilder<T extends ZenController> extends StatelessWidget {
  /// The builder function that creates the widget tree
  final Widget Function(BuildContext context, T controller) builder;

  /// Optional tag for the controller
  final String? tag;

  /// Optional scope to look for the controller
  final ZenScope? scope;

  /// Optional factory function to create the controller if it doesn't exist
  final T Function()? create;

  /// Optional initialization callback
  final void Function(T controller)? init;

  const SimpleBuilder({
    required this.builder,
    this.tag,
    this.scope,
    this.create,
    this.init,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ZenBuilder<T>(
      builder: builder,
      tag: tag,
      scope: scope,
      create: create,
      init: init,
    );
  }
}

/// A reactive builder that automatically rebuilds when reactive values change
class ZenListener<T extends ZenController> extends StatelessWidget {
  /// The builder function that creates the widget tree
  final Widget Function(BuildContext context, T controller) builder;

  /// Optional tag for the controller
  final String? tag;

  /// Optional scope to look for the controller
  final ZenScope? scope;

  /// Optional factory function to create the controller if it doesn't exist
  final T Function()? create;

  /// Optional initialization callback
  final void Function(T controller)? init;

  const ZenListener({
    required this.builder,
    this.tag,
    this.scope,
    this.create,
    this.init,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ZenBuilder<T>(
      builder: builder,
      tag: tag,
      scope: scope,
      create: create,
      init: init,
    );
  }
}