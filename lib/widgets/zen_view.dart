// lib/widgets/zen_view.dart

import 'package:flutter/material.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart';
import '../di/zen_di.dart';
import 'zen_builder.dart';

/// Base class for views with automatic controller binding
abstract class ZenView<T extends ZenController> extends StatefulWidget {
  const ZenView({super.key});

  /// Get the controller tag (optional)
  String? get tag => null;

  /// Create a controller instance if it doesn't exist
  T Function()? get createController => null;

  /// Get the scope for controller resolution (optional)
  ZenScope? get scope => null;

  /// Whether to dispose the controller when this view is removed
  bool get disposeControllerOnRemove => false;

  /// Build the view with the controller
  Widget build(BuildContext context);

  @override
  StatefulElement createElement() {
    return _ZenViewElement(this);
  }

  @override
  State<ZenView<T>> createState() => _ZenViewState<T>();
}

/// State class for ZenView that handles controller lifecycle
class _ZenViewState<T extends ZenController> extends State<ZenView<T>> {
  /// Controller instance
  late T _controller;

  /// Flag to track if controller was created by this view
  bool _didCreateController = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    // First try to find an existing controller
    T? instance = Zen.find<T>(tag: widget.tag, scope: widget.scope);

    // If not found but we have a createController function, use it
    if (instance == null && widget.createController != null) {
      instance = widget.createController!();
      Zen.put<T>(instance, tag: widget.tag, scope: widget.scope);
      _didCreateController = true;
    }

    // If still null, try to get from DI or throw exception
    instance ??= Zen.get<T>(tag: widget.tag, scope: widget.scope);

    _controller = instance;
  }

  @override
  void dispose() {
    // Dispose controller if created by this view and disposal is enabled
    if (_didCreateController && widget.disposeControllerOnRemove) {
      Zen.delete<T>(tag: widget.tag, scope: widget.scope);
    }
    super.dispose();
  }

  /// Get the controller - can be accessed by the widget through the state
  T get controller => _controller;

  @override
  Widget build(BuildContext context) {
    // Create a new BuildContext that provides the controller
    return _ControllerProvider<T>(
      controller: _controller,
      child: Builder(
        builder: (context) => widget.build(context),
      ),
    );
  }
}

/// InheritedWidget that provides the controller to the widget tree
class _ControllerProvider<T extends ZenController> extends InheritedWidget {
  final T controller;

  const _ControllerProvider({
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ControllerProvider<T> oldWidget) {
    return controller != oldWidget.controller;
  }

  /// Find the controller in the widget tree
  static T? maybeOf<T extends ZenController>(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<_ControllerProvider<T>>();
    return provider?.controller;
  }

  /// Find the controller in the widget tree, throws if not found
  static T of<T extends ZenController>(BuildContext context) {
    final controller = maybeOf<T>(context);
    if (controller == null) {
      throw Exception('No controller provider of type $T found in the widget tree');
    }
    return controller;
  }
}

/// Extension on ZenView to access the controller
extension ZenViewExtension<T extends ZenController> on ZenView<T> {
  /// Getter for the controller
  /// This is used internally and provides access to the controller
  /// in the build method.
  T get controller {
    // Check if the current context is set (during build)
    if (_ZenController._currentContext != null) {
      return _ControllerProvider.of<T>(_ZenController._currentContext!);
    }

    // Fallback - check if we can get it from the registry
    // This makes the code more testable
    final controller = Zen.find<T>(tag: tag, scope: scope);
    if (controller != null) {
      return controller;
    }

    throw Exception('Controller can only be accessed during the build method or after being registered');
  }
}

/// Helper class for managing current context
class _ZenController {
  static BuildContext? _currentContext;

  static void setCurrent(BuildContext? context) {
    _currentContext = context;
  }
}

/// Widget that provides reactive updates when the controller changes
class ZenViewReactive<T extends ZenController> extends StatelessWidget {
  /// Builder function that receives the controller
  final Widget Function(BuildContext, T) buildWithController;

  /// Controller tag
  final String? tag;

  /// Controller creation function
  final T Function()? createController;

  /// Scope for controller resolution
  final ZenScope? scope;

  /// Whether to dispose the controller when this view is removed
  final bool disposeControllerOnRemove;

  /// Constructor for direct usage
  const ZenViewReactive({
    super.key,
    required this.buildWithController,
    this.tag,
    this.createController,
    this.scope,
    this.disposeControllerOnRemove = false,
  }) : assert(disposeControllerOnRemove == false || createController != null,
  'disposeControllerOnRemove can only be true when createController is provided');

  @override
  Widget build(BuildContext context) {
    return ZenBuilder<T>(
      tag: tag,
      create: createController,
      scope: scope,
      disposeOnRemove: disposeControllerOnRemove,
      builder: (controller) => buildWithController(context, controller),
    );
  }
}

/// Base class for creating custom ZenViewReactive widgets through subclassing
abstract class ZenViewReactiveBase<T extends ZenController> extends StatelessWidget {
  const ZenViewReactiveBase({super.key});

  /// Get the controller tag (optional)
  String? get tag => null;

  /// Create a controller instance if it doesn't exist
  T Function()? get createController => null;

  /// Get scope for the controller
  ZenScope? get scope => null;

  /// Whether to dispose the controller when this view is removed
  bool get disposeControllerOnRemove => false;

  /// Build method that will receive the controller - must be implemented
  Widget buildWithController(BuildContext context, T controller);

  @override
  Widget build(BuildContext context) {
    return ZenBuilder<T>(
      tag: tag,
      create: createController,
      scope: scope,
      disposeOnRemove: disposeControllerOnRemove && createController != null,
      builder: (controller) => buildWithController(context, controller),
    );
  }
}

/// Method channel for BuildContext-based controller access
extension ZenBuilderExtensions on BuildContext {
  /// Get the controller from the widget tree
  T controller<T extends ZenController>() {
    final controller = _ControllerProvider.maybeOf<T>(this);
    if (controller != null) {
      return controller;
    }

    // Fall back to finding ancestor state
    final state = findAncestorStateOfType<_ZenViewState<T>>();
    if (state != null) {
      return state.controller;
    }

    throw Exception('No controller of type $T found in the widget tree');
  }
}

/// Custom element that captures build context
class _ZenViewElement extends StatefulElement {
  _ZenViewElement(ZenView widget) : super(widget);

  @override
  Widget build() {
    // Set the current context before building
    _ZenController.setCurrent(this);
    try {
      return super.build();
    } finally {
      // Clear the context after building
      _ZenController.setCurrent(null);
    }
  }
}