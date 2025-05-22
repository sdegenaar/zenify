
// lib/di/zen_refs.dart
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart';
import 'zen_di.dart';

/// Base interface for references
abstract class Ref<T> {
  String? get tag;
  ZenScope? get scope;

  /// Get the instance (throws if not found)
  T get();

  /// Find the instance (returns null if not found)
  T? find();

  /// Delete the instance
  bool delete({bool force = false});

  /// Check if instance exists
  bool exists();
}

/// Type-safe reference to a controller
class ControllerRef<T extends ZenController> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  const ControllerRef({this.tag, this.scope});

  /// Get the controller instance (throws if not found)
  @override
  T get() {
    return Zen.get<T>(tag: tag, scope: scope);
  }

  /// Get the controller if it exists, otherwise null
  @override
  T? find() {
    return Zen.find<T>(tag: tag, scope: scope);
  }

  /// Delete the controller
  @override
  bool delete({bool force = false}) {
    return Zen.delete<T>(tag: tag, force: force, scope: scope);
  }

  /// Check if controller exists
  @override
  bool exists() {
    return find() != null;
  }

  /// Register a controller instance
  T put(T controller, {bool permanent = false, List<dynamic> dependencies = const []}) {
    return Zen.put<T>(controller, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
  }

  /// Register a factory for lazy creation
  void lazyPut(T Function() factory, {bool permanent = false}) {
    Zen.lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
  }

  /// Increment use count
  int incrementUseCount() => Zen.incrementUseCount<T>(tag: tag, scope: scope);

  /// Decrement use count
  int decrementUseCount() => Zen.decrementUseCount<T>(tag: tag, scope: scope);
}

/// Type-safe reference to a lazy controller that hasn't been initialized yet
/// Special reference for lazy controllers
class LazyControllerRef<T extends ZenController> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  bool _accessed = false;

  LazyControllerRef({this.tag, this.scope});

  @override
  T get() {
    _accessed = true;
    return Zen.get<T>(tag: tag, scope: scope);
  }

  @override
  T? find() {
    final result = Zen.find<T>(tag: tag, scope: scope);
    if (result != null) {
      _accessed = true;
    }
    return result;
  }

  @override
  bool delete({bool force = false}) {
    return Zen.delete<T>(tag: tag, force: force, scope: scope);
  }

  @override
  bool exists() {
    // If we've already accessed this lazy reference, check the actual existence
    if (_accessed) {
      return find() != null;
    }

    // Important: For LazyControllerRef, exists() should only return true if
    // the controller has already been instantiated, not just registered as a factory

    // For the scope-specific implementation, we need to check:
    // 1. If there's a specific scope, use that scope's hasDependency method
    // 2. Otherwise use the current scope's hasDependency method

    final targetScope = scope ?? Zen.currentScope;
    return targetScope.hasDependency<T>(tag: tag);
  }

  /// Register a controller instance
  T put(T controller, {bool permanent = false, List<dynamic> dependencies = const []}) {
    _accessed = true;
    return Zen.put<T>(controller, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
  }

  /// Register a factory for lazy creation
  void lazyPut(T Function() factory, {bool permanent = false}) {
    Zen.lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
  }

  /// Increment use count
  int incrementUseCount() => Zen.incrementUseCount<T>(tag: tag, scope: scope);

  /// Decrement use count
  int decrementUseCount() => Zen.decrementUseCount<T>(tag: tag, scope: scope);
}

/// Type-safe reference to any dependency (not just controllers)
class DependencyRef<T> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  const DependencyRef({this.tag, this.scope});

  /// Get the dependency instance (throws if not found)
  @override
  T get() => Zen.get<T>(tag: tag, scope: scope);

  /// Get the dependency if it exists, otherwise null
  @override
  T? find() => Zen.find<T>(tag: tag, scope: scope);

  /// Delete the dependency
  @override
  bool delete({bool force = false}) =>
      Zen.delete<T>(tag: tag, force: force, scope: scope);

  /// Check if dependency exists
  @override
  bool exists() => find() != null;

  /// Register a dependency instance
  T put(T instance, {bool permanent = false, List<dynamic> dependencies = const []}) =>
      Zen.put<T>(instance, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);

  /// Register a factory for lazy creation
  void lazyPut(T Function() factory, {bool permanent = false}) =>
      Zen.lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
}

/// Extension methods for the ZenController class
extension ZenControllerExtension on ZenController {
  /// Create a typed reference to this controller instance
  ControllerRef<T> asRef<T extends ZenController>({
    String? tag,
    bool permanent = false,
    ZenScope? scope,
    List<dynamic> dependencies = const [],
  }) {
    if (this is T) {
      Zen.put<T>(
        this as T,
        tag: tag,
        permanent: permanent,
        scope: scope,
        dependencies: dependencies,
      );
      return ControllerRef<T>(tag: tag, scope: scope);
    }
    throw Exception('Controller is not of type $T');
  }

  /// Register this controller in the DI container
  T register<T extends ZenController>({
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    if (this is T) {
      return Zen.put<T>(this as T, tag: tag, permanent: permanent, scope: scope);
    }
    throw Exception('Controller is not of type $T');
  }
}

/// Extension for any object to be registered in the DI container
extension ZenObjectExtension<T> on T {
  /// Register this instance in the DI container
  T put({
    String? tag,
    bool permanent = false,
    ZenScope? scope,
    List<dynamic> dependencies = const [],
  }) {
    return Zen.put<T>(this, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
  }

  /// Create a reference to this instance
  DependencyRef<T> asRef({
    String? tag,
    bool permanent = false,
    ZenScope? scope,
    List<dynamic> dependencies = const [],
  }) {
    Zen.put<T>(this, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return DependencyRef<T>(tag: tag, scope: scope);
  }
}