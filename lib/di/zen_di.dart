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

  /// Get all controllers for lifecycle management
  static List<ZenController> _getAllControllers() {
    final allScopes = scopeManager.getAllScopes();
    final controllers = <ZenController>[];
    for (final scope in allScopes) {
      controllers.addAll(
        scope.findAllOfType<ZenController>(),
      );
    }
    return controllers;
  }

  /// Find the scope containing a controller
  static ZenScope? _findControllerScope(ZenController controller) {
    final allScopes = scopeManager.getAllScopes();
    for (final scope in allScopes) {
      if (scope.containsInstance(controller)) {
        return scope;
      }
    }
    return null;
  }

  //
  // SCOPE MANAGEMENT
  //

  /// Get the global root scope
  static ZenScope get rootScope => scopeManager.rootScope;

  /// Get all controllers in all scopes
  static List<ZenController> get allControllers => _getAllControllers();

  /// Create a new scope with optional parent
  static ZenScope createScope({ZenScope? parent, String? name, String? id}) {
    return scopeManager.createScope(parent: parent, name: name, id: id);
  }

  /// Get the current scope for context-aware operations
  static ZenScope get currentScope => scopeManager.currentScope;

  /// Use a specific scope for subsequent operations
  static void useScope(ZenScope scope) {
    scopeManager.setCurrentScope(scope);
  }

  /// Reset to root scope
  static void resetScope() {
    scopeManager.setCurrentScope(scopeManager.rootScope);
  }

  /// Register modules in a scope
  static void registerModules(List<ZenModule> modules, {ZenScope? scope}) {
    final targetScope = scope ?? currentScope;
    for (final module in modules) {
      module.register(targetScope);
      module.onInit(targetScope);
    }
  }

  //
  // CORE API (GETX COMPATIBLE)
  //

  /// Register a dependency or controller instance
  ///
  /// Compatible with GetX's put() method
  static T put<T>(
      T instance, {
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
      reactiveSystem.notifyListeners<T>(tag);

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
      reactiveSystem.notifyListeners<T>(tag);

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
  ///
  /// Compatible with GetX's lazyPut() method
  static void lazyPut<T>(
      T Function() factory, {
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

  /// Register a factory that creates a new instance each time
  ///
  /// Compatible with GetX's create() method
  static void create<T>(
      T Function() factory, {
        String? tag,
        ZenScope? scope,
      }) {
    final targetScope = scope ?? scopeManager.currentScope;
    targetScope.putFactory<T>(factory, tag: tag);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  /// Find a dependency by type (throws if not found)
  ///
  /// Compatible with GetX's find() method
  /// This is the primary method for retrieving dependencies that are expected to exist.
  /// It throws an exception if the dependency isn't found.
  /// Will instantiate lazy dependencies if they exist.
  static T find<T>({
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;
    final result = targetScope.find<T>(tag: tag);

    if (result == null) {
      throw Exception('Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found');
    }

    return result;
  }

  /// Find a dependency by type, returning null if not found
  ///
  /// Use this method when the dependency might legitimately be absent
  /// and you want to handle that case explicitly.
  /// This method will NOT instantiate lazy dependencies.
  static T? findOrNull<T>({
    String? tag,
    ZenScope? scope,
  }) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.findInstanceOnly<T>(tag: tag);
  }

  /// Find a dependency by type with fallback option
  ///
  /// This is useful when you want to provide a default value if the dependency doesn't exist.
  /// This method will NOT instantiate lazy dependencies when using the fallback.
  static T findOr<T>({
    String? tag,
    ZenScope? scope,
    required T Function() orElse,
  }) {
    final result = findOrNull<T>(tag: tag, scope: scope);
    return result ?? orElse();
  }

  /// Delete an instance by type
  ///
  /// Compatible with GetX's delete() method
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
      final factoryKey = container.getKey(T, tag);
      container.removeFactory(factoryKey);
      reactiveSystem.notifyListeners<T>(tag);
    }

    return deleted;
  }

  /// Delete all dependencies from all scopes
  ///
  /// This is primarily used for testing and should be used with caution
  /// in production code. It wipes out all dependencies across all scopes.
  static void deleteAll({bool force = false}) {
    // Get all scopes
    final allScopes = scopeManager.getAllScopes();

    // For each scope, get all dependencies and delete them
    for (final scope in allScopes) {
      // Skip if the scope is already disposed
      if (scope.isDisposed) continue;

      // Get all controllers and dependencies
      final dependencies = scope.getAllDependencies();

      // For each dependency, get its type and tag and delete it
      for (final dependency in dependencies) {
        final type = dependency.runtimeType;
        final tag = scope.getTagForInstance(dependency);

        if (tag != null) {
          // Delete by tag
          scope.deleteByTag(tag, force: force);
        } else {
          // Delete by type
          scope.deleteByType(type, force: force);
        }
      }
    }

    // Clear all factories and instances from the container
    container.clear();

    // Clear all listeners in the reactive system
    reactiveSystem.clearListeners();

    // Log the cleanup if debug logs are enabled
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Deleted all dependencies from all scopes');
    }
  }

  /// Delete a dependency by runtime type (for route-based auto-disposal)
  ///
  /// Used by ZenRouteObserver and lifecycle management
  static bool deleteByType(Type type, {bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.currentScope;

    // Delete from scope
    bool deleted = targetScope.deleteByType(type, force: force);

    // If deleted, also notify reactive system
    if (deleted && ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Deleted dependency of type $type by runtime type');
    }

    return deleted;
  }

  /// Delete a dependency by tag (for tag-based dependency management)
  ///
  /// Used by ZenRouteObserver for tag-based routing
  static bool deleteByTag(String tag, {bool force = false, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.currentScope;

    // Delete from scope
    bool deleted = targetScope.deleteByTag(tag, force: force);

    // Log if needed
    if (deleted && ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Deleted dependency with tag $tag');
    }

    return deleted;
  }

  /// Replace a dependency instance
  ///
  /// Compatible with GetX's replace() method
  static void replace<T>(T instance, {String? tag}) {
    // Delete first (force true to ensure replacement)
    delete<T>(tag: tag, force: true);

    // Then register the new instance
    put<T>(instance, tag: tag);
  }

  //
  // REFERENCE SYSTEM
  //

  /// Access the dependency reference system
  /// Returns a type-safe reference to a registered dependency
  static EagerRef<T> ref<T>({String? tag, ZenScope? scope}) {
    return EagerRef<T>(tag: tag, scope: scope ?? currentScope);
  }

  /// Access a controller reference (for ZenController types)
  static ControllerRef<T> controllerRef<T extends ZenController>({String? tag, ZenScope? scope}) {
    return ControllerRef<T>(tag: tag, scope: scope ?? currentScope);
  }

  /// Register a dependency and immediately return a reference to it
  /// For regular dependencies (non-controllers)
  static Ref<T> putRef<T>(
      T instance, {
        String? tag,
        bool permanent = false,
        List<dynamic> dependencies = const [],
        ZenScope? scope,
      }) {
    put<T>(instance, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return ref<T>(tag: tag, scope: scope);
  }

  /// Register a controller and immediately return a controller reference
  /// For controllers only
  static ControllerRef<T> putControllerRef<T extends ZenController>(
      T controller, {
        String? tag,
        bool permanent = false,
        List<dynamic> dependencies = const [],
        ZenScope? scope,
      }) {
    put<T>(controller, tag: tag, permanent: permanent, dependencies: dependencies, scope: scope);
    return controllerRef<T>(tag: tag, scope: scope);
  }

  /// Register a lazy factory and return a reference
  /// Useful for dependencies that should only be created when needed
  static LazyRef<T> lazyRef<T>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
      }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return LazyRef<T>(tag: tag, scope: scope ?? currentScope);
  }

  /// Register a lazy controller factory and return a controller reference
  static LazyControllerRef<T> lazyControllerRef<T extends ZenController>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
        ZenScope? scope,
      }) {
    lazyPut<T>(factory, tag: tag, permanent: permanent, scope: scope);
    return LazyControllerRef<T>(tag: tag, scope: scope ?? currentScope);
  }

  //
  // ADVANCED FEATURES
  //

  /// Check if a dependency exists (either as an instance or factory)
  static bool isRegistered<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? currentScope;
    return targetScope.contains<T>(tag: tag);
  }

  /// Check if a lazy dependency is registered but not yet instantiated
  ///
  /// This method can be used to verify that a lazy dependency is properly
  /// registered without triggering its instantiation.
  static bool isLazyRegistered<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? currentScope;
    return targetScope.hasFactory<T>(tag: tag) && !targetScope.hasDependency<T>(tag: tag);
  }

  /// Check if a dependency instance already exists (not just registered as lazy)
  static bool hasInstance<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? currentScope;
    return targetScope.hasDependency<T>(tag: tag);
  }

  /// Increment use count for a dependency (for manual reference counting)
  static int incrementUseCount<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.incrementUseCount<T>(tag: tag);
  }

  /// Decrement use count for a dependency (for manual reference counting)
  static int decrementUseCount<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.decrementUseCount<T>(tag: tag);
  }

  /// Get the current use count for a dependency
  static int getUseCount<T>({String? tag, ZenScope? scope}) {
    final targetScope = scope ?? scopeManager.currentScope;
    return targetScope.getUseCount<T>(tag: tag);
  }
}