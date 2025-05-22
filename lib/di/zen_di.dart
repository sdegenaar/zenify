// lib/di/zen_di.dart
import '../../core/zen_logger.dart';
import '../../core/zen_config.dart';
import '../../core/zen_metrics.dart';
import '../../controllers/zen_controller.dart';
import '../../core/zen_scope.dart';
import '../../core/zen_module.dart';
import '../reactive/rx_value.dart';
import 'zen_refs.dart';
import 'zen_reactive.dart';
import 'zen_lifecycle.dart';
import '../../di/zen_dependency_analyzer.dart';
import 'zen_scope_manager.dart';
import 'internal/zen_container.dart';

// Re-export references for easy access
export 'zen_refs.dart';
export 'zen_reactive.dart';
export '../reactive/rx_value.dart';

/// Dependency injection container with hierarchical scope support
class Zen {
  Zen._(); // Private constructor

  // Internal storage for instances, factories and reactive state
  static final ZenContainer container = ZenContainer.instance;

  // Core reactive system
  static final ZenReactiveSystem reactiveSystem = ZenReactiveSystem.instance;

  // Scope management
  static final ZenScopeManager scopeManager = ZenScopeManager.instance;

  // Lifecycle management
  static final ZenLifecycleManager lifecycleManager = ZenLifecycleManager.instance;

  // Dependency analysis
  static final ZenDependencyAnalyzer dependencyAnalyzer = ZenDependencyAnalyzer.instance;

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

  /// Get the current scope for context-aware operations
  static ZenScope get currentScope => scopeManager.currentScope;

  /// Get a factory key for associating factories with types and tags
  static dynamic _getKey(Type type, String? tag) {
    return container.getKey(type, tag);
  }

  /// Notify reactive listeners about an instance or value
  static void _notifyReactive<T>(T instance, String? tag) {
    // Just notify with the generic type parameter
    reactiveSystem.notifyListeners<T>(tag);
  }

  //
  // DEPENDENCY REGISTRATION
  //

