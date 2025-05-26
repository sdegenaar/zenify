// lib/di/zen_refs.dart
import '../controllers/zen_controller.dart';
import '../core/zen_scope.dart';
import 'zen_di.dart';

/// Base interface for all references to dependencies
abstract class Ref<T> {
  String? get tag;
  ZenScope? get scope;

  /// Get the instance (throws if not found)
  T find();

  /// Find the instance (returns null if not found)
  T? findOrNull();

  /// Delete the instance
  bool delete({bool force = false});

  /// Check if instance exists
  bool exists();
}

/// Reference to an eagerly instantiated dependency
class EagerRef<T> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  const EagerRef({this.tag, this.scope});

  /// Get the instance (throws if not found)
  @override
  T find() {
    final result = Zen.find<T>(tag: tag, scope: scope);
    if (result == null) {
      throw Exception('Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found');
    }
    return result;
  }

  /// Find the instance (returns null if not found)
  @override
  T? findOrNull() => Zen.findOrNull<T>(tag: tag, scope: scope);

  /// Delete the instance
  @override
  bool delete({bool force = false}) =>
      Zen.delete<T>(tag: tag, force: force, scope: scope);

  /// Check if instance exists - for eager instances this directly checks
  @override
  bool exists() => findOrNull() != null;

  /// Register a instance
  T put(T instance, {bool permanent = false, List<dynamic> dependencies = const []}) =>
      Zen.put<T>(instance, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
}

/// Reference to a lazily instantiated dependency
class LazyRef<T> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  bool _accessed = false;

  LazyRef({this.tag, this.scope});

  @override
  T find() {
    _accessed = true;
    final result = Zen.find<T>(tag: tag, scope: scope);
    if (result == null) {
      throw Exception('Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found');
    }
    return result;
  }

  @override
  T? findOrNull() {
    final result = Zen.findOrNull<T>(tag: tag, scope: scope);
    if (result != null) {
      _accessed = true;
    }
    return result;
  }

  @override
  bool delete({bool force = false}) {
    return Zen.delete<T>(tag: tag, force: force, scope: scope);
  }

  /// For lazy references, exists() returns true only if the dependency has already been instantiated
  @override
  bool exists() {
    // If we've already accessed it and found it, we can check directly
    if (_accessed) {
      return findOrNull() != null;
    }

    // If we haven't accessed it yet, check if an actual instance exists (not just a factory)
    final targetScope = scope ?? Zen.currentScope;
    return targetScope.hasDependency<T>(tag: tag);
  }

  /// Register a dependency
  T put(T instance, {bool permanent = false, List<dynamic> dependencies = const []}) {
    _accessed = true;
    return Zen.put<T>(instance, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
  }

  /// Register a factory for lazy creation
  void lazyPut(T Function() factory, {bool permanent = false}) {
    Zen.lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
  }
}

/// Special reference for controllers with additional lifecycle features
class ControllerRef<T extends ZenController> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  const ControllerRef({this.tag, this.scope});

  /// Get the controller instance (throws if not found)
  @override
  T find() {
    final result = Zen.find<T>(tag: tag, scope: scope);
    if (result == null) {
      throw Exception('Controller of type $T${tag != null ? ' with tag $tag' : ''} not found');
    }
    return result;
  }

  /// Get the controller if it exists, otherwise null
  @override
  T? findOrNull() {
    return Zen.findOrNull<T>(tag: tag, scope: scope);
  }

  /// Delete the controller
  @override
  bool delete({bool force = false}) {
    return Zen.delete<T>(tag: tag, force: force, scope: scope);
  }

  /// Check if controller exists
  @override
  bool exists() {
    return findOrNull() != null;
  }

  /// Register a controller instance
  T put(T controller, {bool permanent = false, List<dynamic> dependencies = const []}) {
    return Zen.put<T>(controller, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
  }

  /// Increment use count
  int incrementUseCount() => Zen.incrementUseCount<T>(tag: tag, scope: scope);

  /// Decrement use count
  int decrementUseCount() => Zen.decrementUseCount<T>(tag: tag, scope: scope);
}

/// Reference to a lazily instantiated controller
class LazyControllerRef<T extends ZenController> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  bool _accessed = false;

  LazyControllerRef({this.tag, this.scope});

  @override
  T find() {
    _accessed = true;
    final result = Zen.find<T>(tag: tag, scope: scope);
    if (result == null) {
      throw Exception('Controller of type $T${tag != null ? ' with tag $tag' : ''} not found');
    }
    return result;
  }

  @override
  T? findOrNull() {
    final result = Zen.findOrNull<T>(tag: tag, scope: scope);
    if (result != null) {
      _accessed = true;
    }
    return result;
  }

  @override
  bool delete({bool force = false}) {
    return Zen.delete<T>(tag: tag, force: force, scope: scope);
  }

  /// For lazy controllers, exists() returns true only if the controller has already been instantiated
  @override
  bool exists() {
    // If we've already accessed it and found it, we can check directly
    if (_accessed) {
      return findOrNull() != null;
    }

    // If we haven't accessed it yet, check if an actual instance exists (not just a factory)
    final targetScope = scope ?? Zen.currentScope;
    return targetScope.hasDependency<T>(tag: tag);
  }

  /// Register a controller instance
  T put(T controller, {bool permanent = false, List<dynamic> dependencies = const []}) {
    _accessed = true;
    return Zen.put<T>(controller, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
  }

  /// Increment use count
  int incrementUseCount() => Zen.incrementUseCount<T>(tag: tag, scope: scope);

  /// Decrement use count
  int decrementUseCount() => Zen.decrementUseCount<T>(tag: tag, scope: scope);
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
  EagerRef<T> asRef({
    String? tag,
    bool permanent = false,
    ZenScope? scope,
    List<dynamic> dependencies = const [],
  }) {
    Zen.put<T>(this, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return EagerRef<T>(tag: tag, scope: scope);
  }
}