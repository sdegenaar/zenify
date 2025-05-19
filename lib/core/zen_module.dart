// lib/core/zen_module.dart
import 'zen_scope.dart';
import 'zen_logger.dart';
import 'zen_config.dart';

/// Abstract class for organizing related dependencies into modules
///
/// Modules can declare dependencies, register controllers and providers,
/// and specify dependencies on other modules
abstract class ZenModule {
  /// Unique name for the module
  String get name;

  /// List of modules this module depends on
  List<ZenModule> get dependencies => const [];

  /// Register all dependencies in this module
  ///
  /// This method is called when the module is loaded
  void register(ZenScope scope);

  /// Called when the module is loaded
  ///
  /// Override to perform any initialization logic
  void onInit(ZenScope scope) {}

  /// Called when the module is unloaded
  ///
  /// Override to perform any cleanup logic
  void onDispose(ZenScope scope) {}

  @override
  String toString() => 'ZenModule($name)';
}

/// Registry for all modules in the application
class ZenModuleRegistry {
  ZenModuleRegistry._();

  /// Registered modules by name
  static final Map<String, ZenModule> _modules = {};

  /// Map of module dependencies (for cycle detection)
  static final Map<String, Set<String>> _dependencyGraph = {};

  /// Register a module
  static void register(ZenModule module, {ZenScope? scope}) {
    final moduleName = module.name;

    if (_modules.containsKey(moduleName)) {
      ZenLogger.logWarning('Module "$moduleName" is being overwritten');
    }

    _modules[moduleName] = module;

    // Record dependencies for cycle detection
    final dependencyNames = module.dependencies.map((dep) => dep.name).toSet();
    _dependencyGraph[moduleName] = dependencyNames;

    if (_detectCycles(moduleName)) {
      _modules.remove(moduleName);
      _dependencyGraph.remove(moduleName);
      throw StateError('Circular dependency detected in module "$moduleName"');
    }

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Registered module: $module');
    }

    // If scope is provided, immediately load the module into that scope
    if (scope != null) {
      _loadModule(module, scope, <String>{});
    }
  }

  /// Load a module and its dependencies into a scope
  static void load(String moduleName, ZenScope scope) {
    if (!_modules.containsKey(moduleName)) {
      throw ArgumentError('Module "$moduleName" is not registered');
    }

    final module = _modules[moduleName]!;
    _loadModule(module, scope, <String>{});
  }

  /// Load all registered modules into a scope
  static void loadAll(ZenScope scope) {
    final loadedModules = <String>{};

    for (final module in _modules.values) {
      _loadModule(module, scope, loadedModules);
    }
  }

  /// Get a registered module by name
  static ZenModule? get(String name) {
    return _modules[name];
  }

  /// Check if a module is registered
  static bool hasModule(String name) {
    return _modules.containsKey(name);
  }

  /// Get all registered modules
  static Map<String, ZenModule> getAll() {
    return Map.unmodifiable(_modules);
  }

  /// Recursively load a module and its dependencies
  static void _loadModule(ZenModule module, ZenScope scope, Set<String> loadedModules) {
    final moduleName = module.name;

    // Skip if already loaded
    if (loadedModules.contains(moduleName)) {
      return;
    }

    // Load dependencies first
    for (final dependency in module.dependencies) {
      _loadModule(dependency, scope, loadedModules);
    }

    // Register module dependencies
    module.register(scope);

    // Initialize module
    module.onInit(scope);

    // Mark as loaded
    loadedModules.add(moduleName);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Loaded module: $module');
    }
  }

  /// Detect circular dependencies in modules
  /// Uses DFS to detect cycles in the dependency graph
  static bool _detectCycles(String start) {
    final visited = <String>{};
    final recursionStack = <String>{};

    bool dfs(String current) {
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
            ZenLogger.logError('Circular module dependency detected: $current -> $dependency creates a cycle');
          }
          return true;
        }
      }

      recursionStack.remove(current);
      return false;
    }

    return dfs(start);
  }
}