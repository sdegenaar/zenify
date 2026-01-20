import 'package:flutter/material.dart';
import 'package:zenify/widgets/widgets.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_exception.dart';
import '../../core/zen_scope.dart';
import '../../di/zen_di.dart';

/// Base class for views with automatic controller binding.
abstract class ZenView<T extends ZenController> extends StatefulWidget {
  const ZenView({super.key});

  /// Optional controller tag
  String? get tag => null;

  /// Optional controller factory
  T Function()? get createController => null;

  /// Optional scope
  ZenScope? get scope => null;

  /// Build the view
  Widget build(BuildContext context);

  @override
  State<ZenView<T>> createState() => _ZenViewState<T>();
}

class _ZenViewState<T extends ZenController> extends State<ZenView<T>> {
  T? _controller;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeController();
      _isInitialized = true;
    }
  }

  void _initializeController() {
    T? instance = _findController();

    if (instance == null && widget.createController != null) {
      instance = widget.createController!();
      _registerController(instance);
    }

    if (instance == null) {
      throw ZenControllerNotFoundException(typeName: T.toString());
    }

    _controller = instance;

    // Register immediately after finding/creating the controller
    _ZenViewRegistry.register<T>(_controller!);
  }

  T? _findController() {
    final targetScope =
        widget.scope ?? (context.mounted ? context.zenScope : null);

    if (targetScope != null) {
      final controller = targetScope.find<T>(tag: widget.tag);
      if (controller != null) return controller;
    }

    return Zen.findOrNull<T>(tag: widget.tag);
  }

  void _registerController(T controller) {
    final targetScope =
        widget.scope ?? (context.mounted ? context.zenScope : null);
    if (targetScope != null) {
      targetScope.put<T>(controller, tag: widget.tag);
    } else {
      Zen.put<T>(controller, tag: widget.tag);
    }
  }

  @override
  void dispose() {
    // Unregister when disposing
    if (_controller != null) {
      _ZenViewRegistry.unregister<T>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Directly build - controller is already registered
    return widget.build(context);
  }
}

/// Simple controller registry
class _ZenViewRegistry {
  static final Map<Type, ZenController> _controllers = {};

  static void register<T extends ZenController>(T controller) {
    _controllers[T] = controller;
  }

  static void unregister<T extends ZenController>() {
    _controllers.remove(T);
  }

  static T? get<T extends ZenController>() {
    return _controllers[T] as T?;
  }
}

/// Controller access extension
extension ZenViewExtension<T extends ZenController> on ZenView<T> {
  T get controller {
    final controller = _ZenViewRegistry.get<T>();
    if (controller != null) {
      return controller;
    }

    // Fallback to DI lookup for edge cases
    final scope = this.scope;
    if (scope != null) {
      final foundController = scope.find<T>(tag: tag);
      if (foundController != null) {
        return foundController;
      }
    }

    final globalController = Zen.findOrNull<T>(tag: tag);
    if (globalController != null) {
      return globalController;
    }

    throw ZenControllerNotFoundException(typeName: T.toString());
  }
}

/// Context extension for nested widgets
extension ZenViewContextExtensions on BuildContext {
  T controller<T extends ZenController>() {
    final controller = _ZenViewRegistry.get<T>();
    if (controller != null) {
      return controller;
    }

    final globalController = Zen.findOrNull<T>();
    if (globalController != null) {
      return globalController;
    }

    throw ZenControllerNotFoundException(typeName: T.toString());
  }
}
