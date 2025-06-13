

// lib/di/zen_di.dart
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_scope.dart';
import '../core/zen_module.dart';
import '../controllers/zen_controller.dart';
import 'zen_scope_manager.dart';
import 'zen_lifecycle.dart';
import 'zen_reactive.dart';

/// Main Zenify API for dependency injection
/// Clean atomic module system - no legacy cruft
class Zen {
  Zen._(); // Private constructor

  // Scope management
  static final ZenScopeManager _scopeManager = ZenScopeManager.instance;

  // Lifecycle management
  static final ZenLifecycleManager _lifecycleManager = ZenLifecycleManager.instance;

  /// Initialize the system
  static void init() {
    _scopeManager.initialize();

    // Initialize lifecycle management
    _lifecycleManager.initLifecycleObserver();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('Zen initialized');
    }
  }

  //
  // MODULE MANAGEMENT (Clean Atomic API)
  //

  /// Register and load modules atomically with auto-dependency resolution
  static Future<void> registerModules(List<ZenModule> modules, {ZenScope? scope}) async {
    final targetScope = scope ?? rootScope;
    await ZenModuleRegistry.registerModules(modules, targetScope);
  }

  /// Get a registered module by name
  static ZenModule? getModule(String name) {
    return ZenModuleRegistry.getModule(name);
  }

  /// Check if a module is registered
  static bool hasModule(String name) {
    return ZenModuleRegistry.hasModule(name);
  }

  /// Get all registered modules
  static Map<String, ZenModule> getAllModules() {
    return ZenModuleRegistry.getAllModules();
  }

  //
  // SCOPE CREATION (Primary API)
  //

  /// Create a new scope - the main way to work with dependencies
  static ZenScope createScope({String? name, ZenScope? parent}) {
    return _scopeManager.createScope(
      name: name,
      parent: parent,
    );
  }

  /// Get the root scope for global dependencies
  static ZenScope get rootScope => _scopeManager.rootScope;

  //
  // ROOT SCOPE CONVENIENCE METHODS
  //

  /// Register a dependency in the root scope (convenience method)
  static T put<T>(T instance, {String? tag, bool? isPermanent}) {
    final permanent = isPermanent ?? false;

    final result = rootScope.put<T>(
      instance,
      tag: tag,
      permanent: permanent,
    );

    // Initialize controller lifecycle if it's a controller
    if (instance is ZenController) {
      _lifecycleManager.initializeController(instance);
    }

    return result;
  }

  /// Register a lazy factory in root scope
  static void putLazy<T>(T Function() factory, {String? tag, bool? isPermanent}) {
    final permanent = isPermanent ?? false;
    rootScope.putLazy<T>(factory, tag: tag, isPermanent: permanent);
  }

  /// Register a factory in root scope
  static void putFactory<T>(T Function() factory, {String? tag}) {
    rootScope.putFactory<T>(factory, tag: tag);
  }

  /// Find a dependency in root scope (throws if not found)
  static T find<T>({String? tag}) {
    final result = rootScope.find<T>(tag: tag);
    if (result == null) {
      throw Exception('Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found');
    }
    return result;
  }

  /// Find a dependency in root scope, return null if not found
  static T? findOrNull<T>({String? tag}) {
    return rootScope.find<T>(tag: tag);
  }

  /// Check if a dependency exists in root scope
  static bool exists<T>({String? tag}) {
    return rootScope.exists<T>(tag: tag);
  }

  /// Delete a dependency from root scope
  static bool delete<T>({String? tag, bool force = false}) {
    return rootScope.delete<T>(tag: tag, force: force);
  }

  //
  // UTILITIES
  //

  /// Delete all dependencies from all scopes (mainly for testing)
  static void deleteAll({bool force = false}) {
    _scopeManager.deleteAll(force: force);
  }

  /// Complete reset - clear everything (for testing)
  static void reset() {
    // 1. Clear module registry first
    ZenModuleRegistry.clear();

    // 2. Clear reactive system
    ZenReactiveSystem.instance.clearListeners();

    // 3. Clear lifecycle management
    _lifecycleManager.dispose();

    // 4. Force clear all scopes and recreate scope manager
    _scopeManager.dispose();

    // 5. Reinitialize everything
    _scopeManager.initialize();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('🔄 Zen completely reset');
    }
  }

  /// Dump scope hierarchy for debugging
  static String dumpScopes() {
    return _scopeManager.dumpScopeHierarchy();
  }

  /// Dump module registry for debugging
  static String dumpModules() {
    return ZenModuleRegistry.dumpModules();
  }
}