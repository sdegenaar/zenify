// lib/di/zen_di.dart
import '../../core/zen_logger.dart';
import '../../core/zen_config.dart';
import '../../core/zen_metrics.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_scope.dart';
import '../../core/zen_module.dart';
import 'zen_refs.dart';
import 'zen_reactive.dart';
import 'zen_lifecycle.dart';
import '../../di/zen_dependency_analyzer.dart';
import 'zen_scope_manager.dart';
import 'internal/zen_container.dart';

// Re-export references for easy access
export 'zen_refs.dart';
export 'zen_reactive.dart';

/// Dependency injection container with hierarchical scope support
class Zen {
  Zen._(); // Private constructor

  // Internal storage for instances, factories and reactive state
  static final ZenContainer container = ZenContainer();

  // Core reactive system
  static final ZenReactiveSystem reactiveSystem = ZenReactiveSystem();

  // Scope management
  static final ZenScopeManager scopeManager = ZenScopeManager();

  // Lifecycle management
  static final ZenLifecycleManager lifecycleManager = ZenLifecycleManager();

  // Dependency analysis
  static final ZenDependencyAnalyzer dependencyAnalyzer = ZenDependencyAnalyzer();

  // Initialize the system
  static void init() {
    if (ZenConfig.enableAutoDispose) {
      lifecycleManager.startAutoDisposeTimer(_getAllControllers, _findControllerScope);
    }

    // Set up app lifecycle observer
    lifecycleManager.initLifecycleObserver();
  }

  /// Get the global root scope
  static ZenScope get rootScope => scopeManager.rootScope;

  /// Create a new scope with optional parent
  static ZenScope createScope({ZenScope? parent, String? name, String? id}) {
    return scopeManager.createScope(parent: parent, name: name, id: id);
  }

  /// Get a factory key for associating factories with types and tags
  static dynamic _getKey(Type type, String? tag) {
    return container.getKey(type, tag);
  }

  /// Register an instance and notify listeners
  static void _registerInstance<T>(T instance, String? tag) {
    container.registerInstance<T>(instance, tag);
    reactiveSystem.notifyListeners<T>(tag);
  }

  /// Register a controller instance
  static T put<T extends ZenController>(T controller, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    // Use specified scope or root scope
    final targetScope = scope ?? scopeManager.rootScope;

    // Register in the scope (without cycle checking at this point)
    targetScope.register<T>(
      controller,
      tag: tag,
      permanent: permanent,
      declaredDependencies: dependencies,
    );

    // Also register in the reactive system
    _registerInstance<T>(controller, tag);

    // Check for circular dependencies after registration
    if (dependencies.isNotEmpty && ZenConfig.checkForCircularDependencies) {
      if (dependencyAnalyzer.detectCycles(controller, scopeManager.getAllScopes())) {
        ZenLogger.logWarning('Circular dependency detected involving $T${tag != null ? ' with tag $tag' : ''}');
        // We log but don't prevent registration, as some circular dependencies might be intentional
      }
    }

    // Track metrics
    ZenMetrics.recordControllerCreation(T);

    // Call lifecycle methods
    lifecycleManager.initializeController(controller);

    return controller;
  }

  /// Register a dependency (not a controller)
  static T putDependency<T>(T instance, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.rootScope;

    // Register the instance first without checking for cycles
    targetScope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
      declaredDependencies: dependencies,
    );

    // Also register in the reactive system
    _registerInstance<T>(instance, tag);

