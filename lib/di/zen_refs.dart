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
    if (scope != null) {
      return scope!.findRequired<T>(tag: tag);
    } else {
      return Zen.find<T>(tag: tag);
    }
  }

  /// Find the instance (returns null if not found)
  @override
  T? findOrNull() {
    if (scope != null) {
      return scope!.find<T>(tag: tag);
    } else {
      return Zen.findOrNull<T>(tag: tag);
    }
  }

  /// Delete the instance
  @override
  bool delete({bool force = false}) {
    if (scope != null) {
      return scope!.delete<T>(tag: tag, force: force);
    } else {
      return Zen.delete<T>(tag: tag, force: force);
    }
  }

  /// Check if instance exists
  @override
  bool exists() {
    if (scope != null) {
      return scope!.exists<T>(tag: tag);
    } else {
      return Zen.findOrNull<T>(tag: tag) != null;
    }
  }

  /// Register an instance
  T put(T instance, {bool? isPermanent}) {
    if (scope != null) {
      return scope!.put<T>(
        instance,
        tag: tag,
        isPermanent: isPermanent ?? false,
      );
    } else {
      return Zen.put<T>(instance, tag: tag, isPermanent: isPermanent);
    }
  }
}

/// Reference to a lazily instantiated dependency
class LazyRef<T> implements Ref<T> {
  @override
  final String? tag;

  @override
  final ZenScope? scope;

  LazyRef({this.tag, this.scope});

  @override
  T find() {
    if (scope != null) {
      return scope!.findRequired<T>(tag: tag);
    } else {
      return Zen.find<T>(tag: tag);
    }
  }

  @override
  T? findOrNull() {
    if (scope != null) {
      return scope!.find<T>(tag: tag);
    } else {
      return Zen.findOrNull<T>(tag: tag);
    }
  }

  @override
  bool delete({bool force = false}) {
    if (scope != null) {
      return scope!.delete<T>(tag: tag, force: force);
    } else {
      return Zen.delete<T>(tag: tag, force: force);
    }
  }

  /// For lazy references, check if dependency is registered or instantiated
  @override
  bool exists() {
    final targetScope = scope ?? Zen.rootScope;
    return targetScope.contains<T>(tag: tag);
  }

  /// Register a lazy factory
  void putLazy(T Function() factory, {bool isPermanent = true}) {
    if (scope != null) {
      scope!.putLazy<T>(factory, tag: tag, isPermanent: isPermanent);
    } else {
      Zen.putLazy<T>(factory, tag: tag, isPermanent: isPermanent);
    }
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
    if (scope != null) {
      return scope!.findRequired<T>(tag: tag);
    } else {
      return Zen.find<T>(tag: tag);
    }
  }

  /// Get the controller if it exists, otherwise null
  @override
  T? findOrNull() {
    if (scope != null) {
      return scope!.find<T>(tag: tag);
    } else {
      return Zen.findOrNull<T>(tag: tag);
    }
  }

  /// Delete the controller
  @override
  bool delete({bool force = false}) {
    if (scope != null) {
      return scope!.delete<T>(tag: tag, force: force);
    } else {
      return Zen.delete<T>(tag: tag, force: force);
    }
  }

  /// Check if controller exists
  @override
  bool exists() {
    if (scope != null) {
      return scope!.exists<T>(tag: tag);
    } else {
      return Zen.findOrNull<T>(tag: tag) != null;
    }
  }

  /// Register a controller instance
  T put(T controller, {bool isPermanent = false}) {
    if (scope != null) {
      return scope!.put<T>(
        controller,
        tag: tag,
        isPermanent: isPermanent,
      );
    } else {
      return Zen.put<T>(controller, tag: tag, isPermanent: isPermanent);
    }
  }
}

/// Extension methods for the ZenController class
extension ZenControllerRefExtension on ZenController {
  /// Create a typed reference to this controller instance
  ControllerRef<T> asRef<T extends ZenController>({
    String? tag,
    bool isPermanent = false,
    ZenScope? scope,
  }) {
    if (this is T) {
      if (scope != null) {
        scope.put<T>(this as T, tag: tag, isPermanent: isPermanent);
      } else {
        Zen.put<T>(this as T, tag: tag, isPermanent: isPermanent);
      }
      return ControllerRef<T>(tag: tag, scope: scope);
    }
    throw Exception('Controller is not of type $T');
  }

  /// Register this controller in the DI container
  T register<T extends ZenController>({
    String? tag,
    bool isPermanent = false,
    ZenScope? scope,
  }) {
    if (this is T) {
      if (scope != null) {
        return scope.put<T>(this as T, tag: tag, isPermanent: isPermanent);
      } else {
        return Zen.put<T>(this as T, tag: tag, isPermanent: isPermanent);
      }
    }
    throw Exception('Controller is not of type $T');
  }
}

/// Extension for any object to be registered in the DI container
extension ZenObjectRefExtension<T> on T {
  /// Register this instance in the DI container
  T put({
    String? tag,
    bool? isPermanent,
    ZenScope? scope,
  }) {
    if (scope != null) {
      return scope.put<T>(
        this,
        tag: tag,
        isPermanent: isPermanent ?? false,
      );
    } else {
      return Zen.put<T>(this, tag: tag, isPermanent: isPermanent);
    }
  }

  /// Create a reference to this instance
  EagerRef<T> asRef({
    String? tag,
    bool? isPermanent,
    ZenScope? scope,
  }) {
    put(tag: tag, isPermanent: isPermanent, scope: scope);
    return EagerRef<T>(tag: tag, scope: scope);
  }
}

/// Convenience functions for creating references
class ZenRef {
  ZenRef._();

  /// Create an eager reference
  static EagerRef<T> eager<T>({String? tag, ZenScope? scope}) {
    return EagerRef<T>(tag: tag, scope: scope);
  }

  /// Create a lazy reference
  static LazyRef<T> lazy<T>({String? tag, ZenScope? scope}) {
    return LazyRef<T>(tag: tag, scope: scope);
  }

  /// Create a controller reference
  static ControllerRef<T> controller<T extends ZenController>(
      {String? tag, ZenScope? scope}) {
    return ControllerRef<T>(tag: tag, scope: scope);
  }
}
