// lib/di/zen_refs.dart
import 'package:zenify/di/zen_di.dart';

import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart';

/// Type-safe reference to a controller
/// Enhances type safety and editor autocomplete when working with controllers
class ControllerRef<T extends ZenController> {
  final String? tag;
  final ZenScope? scope;

  const ControllerRef({this.tag, this.scope});

  /// Get the controller instance
  /// Creates the controller if it doesn't exist and a factory is registered
  T get() => Zen.get<T>(tag: tag, scope: scope);

  /// Get the controller if it exists, otherwise null
  T? find() => Zen.find<T>(tag: tag, scope: scope);

  /// Register a controller instance
  T put(T controller, {bool permanent = false}) =>
      Zen.put<T>(controller, tag: tag, permanent: permanent, scope: scope);

  /// Register a factory for lazy creation
  void lazyPut(T Function() factory, {bool permanent = false}) =>
      Zen.lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);

  /// Delete the controller
  bool delete({bool force = false}) =>
      Zen.delete<T>(tag: tag, force: force, scope: scope);

  /// Check if controller exists
  bool exists() => find() != null;

  /// Increment use count
  int incrementUseCount() => Zen.incrementUseCount<T>(tag: tag, scope: scope);

  /// Decrement use count
  int decrementUseCount() => Zen.decrementUseCount<T>(tag: tag, scope: scope);
}

/// Type-safe reference to any dependency (not just controllers)
class DependencyRef<T> {
  final String? tag;
  final ZenScope? scope;

  const DependencyRef({this.tag, this.scope});

  /// Get the dependency instance
  /// Creates the dependency if it doesn't exist and a factory is registered
  T get({T Function()? factory}) =>
      Zen.getDependency<T>(tag: tag, scope: scope, factory: factory);

  /// Get the dependency if it exists, otherwise null
  T? find() => Zen.findDependency<T>(tag: tag, scope: scope);

  /// Register a dependency instance
  T put(T instance, {bool permanent = false}) =>
      Zen.putDependency<T>(instance, tag: tag, permanent: permanent, scope: scope);

  /// Register a factory for lazy creation
  void lazyPut(T Function() factory, {bool permanent = false}) =>
      Zen.lazyPutDependency<T>(factory, tag: tag, permanent: permanent, scope: scope);

  /// Delete the dependency
  bool delete({bool force = false}) =>
      Zen.deleteDependency<T>(tag: tag, force: force, scope: scope);

  /// Check if dependency exists
  bool exists() => find() != null;
}

/// Extension methods for the ZenController class
extension ZenControllerExtension on ZenController {
  /// Create a typed reference to this controller instance
  ControllerRef<T> createRef<T extends ZenController>({
    String? tag,
    bool permanent = false,
    ZenScope? scope,
    List<dynamic> dependencies = const [],
  }) {
    if (this is T) {
      return Zen.putRef<T>(
        this as T,
        tag: tag,
        permanent: permanent,
        scope: scope,
        dependencies: dependencies,
      );
    }
    throw Exception('Controller is not of type $T');
  }
}