// lib/di/zen_di.dart
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_scope.dart';
import '../core/zen_module.dart';
import '../controllers/zen_controller.dart';
import '../core/zen_scope_manager.dart';
import '../debug/debug.dart';
import 'zen_lifecycle.dart';
import 'zen_reactive.dart';

/// Main Zenify API for dependency injection
/// Enhanced with debugging and introspection capabilities via debug package
/// Clean atomic module system
class Zen {
  Zen._(); // Private constructor

  // Lifecycle management
  static final ZenLifecycleManager _lifecycleManager =
      ZenLifecycleManager.instance;

  // Track the actual current scope (not just root)
  static ZenScope? _currentScope;

  /// Initialize the system
  static void init() {
    // Initialize lifecycle management
    _lifecycleManager.initLifecycleObserver();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('Zen initialized');
    }
  }

  //
  // DEBUGGING & INTROSPECTION METHODS (Using debug package)
  //

  /// Get the current active scope (for debugging and introspection)
  static ZenScope get currentScope =>
      _currentScope ?? ZenScopeManager.rootScope;

  /// Set the current scope (used internally by ZenRoute)
  static void setCurrentScope(ZenScope scope) {
    _currentScope = scope;
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('🔧 Zen.currentScope updated to: ${scope.name}');
    }
  }

  /// Reset current scope to root (useful for cleanup)
  static void resetCurrentScope() {
    _currentScope = null;
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('🔧 Zen.currentScope reset to root');
    }
  }

  /// Get all active scopes in the system (for debugging)
  static List<ZenScope> get allScopes => ZenScopeManager.getAllScopes();

  /// Get comprehensive debugging information about the entire scope hierarchy
  static Map<String, dynamic> getHierarchyInfo() =>
      ZenHierarchyDebug.getCompleteHierarchyInfo();

  /// Get detailed statistics about the entire Zen system
  static Map<String, dynamic> getSystemStats() =>
      ZenSystemStats.getSystemStats();

  /// Find all instances of a specific type across all scopes
  static List<T> findAllInstancesOfType<T>() =>
      ZenSystemStats.findAllInstancesOfType<T>();

  /// Find which scope contains a specific instance
  static ZenScope? findScopeContaining(dynamic instance) =>
      ZenSystemStats.findScopeContaining(instance);

  //
  // MODULE MANAGEMENT (Clean Atomic API)
  //

  /// Register and load modules atomically with auto-dependency resolution
  static Future<void> registerModules(List<ZenModule> modules,
      {ZenScope? scope}) async {
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
    return ZenScopeManager.getOrCreateScope(
      name: name ?? 'Scope_${DateTime.now().millisecondsSinceEpoch}',
      parentScope: parent,
      autoDispose: false,
    );
  }

  /// Get the root scope for global dependencies
  static ZenScope get rootScope {
    return ZenScopeManager.rootScope;
  }

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
  static void putLazy<T>(T Function() factory,
      {String? tag, bool? isPermanent}) {
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
      throw Exception(
          'Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found');
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
  // ENHANCED DEBUGGING UTILITIES (Using debug package)
  //

  /// Dump scope hierarchy for debugging with enhanced formatting
  static String dumpScopes() => ZenHierarchyDebug.dumpCompleteHierarchy();

  /// Dump module registry for debugging with enhanced formatting
  static String dumpModules() {
    final buffer = StringBuffer();
    buffer.writeln('=== ZEN MODULE REGISTRY ===');

    final modules = getAllModules();
    buffer.writeln('Total Modules: ${modules.length}');
    buffer.writeln();

    for (final entry in modules.entries) {
      buffer.writeln('📦 ${entry.key}');
      buffer.writeln('   Type: ${entry.value.runtimeType}');
      buffer.writeln('   Status: Registered');
      buffer.writeln();
    }

    buffer.writeln('=== END MODULE REGISTRY ===');
    return buffer.toString();
  }

  /// Generate a comprehensive system report
  static String generateSystemReport() => ZenSystemStats.generateSystemReport();

  //
  // UTILITIES
  //

  /// Delete all dependencies from all scopes (mainly for testing)
  static void deleteAll({bool force = false}) {
    ZenScopeManager.disposeAll();
  }

  /// Complete reset - clear everything (for testing)
  static void reset() {
    // 1. Clear module registry first
    ZenModuleRegistry.clear();

    // 2. Clear reactive system
    ZenReactiveSystem.instance.clearListeners();

    // 3. Clear lifecycle management
    _lifecycleManager.dispose();

    // 4. Reset current scope tracking
    _currentScope = null;

    // 5. Force clear all scopes
    ZenScopeManager.disposeAll();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('🔄 Zen completely reset');
    }
  }
}
