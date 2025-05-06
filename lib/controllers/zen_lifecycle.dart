
// lib/controllers/zen_lifecycle.dart
import 'package:flutter/widgets.dart';
import 'zen_controller.dart';
import 'zen_di.dart';

/// Mixin to add controller lifecycle management to a State class
mixin ZenControllerMixin<T extends StatefulWidget> on State<T> {
  // Set of managed controller references
  final _managedControllers = <_ManagedControllerRef>{};

  /// Use an existing controller and manage its lifecycle with this widget
  void useController<C extends ZenController>({String? tag}) {
    final ref = Zen.ref<C>(tag: tag);

    // Increment use count
    ref.incrementUseCount();

    // Add to managed controllers for cleanup in dispose
    _managedControllers.add(_ManagedControllerRef<C>(tag: tag));
  }

  /// Create a new controller and manage its lifecycle with this widget
  C createController<C extends ZenController>(C Function() factory, {String? tag, bool permanent = false}) {
    // Create controller via factory
    final controller = factory();

    // Register it
    Zen.put<C>(controller, tag: tag, permanent: permanent);

    // Set up lifecycle
    useController<C>(tag: tag);

    return controller;
  }

  @override
  void dispose() {
    // Decrement use count for all managed controllers
    for (final managedRef in _managedControllers) {
      managedRef.decrementUseCount();
    }

    _managedControllers.clear();
    super.dispose();
  }
}

/// Helper class to store controller reference info
class _ManagedControllerRef<C extends ZenController> {
  final String? tag;

  _ManagedControllerRef({this.tag});

  void decrementUseCount() {
    Zen.decrementUseCount<C>(tag: tag);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ManagedControllerRef<C> && other.tag == tag;
  }

  @override
  int get hashCode => C.hashCode ^ (tag?.hashCode ?? 0);
}

/// Helper class for manual controller management when mixins can't be used
class ZenControllerHelper {
  /// Register controller usage and return a cleanup function to call in dispose
  static VoidCallback useController<C extends ZenController>({String? tag}) {
    final ref = Zen.ref<C>(tag: tag);
    ref.incrementUseCount();

    // Return a cleanup function to call in dispose
    return () => Zen.decrementUseCount<C>(tag: tag);
  }

  /// Create and register a controller, returning both the controller and a cleanup function
  static (C controller, VoidCallback cleanup) createController<C extends ZenController>(
      C Function() factory, {
        String? tag,
        bool permanent = false,
      }) {
    // Create the controller
    final controller = factory();

    // Register it
    Zen.put<C>(controller, tag: tag, permanent: permanent);

    // Increment use count
    Zen.incrementUseCount<C>(tag: tag);

    // Return the controller and a cleanup function
    return (controller, () => Zen.decrementUseCount<C>(tag: tag));
  }
}

/// A StatefulWidget that automatically handles controller lifecycle
class ZenControllerWidget<C extends ZenController> extends StatefulWidget {
  final Widget Function(BuildContext context, C controller) builder;
  final C Function() createController;
  final String? tag;
  final bool autoDispose;

  const ZenControllerWidget({
    required this.builder,
    required this.createController,
    this.tag,
    this.autoDispose = true,
    super.key,
  });

  @override
  State<ZenControllerWidget<C>> createState() => _ZenControllerWidgetState<C>();
}

class _ZenControllerWidgetState<C extends ZenController> extends State<ZenControllerWidget<C>> {
  late final C controller;
  late final VoidCallback cleanup;

  @override
  void initState() {
    super.initState();

    // Check if controller already exists
    controller = Zen.find<C>(tag: widget.tag) ?? widget.createController();

    // Register if it doesn't exist
    if (Zen.find<C>(tag: widget.tag) == null) {
      Zen.put<C>(controller, tag: widget.tag);
    }

    // Set up cleanup
    cleanup = ZenControllerHelper.useController<C>(tag: widget.tag);
  }

  @override
  void dispose() {
    cleanup();

    // Auto-dispose if requested and use count is 0
    if (widget.autoDispose && Zen.getUseCount<C>(tag: widget.tag) <= 0) {
      Zen.delete<C>(tag: widget.tag);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, controller);
  }
}