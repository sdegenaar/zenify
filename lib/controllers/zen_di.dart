// lib/controllers/zen_di.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';
import 'zen_controller.dart';
import '../core/zen_scope.dart';
import '../core/zen_module.dart';

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

/// Dependency injection container with hierarchical scope support
class Zen {
  Zen._(); // Private constructor

  // Will be initialized with the app's root container
  static late ProviderContainer _container;

  // Root scope for the application
  static final ZenScope _rootScope = ZenScope(name: 'RootScope');

  // Map for factories - stored centrally but associated with scopes
  static final Map<dynamic, Function> _factories = {};

  // App lifecycle observer
  static _ZenAppLifecycleObserver? _lifecycleObserver;

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

  /// Get a factory key for associating factories with types and tags
  static dynamic _getFactoryKey(Type type, String? tag) {
    return tag != null ? '$type:$tag' : type;
  }

  /// Register a controller instance
  static T put<T extends ZenController>(T controller, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    // Use specified scope or root scope
    final targetScope = scope ?? _rootScope;

    // Register in the scope (without cycle checking at this point)
    targetScope.register<T>(
      controller,
      tag: tag,
      permanent: permanent,
      declaredDependencies: dependencies,
    );

    // Check for circular dependencies after registration
    if (dependencies.isNotEmpty && ZenConfig.checkForCircularDependencies) {
      if (_detectCycles(controller)) {
        ZenLogger.logWarning('Circular dependency detected involving $T${tag != null ? ' with tag $tag' : ''}');
        // We log but don't prevent registration, as some circular dependencies might be intentional
      }
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

  /// Register a dependency (not a controller)
  static T putDependency<T>(T instance, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    final targetScope = scope ?? _rootScope;

    // Register the instance first without checking for cycles
    targetScope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
      declaredDependencies: dependencies,
    );

    // Only check for cycles if explicitly enabled AND dependencies are provided
    if (dependencies.isNotEmpty && ZenConfig.checkForCircularDependencies) {
      // Suppress any exceptions during cycle detection - we don't want them to
      // prevent the registration or break tests
      try {
        if (_detectCycles(instance)) {
          ZenLogger.logWarning('Circular dependency detected involving $T${tag != null ? ' with tag $tag' : ''}');
        }
      } catch (e) {
        // Just log the error and continue
        ZenLogger.logWarning('Error during cycle detection: $e');
      }
    }

    return instance;
  }

  /// Find a controller in the specified scope or its parents
  static T? find<T extends ZenController>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;
    return targetScope.find<T>(tag: tag);
  }

