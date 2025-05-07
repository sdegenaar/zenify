// lib/controllers/zen_di.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';
import 'zen_controller.dart';
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
  int incrementUseCount() => Zen.incrementUseCount<T>(tag: tag);

  /// Decrement use count
  int decrementUseCount() => Zen.decrementUseCount<T>(tag: tag);
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

/// Dependency injection container with hierarchical scope support
class Zen {
  Zen._(); // Private constructor

  // Will be initialized with the app's root container
  static late ProviderContainer _container;
  // Root scope for the application
  static final ZenScope _rootScope = ZenScope(name: 'RootScope');

  // Legacy maps for backward compatibility
  static final Map<Type, ZenController> _controllers = {};
  static final Map<String, ZenController> _taggedControllers = {};
  static final Map<Type, int> _typeUseCount = {}; // Use count for Type keys
  static final Map<String, int> _tagUseCount = {}; // Use count for String keys
  static final Map<Type, Function> _typeFactories = {}; // For lazy instantiation by Type
  static final Map<String, Function> _taggedFactories = {}; // For lazy instantiation by tag
  static _ZenAppLifecycleObserver? _lifecycleObserver;

  // Map for tracking dependencies between controllers (for cycle detection)
  static final Map<dynamic, Set<dynamic>> _dependencyGraph = {};

