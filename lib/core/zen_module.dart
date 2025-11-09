// lib/core/zen_module.dart
import 'zen_scope.dart';
import 'zen_logger.dart';

/// Abstract class for organizing related dependencies into modules
abstract class ZenModule {
  /// Unique name for this module
  String get name;

  /// List of modules this module depends on
  List<ZenModule> get dependencies => const [];

  /// Register all dependencies in this module
  void register(ZenScope scope);

  /// Called after module registration for async initialization
  Future<void> onInit(ZenScope scope) async {}

  /// Called when the module is being disposed
  Future<void> onDispose(ZenScope scope) async {}

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ZenModule && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ZenModule($name)';
}

/// Clean module registry - fail-fast approach
class ZenModuleRegistry {
  static final Map<String, ZenModule> _modules = {};

  /// Register and load modules with dependency resolution
  ///
  /// Validates upfront, then loads in correct order.
  /// Throws immediately on any error - no complex rollback.
  static Future<void> registerModules(
    List<ZenModule> modules,
    ZenScope scope,
  ) async {
    if (modules.isEmpty) return;

    // 1. Collect all dependencies
    final allModules = _collectAllDependencies(modules);

    // 2. Validate - throws if circular dependencies
    _validateDependencyGraph(allModules);

    // 3. Check all module dependencies are available
    for (final module in allModules) {
      for (final dep in module.dependencies) {
        if (!_modules.containsKey(dep.name) &&
            !allModules.any((m) => m.name == dep.name)) {
          throw StateError(
              'Missing dependency: "${dep.name}" required by "${module.name}"');
        }
      }
    }

    // 4. Calculate load order
    final loadOrder = _calculateLoadOrder(allModules);

    ZenLogger.logInfo(
        'Loading ${loadOrder.length} modules: ${loadOrder.map((m) => m.name).join(' → ')}');

    // 5. Load modules in dependency order
    for (final module in loadOrder) {
      // Skip if already loaded
      if (_modules.containsKey(module.name)) {
        ZenLogger.logDebug('⏭️  Skipped (already loaded): ${module.name}');
        continue;
      }

      // Register dependencies
      module.register(scope);

      // Initialize
      await module.onInit(scope);

      // Mark as loaded
      _modules[module.name] = module;

      ZenLogger.logInfo('✅ Loaded: ${module.name}');
    }

    ZenLogger.logInfo('✅ All ${loadOrder.length} modules loaded successfully');
  }

  /// Check if a module is registered
  static bool hasModule(String name) => _modules.containsKey(name);

  /// Get registered module by name
  static ZenModule? getModule(String name) => _modules[name];

  /// Get all registered modules
  static Map<String, ZenModule> getAllModules() => Map.unmodifiable(_modules);

  /// Clear all modules (for testing)
  static void clear() {
    _modules.clear();
    ZenLogger.logInfo('Cleared module registry');
  }

  // =============================================
  // INTERNAL HELPER METHODS
  // =============================================

  /// Collect all dependencies recursively
  static List<ZenModule> _collectAllDependencies(List<ZenModule> modules) {
    final allModules = <String, ZenModule>{};
    final toProcess = <ZenModule>[...modules];

    while (toProcess.isNotEmpty) {
      final module = toProcess.removeAt(0);

      if (allModules.containsKey(module.name)) {
        continue;
      }

      allModules[module.name] = module;

      for (final dep in module.dependencies) {
        if (!allModules.containsKey(dep.name)) {
          toProcess.add(dep);
        }
      }
    }

    return allModules.values.toList();
  }

  /// Validate dependency graph for circular dependencies
  static void _validateDependencyGraph(List<ZenModule> modules) {
    final moduleMap = <String, ZenModule>{};
    for (final module in modules) {
      moduleMap[module.name] = module;
    }

    final visited = <String>{};
    final visiting = <String>{};

    void visit(String moduleName) {
      if (visited.contains(moduleName)) return;

      if (visiting.contains(moduleName)) {
        throw StateError('Circular dependency detected: $moduleName');
      }

      visiting.add(moduleName);

      final module = moduleMap[moduleName];
      if (module != null) {
        for (final dep in module.dependencies) {
          visit(dep.name);
        }
      }

      visiting.remove(moduleName);
      visited.add(moduleName);
    }

    for (final module in modules) {
      visit(module.name);
    }
  }

  /// Calculate load order using topological sort
  static List<ZenModule> _calculateLoadOrder(List<ZenModule> modules) {
    final result = <ZenModule>[];
    final visited = <String>{};
    final moduleMap = <String, ZenModule>{};

    for (final module in modules) {
      moduleMap[module.name] = module;
    }

    void visit(ZenModule module) {
      if (visited.contains(module.name)) return;

      for (final dep in module.dependencies) {
        final depModule = moduleMap[dep.name];
        if (depModule != null) {
          visit(depModule);
        }
      }

      visited.add(module.name);
      result.add(module);
    }

    for (final module in modules) {
      visit(module);
    }

    return result;
  }
}