    // Only check for cycles if explicitly enabled AND dependencies are provided
    if (dependencies.isNotEmpty && ZenConfig.checkForCircularDependencies) {
      // Suppress any exceptions during cycle detection - we don't want them to
      // prevent the registration or break tests
      try {
        if (dependencyAnalyzer.detectCycles(instance, scopeManager.getAllScopes())) {
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
    final targetScope = scope ?? scopeManager.rootScope;
    return targetScope.find<T>(tag: tag);
  }

  /// Find any dependency (not a controller)
  static T? findDependency<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;
    return targetScope.find<T>(tag: tag);
  }

  /// Find any dependency by Type object at runtime (not just at compile time)
  static dynamic findDependencyByType(Type type, {String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;
    return targetScope.findByType(type, tag: tag);
  }

  /// Get controller, create if it doesn't exist
  static T get<T extends ZenController>({String? tag, bool permanent = false, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;
    final existing = targetScope.find<T>(tag: tag);

    if (existing != null) {
      return existing;
    }

    // Check for factory
    final factoryKey = _getKey(T, tag);
    final factory = container.getFactory(factoryKey);

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
    final targetScope = scope ?? scopeManager.rootScope;
    final existing = targetScope.find<T>(tag: tag);

    if (existing != null) {
      return existing;
    }

    // Check for registered factory
    final factoryKey = _getKey(T, tag);
    final registeredFactory = container.getFactory(factoryKey);

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
    final factoryKey = _getKey(T, tag);
    container.registerFactory(factoryKey, factory);

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
    final factoryKey = _getKey(T, tag);
    container.registerFactory(factoryKey, factory);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for dependency $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  /// Delete a controller
  static bool delete<T extends ZenController>({String? tag, bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.delete<T>(tag: tag, force: force);

    // If deleted, also remove from reactive system and any factory
    if (deleted) {
      container.removeInstance<T>(tag);
      final factoryKey = _getKey(T, tag);
      container.removeFactory(factoryKey);
    }

    return deleted;
  }

  /// Delete any dependency
  static bool deleteDependency<T>({String? tag, bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;

    // Delete from scope
    bool deleted = targetScope.delete<T>(tag: tag, force: force);

    // If deleted, also remove from reactive system and any factory
    if (deleted) {
      container.removeInstance<T>(tag);
      final factoryKey = _getKey(T, tag);
      container.removeFactory(factoryKey);
    }

    return deleted;
  }

  /// Delete by tag only (without knowing the type)
  static bool deleteByTag(String tag, {bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.deleteByTag(tag, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      // We don't have the type, so we need to find factories by tag pattern
      container.removeFactoriesByTag(tag);
    }

    return deleted;
  }

  /// Delete by runtime type
  static bool deleteByType(Type type, {bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.deleteByType(type, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      container.removeFactoriesByType(type);
    }

    return deleted;
  }

  /// Delete all controllers and dependencies
  static void deleteAll({bool force = false, ZenScope? scope}) {
    // Use specified scope or root scope for scope-based deletion
    final targetScope = scope ?? scopeManager.rootScope;

    // If we're deleting from the root scope, clear all factories too
    if (scope == null || scope == scopeManager.rootScope) {
      container.clear();
      reactiveSystem.clearListeners();
    } else {
      // Otherwise just clear factories related to this scope's dependencies
      final allDeps = targetScope.getAllDependencies();
      for (final dep in allDeps) {
        final type = dep.runtimeType;

        // Try to determine if this dependency has a tag
        final tag = targetScope.getTagForInstance(dep);
        final key = tag != null ? _getKey(type, tag) : type;

        container.removeFactory(key);
        container.removeInstanceByTypeAndTag(type, tag);
      }
    }

    // Handle scope differently based on whether it's the root scope or not
    if (force) {
      if (scope == null || scope == scopeManager.rootScope) {
        // For root scope with force=true, we need special handling
        // First, clear all dependencies without disposing the scope itself
        final deps = scopeManager.rootScope.getAllDependencies().toList();
        for (final dep in deps) {
          final type = dep.runtimeType;
          final tag = scopeManager.rootScope.getTagForInstance(dep);

          if (tag != null) {
            scopeManager.rootScope.deleteByTag(tag, force: true);
          } else {
            scopeManager.rootScope.deleteByType(type, force: true);
          }
        }

        // Clear all child scopes without disposing root
        for (final childScope in List.from(scopeManager.rootScope.childScopes)) {
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
    final targetScope = scope ?? scopeManager.rootScope;
    return targetScope.incrementUseCount<T>(tag: tag);
  }

  /// Decrement use count for a controller
  static int decrementUseCount<T extends ZenController>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;
    return targetScope.decrementUseCount<T>(tag: tag);
  }

  /// Get current use count for a controller
  static int getUseCount<T extends ZenController>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.rootScope;
    return targetScope.getUseCount<T>(tag: tag);
  }

  /// Listen to changes for a specific type and tag
  /// Replacement for Riverpod's listen function
  static ZenSubscription listen<T>(
      dynamic provider,
      void Function(T) listener, {
        dynamic container,
      }) {
    return reactiveSystem.listen<T>(provider, listener);
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
    final targetScope = scope ?? scopeManager.rootScope;

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
    return _getAllControllers();
  }

  static List<ZenController> _getAllControllers() {
    return scopeManager.rootScope
        .getAllDependencies()
        .whereType<ZenController>()
        .toList();
  }

  static ZenScope? _findControllerScope(ZenController controller) {
    for (final scope in scopeManager.getAllScopes()) {
      if (scope.containsInstance(controller)) {
        return scope;
      }
    }
    return null;
  }

  /// Clean up resources when app is terminating
  static void dispose() {
    lifecycleManager.dispose();
    container.clear();
    reactiveSystem.clearListeners();
    scopeManager.dispose();
  }

  /// Detect and report problematic dependencies
  static String detectProblematicDependencies() {
    if (!ZenConfig.enableDependencyVisualization) {
      return 'Dependency detection is disabled. Enable it with ZenConfig.enableDependencyVisualization = true';
    }

    return dependencyAnalyzer.detectProblematicDependencies(scopeManager.getAllScopes());
  }

  /// Visualize dependency relationships for debugging
  static String visualizeDependencyGraph() {
    if (!ZenConfig.enableDependencyVisualization) {
      return 'Dependency visualization is disabled. Enable it with ZenConfig.enableDependencyVisualization = true';
    }

    return dependencyAnalyzer.visualizeDependencyGraph(scopeManager.getAllScopes());
  }
}