  // Initialize with the app's root container
  static void init(ProviderContainer container) {
    _container = container;

    if (ZenConfig.enableAutoDispose) {
      _startAutoDisposeTimer();
    }

    // Set up app lifecycle observer
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _ZenAppLifecycleObserver();
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Zen lifecycle observer initialized');
      }
    }
  }

  /// Get the global root scope
  static ZenScope get rootScope => _rootScope;

  /// Create a new scope with optional parent
  static ZenScope createScope({ZenScope? parent, String? name, String? id}) {
    return ZenScope(
      parent: parent ?? _rootScope,
      name: name,
      id: id,
    );
  }

  /// Register a controller instance
  static T put<T extends ZenController>(
      T controller, {
        String? tag,
        bool permanent = false,
        List<dynamic> dependencies = const [],
        ZenScope? scope,
      }) {
    // Use specified scope or root scope
    final targetScope = scope ?? _rootScope;

    // Register in the scope system (using public register method instead of internal)
    targetScope.register<T>(
      controller,
      tag: tag,
      declaredDependencies: dependencies,
    );

    // For backward compatibility, also keep in legacy maps
    if (tag != null) {
      _taggedControllers[tag] = controller;
      // Set initial use count
      _tagUseCount[tag] = permanent ? -1 : 0; // -1 means permanent
    } else {
      _controllers[T] = controller;
      // Set initial use count
      _typeUseCount[T] = permanent ? -1 : 0; // -1 means permanent
    }

    // Track metrics
    ZenMetrics.recordControllerCreation(T);

    // Call lifecycle methods
    try {
      controller.onInit();

      // Schedule onReady to be called after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.isDisposed) {
          controller.onReady();
        }
      });
    } catch (e, stack) {
      ZenLogger.logError('Error initializing controller $T', e, stack);
    }

    return controller;
  }

  /// Find a controller in the specified scope or its parents
  static T? find<T extends ZenController>({String? tag, ZenScope? scope}) {
    // First try to find in the scope system
    final targetScope = scope ?? _rootScope;
    final scopeResult = targetScope.find<T>(tag: tag);
    if (scopeResult != null) {
      return scopeResult;
    }

    // Backward compatibility - check in legacy maps
    if (tag != null) {
      return _taggedControllers[tag] as T?;
    }
    return _controllers[T] as T?;
  }

  /// Get controller, create if it doesn't exist
  static T get<T extends ZenController>({String? tag, bool permanent = false, ZenScope? scope}) {
    final existing = find<T>(tag: tag, scope: scope);
    if (existing != null) {
      return existing;
    }

    // Check for factory
    Function? factory;
    if (tag != null) {
      factory = _taggedFactories[tag];
    } else {
      factory = _typeFactories[T];
    }

    if (factory != null) {
      final controller = factory() as T;
      return put<T>(controller, tag: tag, permanent: permanent, scope: scope);
    }

    throw Exception('Controller $T${tag != null ? ' with tag $tag' : ''} not found and no factory registered');
  }

  /// Register a factory for lazy creation
  static void lazyPut<T extends ZenController>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
      }) {
    if (tag != null) {
      _taggedFactories[tag] = factory;
    } else {
      _typeFactories[T] = factory;
    }

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  /// Delete a controller
  static bool delete<T extends ZenController>({String? tag, bool force = false, ZenScope? scope}) {
    bool deleted = false;

    // First remove from scope system
    final targetScope = scope ?? _rootScope;
    deleted = targetScope.delete<T>(tag: tag);

    // Also remove from legacy system for backward compatibility
    if (tag != null) {
      final controller = _taggedControllers[tag];
      if (controller != null) {
        // Check if permanent
        if (_tagUseCount[tag] == -1 && !force) {
          ZenLogger.logWarning('Attempted to delete permanent controller $T with tag $tag. Use force=true to override.');
          return false;
        }

        _taggedControllers.remove(tag);
        _taggedFactories.remove(tag);
        _tagUseCount.remove(tag);
        controller.dispose();
        deleted = true;
      }
    } else {
      final controller = _controllers[T];
      if (controller != null) {
        // Check if permanent
        if (_typeUseCount[T] == -1 && !force) {
          ZenLogger.logWarning('Attempted to delete permanent controller $T. Use force=true to override.');
          return false;
        }

        _controllers.remove(T);
        _typeFactories.remove(T);
        _typeUseCount.remove(T);
        controller.dispose();
        deleted = true;
      }
    }

    return deleted;
  }

  /// Delete by tag only
  static bool deleteByTag(String tag, {bool force = false, ZenScope? scope}) {
    bool deleted = false;

    // First delete from scope system
    final targetScope = scope ?? _rootScope;
    deleted = targetScope.deleteByTag(tag);

    // Also remove from legacy system for backward compatibility
    final controller = _taggedControllers[tag];
    if (controller != null) {
      // Check if permanent
      if (_tagUseCount[tag] == -1 && !force) {
        ZenLogger.logWarning('Attempted to delete permanent controller with tag $tag. Use force=true to override.');
        return false;
      }

      _taggedControllers.remove(tag);
      _taggedFactories.remove(tag);
      _tagUseCount.remove(tag);
      controller.dispose();
      deleted = true;
    }

    return deleted;
  }

  /// Delete all controllers
  static void deleteAll({bool force = false, ZenScope? scope}) {
    // Use specified scope or root scope for scope-based deletion
    final targetScope = scope ?? _rootScope;

    // Get all controllers in the target scope
    final controllers = targetScope.getAllDependencies().whereType<ZenController>().toList();

    // Dispose all controllers
    for (final controller in controllers) {
      if (!controller.isDisposed) {
        controller.dispose();
      }
    }

    // Clear the scope
    targetScope.dispose();

    // If deleting from root scope, also clean up legacy system
    if (scope == null || scope == _rootScope) {
      _controllers.clear();
      _taggedControllers.clear();
      _typeFactories.clear();
      _taggedFactories.clear();
      _typeUseCount.clear();
      _tagUseCount.clear();
    }
  }

  // Track usage count (for auto-disposal)
  static int incrementUseCount<T extends ZenController>({String? tag}) {
    if (tag != null) {
      final count = (_tagUseCount[tag] ?? 0) + 1;
      _tagUseCount[tag] = count;
      return count;
    } else {
      final count = (_typeUseCount[T] ?? 0) + 1;
      _typeUseCount[T] = count;
      return count;
    }
  }

  static int decrementUseCount<T extends ZenController>({String? tag}) {
    if (tag != null) {
      if (!_tagUseCount.containsKey(tag) || _tagUseCount[tag] == -1) {
        return -1; // Permanent or not found
      }

      final count = (_tagUseCount[tag] ?? 1) - 1;
      _tagUseCount[tag] = count;
      return count;
    } else {
      if (!_typeUseCount.containsKey(T) || _typeUseCount[T] == -1) {
        return -1; // Permanent or not found
      }

      final count = (_typeUseCount[T] ?? 1) - 1;
      _typeUseCount[T] = count;
      return count;
    }
  }

  // Auto-dispose unused controllers after a timeout
  static void _startAutoDisposeTimer() {
    Future.delayed(ZenConfig.controllerCacheExpiry, () {
      if (!ZenConfig.enableAutoDispose) return;

      final now = DateTime.now();

      // Check controllers by Type
      for (final entry in _controllers.entries) {
        final type = entry.key;
        final controller = entry.value;

        // Skip if permanent or in use
        if (_typeUseCount[type] == -1 || (_typeUseCount[type] ?? 0) > 0) continue;

        // Check if expired
        final age = now.difference(controller.createdAt);
        if (age > ZenConfig.controllerCacheExpiry) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug('Auto-disposing unused controller $type after ${age.inSeconds}s');
          }
          delete(scope: null, force: false);
        }
      }

      // Check controllers by Tag
      for (final entry in _taggedControllers.entries) {
        final tag = entry.key;
        final controller = entry.value;

        // Skip if permanent or in use
        if (_tagUseCount[tag] == -1 || (_tagUseCount[tag] ?? 0) > 0) continue;

        // Check if expired
        final age = now.difference(controller.createdAt);
        if (age > ZenConfig.controllerCacheExpiry) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug('Auto-disposing unused controller with tag $tag after ${age.inSeconds}s');
          }
          deleteByTag(tag);
        }
      }

      // Schedule next check
      _startAutoDisposeTimer();
    });
  }

  // Access the ProviderContainer for raw Riverpod usage
  static ProviderContainer get container => _container;

  /// Delete a controller by its runtime Type
  static bool deleteByType(Type type, {ZenScope? scope}) {
    // Delete from scope system first
    final targetScope = scope ?? _rootScope;
    final scopeDeleted = targetScope.deleteByType(type);

    // Check if the type exists in the controllers map
    if (_controllers.containsKey(type)) {
      final controller = _controllers[type]!;
      controller.dispose();
      _controllers.remove(type);

      // Update tracking counts
      if (_typeUseCount.containsKey(type)) {
        _typeUseCount.remove(type);
      }

      return true;
    }

    return scopeDeleted;
  }

  /// Create a type-safe controller reference
  static ControllerRef<T> ref<T extends ZenController>({String? tag, ZenScope? scope}) {
    return ControllerRef<T>(tag: tag, scope: scope);
  }

  /// Register a controller and return a type-safe reference
  static ControllerRef<T> putRef<T extends ZenController>(
      T controller, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
        List<dynamic> dependencies = const [],
      }) {
    put<T>(
      controller,
      tag: tag,
      permanent: permanent,
      scope: scope,
      dependencies: dependencies,
    );
    return ref<T>(tag: tag, scope: scope);
  }

  /// Register a factory and return a type-safe reference
  static ControllerRef<T> lazyRef<T extends ZenController>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
      }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return ref<T>(tag: tag, scope: scope);
  }

  /// Clean up resources when app is terminating
  static void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }

    // Clean up all controllers
    deleteAll(force: true);
  }

  /// Get all active controllers for management and debugging
  static List<ZenController> get allControllers {
    final List<ZenController> controllers = [];

    // Add from legacy system
    controllers.addAll(_controllers.values);
    controllers.addAll(_taggedControllers.values);

    // Add from scoped system (without duplicates)
    final allScopedControllers = _rootScope.getAllDependencies().whereType<ZenController>().toList();
    for (final controller in allScopedControllers) {
      if (!controllers.contains(controller)) {
        controllers.add(controller);
      }
    }

    return controllers;
  }

  /// Get the current use count for a controller type or tag
  static int getUseCount<T extends ZenController>({String? tag}) {
    if (tag != null) {
      // Use count for tagged controller
      return _tagUseCount[tag] ?? 0;
    } else {
      // Use count for type-based controller
      return _typeUseCount[T] ?? 0;
    }
  }

  /// Detect circular dependencies
  static bool _detectCycles(dynamic start) {
    final visited = <dynamic>{};
    final recursionStack = <dynamic>{};

    bool dfs(dynamic current) {
      if (!_dependencyGraph.containsKey(current)) {
        return false;
      }

      visited.add(current);
      recursionStack.add(current);

      for (final dependency in _dependencyGraph[current]!) {
        if (!visited.contains(dependency)) {
          if (dfs(dependency)) {
            return true;
          }
        } else if (recursionStack.contains(dependency)) {
          // Found a cycle
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logError('Circular dependency detected: ${dependency.runtimeType} depends on itself');
          }
          return true;
        }
      }

      recursionStack.remove(current);
      return false;
    }

    return dfs(start);
  }

  /// Find any registered dependency (not just controllers)
  static T? findDependency<T>({String? tag, ZenScope? scope}) {
    // Search in the scope system
    final targetScope = scope ?? _rootScope;
    return targetScope.find<T>(tag: tag);
  }

  /// Register any dependency (not just controllers)
  static T putDependency<T>(
      T instance, {
        String? tag,
        bool permanent = false,
        List<dynamic> dependencies = const [],
        ZenScope? scope,
      }) {
    // Use specified scope or root scope
    final targetScope = scope ?? _rootScope;

    // Register in the scope system using public register method
    targetScope.register<T>(
      instance,
      tag: tag,
      declaredDependencies: dependencies,
    );

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Registered dependency $T${tag != null ? ' with tag $tag' : ''}');
    }

    return instance;
  }

  /// Get dependency, create if it doesn't exist using factory
  static T getDependency<T>({
    String? tag,
    T Function()? factory,
    bool permanent = false,
    ZenScope? scope
  }) {
    final existing = findDependency<T>(tag: tag, scope: scope);
    if (existing != null) {
      return existing;
    }

    if (factory != null) {
      final instance = factory();
      return putDependency<T>(instance, tag: tag, permanent: permanent, scope: scope);
    }

    throw Exception('Dependency $T${tag != null ? ' with tag $tag' : ''} not found and no factory provided');
  }

  /// Register a factory for lazy creation of any dependency
  static void lazyPutDependency<T>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
      }) {
    // Store factory in the scope system
    if (tag != null) {
      _taggedFactories[tag] = factory;
    } else {
      _typeFactories[T] = factory;
    }

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for dependency $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  /// Delete a dependency (not a controller)
  static bool deleteDependency<T>({String? tag, bool force = false, ZenScope? scope}) {
    // Use specified scope or root scope
    final targetScope = scope ?? _rootScope;

    // Find the dependency in the target scope
    final dependency = targetScope.findInThisScope<T>(tag: tag);
    if (dependency == null) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logWarning('Dependency $T${tag != null ? ' with tag $tag' : ''} not found');
      }
      return false;
    }

    // Delete from scope
    bool deleted = targetScope.delete<T>(tag: tag);

    // Also remove from type factories or tagged factories if needed
    if (tag != null) {
      _taggedFactories.remove(tag);
    } else {
      _typeFactories.remove(T);
    }

    if (deleted && ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Deleted dependency $T${tag != null ? ' with tag $tag' : ''}');
    }

    return deleted;
  }

  /// Create a type-safe dependency reference
  static DependencyRef<T> dependencyRef<T>({String? tag, ZenScope? scope}) {
    return DependencyRef<T>(tag: tag, scope: scope);
  }

  /// Register a dependency and return a type-safe reference
  static DependencyRef<T> putDependencyRef<T>(
      T instance, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
        List<dynamic> dependencies = const [],
      }) {
    putDependency<T>(
      instance,
      tag: tag,
      permanent: permanent,
      scope: scope,
      dependencies: dependencies,
    );
    return dependencyRef<T>(tag: tag, scope: scope);
  }

  /// Register a factory and return a type-safe dependency reference
  static DependencyRef<T> lazyDependencyRef<T>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
      }) {
    lazyPutDependency<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return dependencyRef<T>(tag: tag, scope: scope);
  }

  /// Register multiple modules at once
  static void registerModules(List<ZenModule> modules) {
    for (final module in modules) {
      module.registerDependencies();
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Registered module: ${module.runtimeType}');
      }
    }
  }
}