  /// Find any dependency (not a controller)
  static T? findDependency<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;
    return targetScope.find<T>(tag: tag);
  }

  /// Find any dependency by Type object at runtime (not just at compile time)
  static dynamic findDependencyByType(Type type, {String? tag, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;
    return targetScope.findByType(type, tag: tag);
  }


  /// Get controller, create if it doesn't exist
  static T get<T extends ZenController>({String? tag, bool permanent = false, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;
    final existing = targetScope.find<T>(tag: tag);

    if (existing != null) {
      return existing;
    }

    // Check for factory
    final factoryKey = _getFactoryKey(T, tag);
    final factory = _factories[factoryKey];

    if (factory != null) {
      final controller = factory() as T;
      return put<T>(controller, tag: tag, permanent: permanent, scope: scope);
    }

    throw Exception('Controller $T${tag != null ? ' with tag $tag' : ''} not found and no factory registered');
  }

  /// Get any dependency, create if it doesn't exist
  static T getDependency<T>({
    String? tag,
    T Function()? factory,
    bool permanent = false,
    ZenScope? scope
  }) {
    final targetScope = scope ?? _rootScope;
    final existing = targetScope.find<T>(tag: tag);

    if (existing != null) {
      return existing;
    }

    // Check for registered factory
    final factoryKey = _getFactoryKey(T, tag);
    final registeredFactory = _factories[factoryKey];

    // Use provided factory or registered factory
    if (factory != null) {
      final instance = factory();
      return putDependency<T>(instance, tag: tag, permanent: permanent, scope: scope);
    } else if (registeredFactory != null) {
      final instance = registeredFactory() as T;
      return putDependency<T>(instance, tag: tag, permanent: permanent, scope: scope);
    }

    throw Exception('Dependency $T${tag != null ? ' with tag $tag' : ''} not found and no factory provided or registered');
  }

  /// Register a factory for lazy creation of controllers
  static void lazyPut<T extends ZenController>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    final factoryKey = _getFactoryKey(T, tag);
    _factories[factoryKey] = factory;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  /// Register a factory for lazy creation of dependencies
  static void lazyPutDependency<T>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    final factoryKey = _getFactoryKey(T, tag);
    _factories[factoryKey] = factory;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for dependency $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  /// Delete a controller
  static bool delete<T extends ZenController>({String? tag, bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.delete<T>(tag: tag, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      final factoryKey = _getFactoryKey(T, tag);
      _factories.remove(factoryKey);
    }

    return deleted;
  }

  /// Delete any dependency
  static bool deleteDependency<T>({String? tag, bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;

    // Delete from scope
    bool deleted = targetScope.delete<T>(tag: tag, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      final factoryKey = _getFactoryKey(T, tag);
      _factories.remove(factoryKey);
    }

    return deleted;
  }

  /// Delete by tag only (without knowing the type)
  static bool deleteByTag(String tag, {bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.deleteByTag(tag, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      // We don't have the type, so we need to find factories by tag pattern
      final keysToRemove = _factories.keys
          .whereType<String>()
          .where((key) => key.endsWith(':$tag'))
          .toList();

      for (final key in keysToRemove) {
        _factories.remove(key);
      }
    }

    return deleted;
  }

  /// Delete by runtime type
  static bool deleteByType(Type type, {bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.deleteByType(type, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      _factories.remove(type);

      // Also remove any tagged factories for this type
      final keysToRemove = _factories.keys
          .whereType<String>()
          .where((key) => key.startsWith('$type:'))
          .toList();

      for (final key in keysToRemove) {
        _factories.remove(key);
      }
    }

    return deleted;
  }

  /// Delete all controllers and dependencies
  static void deleteAll({bool force = false, ZenScope? scope}) {
    // Use specified scope or root scope for scope-based deletion
    final targetScope = scope ?? _rootScope;

    // If we're deleting from the root scope, clear all factories too
    if (scope == null || scope == _rootScope) {
      _factories.clear();
    } else {
      // Otherwise just clear factories related to this scope's dependencies
      final allDeps = targetScope.getAllDependencies();
      for (final dep in allDeps) {
        final type = dep.runtimeType;

        // Try to determine if this dependency has a tag
        final tag = targetScope.getTagForInstance(dep);
        final key = tag != null ? _getFactoryKey(type, tag) : type;

        _factories.remove(key);
      }
    }

    // Handle scope differently based on whether it's the root scope or not
    if (force) {
      if (scope == null || scope == _rootScope) {
        // For root scope with force=true, we need special handling
        // First, clear all dependencies without disposing the scope itself
        final deps = _rootScope.getAllDependencies().toList();
        for (final dep in deps) {
          final type = dep.runtimeType;
          final tag = _rootScope.getTagForInstance(dep);

          if (tag != null) {
            _rootScope.deleteByTag(tag, force: true);
          } else {
            _rootScope.deleteByType(type, force: true);
          }
        }

        // Clear all child scopes without disposing root
        for (final childScope in List.from(_rootScope.childScopes)) {
          childScope.dispose();
        }
      } else {
        // For non-root scopes, we can simply dispose them
        targetScope.dispose();
      }
    } else {
      // Only dispose non-permanent ones
      final deps = targetScope.getAllDependencies();
      for (final dep in deps) {
        if (dep is ZenController) {
          final type = dep.runtimeType;
          final tag = targetScope.getTagForInstance(dep);

          if (!targetScope.isPermanent(type: type, tag: tag)) {
            if (tag != null) {
              targetScope.deleteByTag(tag);
            } else {
              targetScope.deleteByType(type);
            }
          }
        }
      }
    }
  }

  /// Increment use count for a controller
  static int incrementUseCount<T extends ZenController>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;
    return targetScope.incrementUseCount<T>(tag: tag);
  }

  /// Decrement use count for a controller
  static int decrementUseCount<T extends ZenController>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;
    return targetScope.decrementUseCount<T>(tag: tag);
  }

  /// Get current use count for a controller
  static int getUseCount<T extends ZenController>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;
    return targetScope.getUseCount<T>(tag: tag);
  }

  /// Create and return a reference to a controller
  static ControllerRef<T> ref<T extends ZenController>({String? tag, ZenScope? scope}) {
    return ControllerRef<T>(tag: tag, scope: scope);
  }

  /// Create and register a type-safe reference to a controller
  static ControllerRef<T> putRef<T extends ZenController>(T controller, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    put<T>(controller, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return ControllerRef<T>(tag: tag, scope: scope);
  }

  /// Register a factory and return a type-safe reference
  static ControllerRef<T> lazyRef<T extends ZenController>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return ref<T>(tag: tag, scope: scope);
  }

  /// Create and return a reference to any dependency
  static DependencyRef<T> dependencyRef<T>({String? tag, ZenScope? scope}) {
    return DependencyRef<T>(tag: tag, scope: scope);
  }

  /// Create and register a type-safe reference to any dependency
  static DependencyRef<T> putDependencyRef<T>(T instance, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    putDependency<T>(instance, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return DependencyRef<T>(tag: tag, scope: scope);
  }

  /// Register a factory and return a type-safe dependency reference
  static DependencyRef<T> lazyDependencyRef<T>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    lazyPutDependency<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return dependencyRef<T>(tag: tag, scope: scope);
  }


  /// Register modules in a scope
  static void registerModules(List<ZenModule> modules, {ZenScope? scope}) {
    final targetScope = scope ?? _rootScope;

    for (final module in modules) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Registering module: ${module.name}');
      }

      // Register the module in the registry with the current scope
      ZenModuleRegistry.register(module, scope: targetScope);
    }
  }

  /// Get all active controllers for management and debugging
  static List<ZenController> get allControllers {
    return _rootScope
        .getAllDependencies()
        .whereType<ZenController>()
        .toList();
  }

  /// Detect circular dependencies across all scopes
  static bool _detectCycles(dynamic start) {
    try {
      // Safety check - if start is null, there can't be a cycle
      if (start == null) return false;

      final visited = <dynamic>{};
      final recursionStack = <dynamic>{};

      // Helper to recursively trace dependencies across scopes
      bool detectCyclesRecursive(dynamic current) {
        // Safety check - null should not be considered for cycles
        if (current == null) return false;

        // Depth limiter
        if (recursionStack.length > 100) {
          ZenLogger.logWarning('Cycle detection reached depth limit - possible deep circular reference');
          return true;
        }

        // If already in recursion stack, we found a cycle
        if (recursionStack.contains(current)) {
          return true;
        }

        // If already visited and no cycle was found, skip
        if (visited.contains(current)) {
          return false;
        }

        visited.add(current);
        recursionStack.add(current);

        // Check dependencies in all scopes
        for (final scope in _getAllScopes()) {
          final dependencies = scope.getDependenciesOf(current);
          for (final dependency in dependencies) {
            if (detectCyclesRecursive(dependency)) {
              return true;
            }
          }
        }

        recursionStack.remove(current);
        return false;
      }

      return detectCyclesRecursive(start);
    } catch (e, stack) {
      ZenLogger.logError('Error in cycle detection', e, stack);
      // Assume a cycle exists if there's an error
      return true;
    }
  }


  /// Clean up resources when app is terminating
  static void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }

    // Clean up all controllers and factories
    _factories.clear();
    _rootScope.dispose();
  }

  /// Start auto dispose timer for cleaning up unused controllers
  static void _startAutoDisposeTimer() {
    Future.delayed(ZenConfig.controllerCacheExpiry, () {
      if (!ZenConfig.enableAutoDispose) return;

      final now = DateTime.now();

      // Change this line to use the getter properly
      final controllers = Zen.allControllers;

      for (final controller in controllers) {
        if (controller.isDisposed) continue;

        // Try to find the scope this controller is in
        ZenScope? controllerScope;
        for (final scope in _getAllScopes()) {
          if (scope.containsInstance(controller)) {
            controllerScope = scope;
            break;
          }
        }

        if (controllerScope == null) continue;

        // Skip if permanent
        final tag = controllerScope.getTagForInstance(controller);
        final type = controller.runtimeType;

        if (controllerScope.isPermanent(type: type, tag: tag)) {
          continue;
        }

        // Check if use count is 0
        final useCount = tag != null
            ? controllerScope.getUseCountByType(type: type, tag: tag)
            : controllerScope.getUseCountByType(type: type, tag: null);

        if (useCount > 0) continue;

        // Check if expired
        final age = now.difference(controller.createdAt);
        if (age > ZenConfig.controllerCacheExpiry) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug('Auto-disposing unused controller $type${tag != null ? ' with tag $tag' : ''} after ${age.inSeconds}s');
          }

          if (tag != null) {
            controllerScope.deleteByTag(tag);
          } else {
            controllerScope.deleteByType(type);
          }
        }
      }

      // Schedule next check
      _startAutoDisposeTimer();
    });
  }



  /// Get all scopes in the hierarchy
  static List<ZenScope> _getAllScopes() {
    final List<ZenScope> result = [_rootScope];

    void addChildScopes(ZenScope scope) {
      final children = scope.childScopes;
      result.addAll(children);
      for (final child in children) {
        addChildScopes(child);
      }
    }

    addChildScopes(_rootScope);
    return result;
  }

  /// Detect and report problematic dependencies
  /// Useful for debugging dependency issues
  static String detectProblematicDependencies() {
    final buffer = StringBuffer();

    if (!ZenConfig.enableDependencyVisualization) {
      return 'Dependency detection is disabled. Enable it with ZenConfig.enableDependencyVisualization = true';
    }

    buffer.writeln('=== DEPENDENCY ANALYSIS ===\n');

    // List potentially problematic dependencies
    var problemFound = false;

    // Check for circular dependencies
    for (final scope in _getAllScopes()) {
      final allDeps = scope.findAllOfType<Object>();

      for (final dep in allDeps) {
        if (_detectCycles(dep)) {
          final tag = scope.getTagForInstance(dep);
          buffer.write('CIRCULAR DEPENDENCY: ${dep.runtimeType}');
          if (tag != null) buffer.write(' (tag: $tag)');
          buffer.writeln(' is part of a dependency cycle');
          problemFound = true;
        }
      }
    }

    // Check for dependencies registered in multiple scopes
    final typeToScopes = <Type, List<ZenScope>>{};

    for (final scope in _getAllScopes()) {
      final deps = scope.findAllOfType<Object>();

      for (final dep in deps) {
        final type = dep.runtimeType;
        if (!typeToScopes.containsKey(type)) {
          typeToScopes[type] = [];
        }
        typeToScopes[type]!.add(scope);
      }
    }

    // Report types registered in multiple scopes
    for (final entry in typeToScopes.entries) {
      if (entry.value.length > 1) {
        buffer.writeln('MULTIPLE REGISTRATIONS: ${entry.key} is registered in multiple scopes:');
        for (final scope in entry.value) {
          buffer.writeln('  - ${scope.name ?? scope.id}');
        }
        problemFound = true;
      }
    }

    // Check for heavily dependent objects (potential design issues)
    for (final scope in _getAllScopes()) {
      final allDeps = scope.findAllOfType<Object>();

      for (final dep in allDeps) {
        final dependencies = scope.getDependenciesOf(dep);
        if (dependencies.length > 5) {  // Threshold for "too many dependencies"
          final tag = scope.getTagForInstance(dep);
          buffer.write('MANY DEPENDENCIES: ${dep.runtimeType}');
          if (tag != null) buffer.write(' (tag: $tag)');
          buffer.writeln(' has ${dependencies.length} dependencies which might indicate a design issue');
          problemFound = true;
        }
      }
    }

    // No problems found
    if (!problemFound) {
      buffer.writeln('No problematic dependencies detected');
    }

    return buffer.toString();
  }

  /// Visualize dependency relationships for debugging
  /// Returns a string representation of the dependency graph
  static String visualizeDependencyGraph() {
    final buffer = StringBuffer();

    if (!ZenConfig.enableDependencyVisualization) {
      return 'Dependency visualization is disabled. Enable it with ZenConfig.enableDependencyVisualization = true';
    }

    buffer.writeln('=== ZEN DEPENDENCY GRAPH ===\n');

    for (final scope in _getAllScopes()) {
      buffer.writeln('SCOPE: ${scope.name ?? scope.id}');

      // Get all dependencies in this scope
      final dependencies = <dynamic>[];
      dependencies.addAll(scope.findAllOfType<Object>());

      if (dependencies.isEmpty) {
        buffer.writeln('  No dependencies registered in this scope');
        buffer.writeln();
        continue;
      }

      // List each dependency and what it depends on
      for (final instance in dependencies) {
        final type = instance.runtimeType;
        final tag = scope.getTagForInstance(instance);
        final dependsOn = scope.getDependenciesOf(instance);

        buffer.write('  $type');
        if (tag != null) buffer.write(' (tag: $tag)');

        if (dependsOn.isEmpty) {
          buffer.writeln(' - no dependencies');
        } else {
          buffer.writeln(' depends on:');
          for (final dep in dependsOn) {
            final depTag = scope.getTagForInstance(dep);
            buffer.write('    - ${dep.runtimeType}');
            if (depTag != null) buffer.write(' (tag: $depTag)');
            buffer.writeln();
          }
        }
      }

      buffer.writeln();
    }

    // Also show module dependencies if any modules are registered
    if (ZenModuleRegistry.getAll().isNotEmpty) {
      buffer.writeln('=== MODULE DEPENDENCIES ===\n');

      for (final entry in ZenModuleRegistry.getAll().entries) {
        final moduleName = entry.key;
        final module = entry.value;

        buffer.write('Module: $moduleName depends on: ');
        if (module.dependencies.isEmpty) {
          buffer.writeln('none');
        } else {
          buffer.writeln();
          for (final dep in module.dependencies) {
            buffer.writeln('  - ${dep.name}');
          }
        }
      }
    }

    return buffer.toString();
  }

  // Access the ProviderContainer for raw Riverpod usage
  static ProviderContainer get container => _container;
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