  /// Register a controller or dependency instance
  static T put<T>(T instance, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    // Use specified scope or current scope
    final targetScope = scope ?? scopeManager.currentScope;

    // Handle controllers with special lifecycle handling
    if (instance is ZenController) {
      // Register in the scope
      targetScope.register<T>(
        instance,
        tag: tag,
        permanent: permanent,
        declaredDependencies: dependencies,
      );

      // Notify reactive system
      _notifyReactive<T>(instance, tag);

      // Check for circular dependencies if needed
      if (dependencies.isNotEmpty && ZenConfig.checkForCircularDependencies) {
        if (dependencyAnalyzer.detectCycles(instance, scopeManager.getAllScopes())) {
          ZenLogger.logWarning('Circular dependency detected involving $T${tag != null ? ' with tag $tag' : ''}');
        }
      }

      // Track metrics
      ZenMetrics.recordControllerCreation(T);

      // Call lifecycle methods
      lifecycleManager.initializeController(instance as ZenController);

      return instance;
    } else {
      // Register regular dependency in the scope
      targetScope.register<T>(
        instance,
        tag: tag,
        permanent: permanent,
        declaredDependencies: dependencies,
      );

      // Notify reactive system
      _notifyReactive<T>(instance, tag);

      // Debug logs
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Registered $T${tag != null ? ' with tag $tag' : ''} in scope: ${targetScope.name}');
      }

      // Circular dependency detection
      if (dependencies.isNotEmpty && ZenConfig.checkForCircularDependencies) {
        try {
          if (dependencyAnalyzer.detectCycles(instance, scopeManager.getAllScopes())) {
            ZenLogger.logWarning('Circular dependency detected involving $T${tag != null ? ' with tag $tag' : ''}');
          }
        } catch (e) {
          ZenLogger.logWarning('Error during cycle detection: $e');
        }
      }

      return instance;
    }
  }

  /// Register a factory for lazy initialization
  static void lazyPut<T>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // Only register in the scope - no need for the container duplication
    targetScope.lazily<T>(factory, tag: tag);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''} in scope: ${targetScope.name}');
    }
  }

  /// Alternative API for registering a controller-specific factory
  static void lazyController<T extends ZenController>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
  }

  /// Register a factory for lazy creation of dependencies
  static void lazyInject<T>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
  }

  /// Register a factory that creates a new instance each time
  static void putFactory<T>(T Function() factory, {
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;
    targetScope.putFactory<T>(factory, tag: tag);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  /// Register a factory function in the root scope
  static void putFactoryGlobal<T>(T Function() factory, {String? tag}) {
    scopeManager.rootScope.putFactory<T>(factory, tag: tag);
  }

  //
  // DEPENDENCY RETRIEVAL
  //

  /// Find an instance by type (may return null if not found)
  /// This does NOT instantiate lazy dependencies
  static T? find<T>({
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // Only check for actual instances, not factories
    // We need to check all parent scopes too, but without instantiating lazy dependencies
    return _findInstanceOnly<T>(tag: tag, scope: targetScope);
  }

  /// Internal helper to find only existing instances without triggering lazy instantiation
  static T? _findInstanceOnly<T>({String? tag, required ZenScope scope}) {
    // First check if the instance exists in this scope without initializing lazy deps
    final instance = scope.findInstanceOnly<T>(tag: tag);
    if (instance != null) {
      return instance;
    }

    // Check parent scopes if available
    if (scope.parent != null) {
      return _findInstanceOnly<T>(tag: tag, scope: scope.parent!);
    }

    return null;
  }




  /// Get an instance by type (throws if not found)
  static T get<T>({
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // First check if the instance already exists in the scope
    final result = targetScope.find<T>(tag: tag);
    if (result != null) {
      return result;
    }

    // If not found in scope, check for factory in the container
    final factoryKey = _getKey(T, tag);
    final factory = container.getFactory(factoryKey);

    if (factory != null && T != dynamic) {
      // Create the instance and register it
      final instance = factory() as T;

      // Use put to register it properly
      return put<T>(instance, tag: tag, scope: targetScope);
    }

    throw Exception('Instance of $T${tag != null ? ' with tag $tag' : ''} not found and no factory available');
  }

  /// Find a dependency, returns null if not found (compatibility alias)
  static T? lookup<T>({String? tag, ZenScope? scope}) {
    return find<T>(tag: tag, scope: scope);
  }

  /// Get a dependency, create if it doesn't exist
  static T require<T>({
    String? tag,
    T Function()? factory,
    bool permanent = false,
    ZenScope? scope
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // First check if the instance already exists
    final existing = targetScope.find<T>(tag: tag);
    if (existing != null) {
      return existing;
    }

    // Try provided factory first
    if (factory != null) {
      final instance = factory();
      return put<T>(instance, tag: tag, permanent: permanent, scope: targetScope);
    }

    // Check for registered factory
    final factoryKey = _getKey(T, tag);
    final registeredFactory = container.getFactory(factoryKey);

    if (registeredFactory != null) {
      final instance = registeredFactory() as T;
      return put<T>(instance, tag: tag, permanent: permanent, scope: targetScope);
    }

    throw Exception('Dependency $T${tag != null ? ' ($tag)' : ''} not found and no factory available');
  }

  //
  // DEPENDENCY REMOVAL
  //

  /// Delete an instance by type
  static bool delete<T>({
    String? tag,
    bool force = false,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.delete<T>(tag: tag, force: force);

    // If deleted, also remove any factory and notify reactive system
    if (deleted) {
      final factoryKey = _getKey(T, tag);
      container.removeFactory(factoryKey);
      reactiveSystem.notifyListeners<T>(tag);
    }

    return deleted;
  }

  /// Delete by tag only (without knowing the type)
  static bool deleteByTag(String tag, {
    bool force = false,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.deleteByTag(tag, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      container.removeFactoriesByTag(tag);
    }

    return deleted;
  }

  /// Delete by runtime type
  static bool deleteByType(Type type, {
    bool force = false,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // Delete from scope - this handles permanent flag check and disposal
    bool deleted = targetScope.deleteByType(type, force: force);

    // If deleted, also remove any factory
    if (deleted) {
      container.removeFactoriesByType(type);
    }

    return deleted;
  }

  /// Remove a dependency (alias for delete)
  static bool remove<T>({String? tag, bool force = false, ZenScope? scope}) {
    return delete<T>(tag: tag, force: force, scope: scope);
  }

  /// Delete all dependencies and controllers
  static void deleteAll({
    bool force = false,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    // If we're deleting from the root scope, clear all factories too
    if (targetScope == scopeManager.rootScope) {
      container.clear();
      reactiveSystem.clearListeners();
    } else {
      // Otherwise just clear factories related to this scope's dependencies
      final allDeps = targetScope.getAllDependencies();
      for (final dep in allDeps) {
        final type = dep.runtimeType;
        final tag = targetScope.getTagForInstance(dep);
        final key = tag != null ? _getKey(type, tag) : type;
        container.removeFactory(key);
      }
    }

    // Handle scope differently based on whether it's the root scope or not
    if (force) {
      if (targetScope == scopeManager.rootScope) {
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

  //
  // REFERENCE SYSTEM
  //

  /// Create and return a reference to a controller
  static ControllerRef<T> ref<T extends ZenController>({
    String? tag,
    ZenScope? scope,
  }) {
    return ControllerRef<T>(tag: tag, scope: scope ?? currentScope);
  }

  /// Create and register a reference to a controller
  static ControllerRef<T> putRef<T extends ZenController>(T controller, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    put<T>(controller, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return ref<T>(tag: tag, scope: scope);
  }

  /// Register a factory and return a controller reference
  static LazyControllerRef<T> lazyRef<T extends ZenController>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return LazyControllerRef<T>(tag: tag, scope: scope);
  }

  /// Create and return a reference to any dependency
  static DependencyRef<T> depRef<T>({
    String? tag,
    ZenScope? scope,
  }) {
    return DependencyRef<T>(tag: tag, scope: scope ?? currentScope);
  }

  /// Create and register a reference to any dependency
  static DependencyRef<T> injectRef<T>(T instance, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
    ZenScope? scope,
  }) {
    put<T>(instance, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return depRef<T>(tag: tag, scope: scope);
  }

  /// Register a factory and return a dependency reference
  static DependencyRef<T> lazyDepRef<T>(T Function() factory, {
    String? tag,
    bool permanent = false,
    ZenScope? scope,
  }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return depRef<T>(tag: tag, scope: scope);
  }

  /// Check if a dependency exists without initializing it (for lazy dependencies)
  /// Check if a dependency exists without initializing it (for lazy dependencies)
  static bool exists<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.currentScope;

    // For lazy dependencies, we need to check both actual instances and factories
    // But for lazy references, we only want to return true if the actual instance exists
    return targetScope.hasDependency<T>(tag: tag) ||
        (targetScope.parent != null && exists<T>(tag: tag, scope: targetScope.parent));
  }

  /// Check if a factory exists for a type without initializing it
  static bool hasFactory<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.hasFactory<T>(tag: tag) ||
        (targetScope.parent != null && hasFactory<T>(tag: tag, scope: targetScope.parent));
  }

  //
  // USAGE TRACKING
  //

  /// Increment use count for a controller or dependency
  static int incrementUseCount<T>({
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.incrementUseCount<T>(tag: tag);
  }

  /// Decrement use count for a controller or dependency
  static int decrementUseCount<T>({
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.decrementUseCount<T>(tag: tag);
  }

  /// Get current use count for a controller or dependency
  static int getUseCount<T>({
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.getUseCount<T>(tag: tag);
  }

  //
  // REACTIVE SYSTEM
  //

  /// Listen to changes for a specific type and tag
  static ZenSubscription listen<T>(
      dynamic provider,
      void Function(T) listener,
      ) {
    return reactiveSystem.listen<T>(provider, listener);
  }

  //
  // REACTIVE VALUES
  //

  /// Create a reactive value of the specified type
  static Rx<T> rx<T>(T initialValue) {
    return Rx<T>(initialValue);
  }

  /// Create a reactive integer
  static RxInt rxInt([int initialValue = 0]) => RxInt(initialValue);

  /// Create a reactive double
  static RxDouble rxDouble([double initialValue = 0.0]) => RxDouble(initialValue);

  /// Create a reactive string
  static RxString rxString([String initialValue = '']) => RxString(initialValue);

  /// Create a reactive boolean
  static RxBool rxBool([bool initialValue = false]) => RxBool(initialValue);

  //
  // SCOPE HELPERS
  //

  /// Create a helper for working with a specific scope
  static ZenScopeHelper withScope(ZenScope scope) {
    return ZenScopeHelper(scope);
  }

  //
  // MODULE REGISTRATION
  //

  /// Register modules in a scope
  static void registerModules(List<ZenModule> modules, {
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;

    for (final module in modules) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Registering module: ${module.name}');
      }

      // Register the module in the registry with the current scope
      ZenModuleRegistry.register(module, scope: targetScope);
    }
  }

  //
  // MANAGEMENT METHODS
  //

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

  /// Find any dependency by Type object at runtime (not just at compile time)
  static dynamic findByType(Type type, {
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.findByType(type, tag: tag);
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

  /// Clean up resources when app is terminating
  static void dispose() {
    lifecycleManager.dispose();
    container.clear();
    reactiveSystem.clearListeners();
    scopeManager.dispose();
  }
}

/// Helper class for working with a specific scope
class ZenScopeHelper {
  final ZenScope scope;

  ZenScopeHelper(this.scope);

  /// Register an instance in this scope
  T put<T>(T instance, {
    String? tag,
    bool permanent = false,
    List<dynamic> dependencies = const [],
  }) {
    return Zen.put<T>(
      instance,
      tag: tag,
      permanent: permanent,
      dependencies: dependencies,
      scope: scope,
    );
  }

  /// Find an instance in this scope
  T? find<T>({String? tag}) {
    return Zen.find<T>(tag: tag, scope: scope);
  }

  /// Get an instance from this scope
  T get<T>({String? tag}) {
    return Zen.get<T>(tag: tag, scope: scope);
  }

  /// Delete an instance from this scope
  bool delete<T>({String? tag, bool force = false}) {
    return Zen.delete<T>(tag: tag, force: force, scope: scope);
  }

  /// Register a factory in this scope
  void lazyPut<T>(T Function() factory, {
    String? tag,
    bool permanent = false,
  }) {
    Zen.lazyPut<T>(
      factory,
      tag: tag,
      permanent: permanent,
      scope: scope,
    );
  }
}