/// Base class for organizing related dependencies into modules
abstract class ZenModule {
  /// Override this method to register your dependencies
  void registerDependencies();

  /// Helper method to register a dependency in this module
  T register<T>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
        bool lazy = false,
        ZenScope? scope,
        List<dynamic> dependencies = const [],
      }) {
    final targetScope = scope ?? Zen.rootScope;

    if (lazy) {
      if (T is ZenController) {
        Zen.lazyPut<ZenController>(
            factory as ZenController Function(),
            tag: tag,
            permanent: permanent,
            scope: targetScope
        );
        return null as T; // Will be initialized later
      } else {
        Zen.lazyPutDependency<T>(
            factory,
            tag: tag,
            permanent: permanent,
            scope: targetScope
        );
        return null as T; // Will be initialized later
      }
    } else {
      final instance = factory();
      if (instance is ZenController) {
        return Zen.put<ZenController>(
            instance as ZenController,
            tag: tag,
            permanent: permanent,
            dependencies: dependencies,
            scope: targetScope
        ) as T;
      } else {
        return Zen.putDependency<T>(
            instance,
            tag: tag,
            permanent: permanent,
            dependencies: dependencies,
            scope: targetScope
        );
      }
    }
  }
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

/// Monitors app lifecycle events and forwards them to controllers
class _ZenAppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Forward lifecycle events to all controllers
    final allControllers = Zen.allControllers;

    switch (state) {
      case AppLifecycleState.resumed:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onResume();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onResume for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.inactive:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onInactive();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onInactive for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.paused:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onPause();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onPause for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.detached:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onDetached();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onDetached for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.hidden:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onHidden();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onHidden for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
    }
  }
}