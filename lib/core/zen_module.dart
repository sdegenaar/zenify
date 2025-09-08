// lib/core/zen_module.dart
import 'zen_scope.dart';
import 'zen_logger.dart';
import 'zen_config.dart';

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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZenModule && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ZenModule(name: $name)';
}

/// Clean module registry - focused on new API only
class ZenModuleRegistry {
  static final Map<String, ZenModule> _modules = {};

  /// Register and load modules atomically with dependency resolution
  static Future<void> registerModules(
      List<ZenModule> modules, ZenScope scope) async {
    if (modules.isEmpty) return;

    // Store original state for rollback
    final originalScopeState = _captureOriginalScopeState(scope);
    final originalModules = Map<String, ZenModule>.from(_modules);

    try {
      // 1. Collect all dependencies
      final allModules = _collectAllDependencies(modules);

      // 2. Validate no circular dependencies (can throw StateError)
      _validateDependencyGraph(allModules);

      // 3. Calculate load order
      final loadOrder = _calculateLoadOrder(allModules);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logInfo(
            'Loading ${loadOrder.length} modules: ${loadOrder.map((m) => m.name).join(' -> ')}');
      }

      // 4. Load modules in dependency order (this can fail)
      for (final module in loadOrder) {
        // Register dependencies (this can throw)
        module.register(scope);

        // Initialize (this can throw)
        await module.onInit(scope);

        // Only add to registry after successful registration and init
        _modules[module.name] = module;

        if (ZenConfig.enableDebugLogs) {
          ZenLogger.logDebug('✅ Loaded: ${module.name}');
        }
      }

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logInfo(
            '✅ Successfully loaded all ${loadOrder.length} modules');
      }
    } catch (error, stackTrace) {
      // Rollback: restore original module registry
      _modules.clear();
      _modules.addAll(originalModules);

      // Rollback: restore original scope state
      _restoreOriginalScopeState(scope, originalScopeState);

      // Log the failure
      ZenLogger.logError('Module registration failed', error, stackTrace);

      // Re-throw original error without wrapping to preserve type
      rethrow;
    }
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
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logInfo('Cleared module registry');
    }
  }

  /// Debug info
  static String dumpModules() {
    if (_modules.isEmpty) return 'No modules registered';

    final buffer = StringBuffer();
    buffer.writeln('Registered Modules (${_modules.length}):');

    for (final module in _modules.values) {
      buffer.writeln('📦 ${module.name}');
      if (module.dependencies.isNotEmpty) {
        buffer.writeln(
            '   ↳ ${module.dependencies.map((d) => d.name).join(', ')}');
      }
    }

    return buffer.toString();
  }

  // =============================================
  // INTERNAL HELPER METHODS
  // =============================================

  /// Capture the original state of a scope for rollback
  static Map<String, dynamic> _captureOriginalScopeState(ZenScope scope) {
    try {
      final dependencies = scope.getAllDependencies();
      final dependencyTypes = <Type, dynamic>{};
      final dependencyTags = <String, dynamic>{};

      for (final dep in dependencies) {
        dependencyTypes[dep.runtimeType] = dep;

        // Try to get tag (scope implementation specific)
        try {
          final tag = scope.getTagForInstance(dep);
          if (tag != null) {
            dependencyTags[tag] = dep;
          }
        } catch (e) {
          // Ignore - tag retrieval not supported
        }
      }

      return {
        'types': dependencyTypes,
        'tags': dependencyTags,
      };
    } catch (e) {
      return {};
    }
  }

  /// Restore the original state of a scope after failure
  static void _restoreOriginalScopeState(
      ZenScope scope, Map<String, dynamic> originalState) {
    try {
      // Clear current dependencies
      final currentDeps = scope.getAllDependencies();
      for (final dep in currentDeps) {
        try {
          scope.deleteByType(dep.runtimeType, force: true);
        } catch (e) {
          // Continue cleanup
        }
      }

      // Restore original dependencies
      final originalTypes = originalState['types'] as Map<Type, dynamic>? ?? {};
      for (final entry in originalTypes.entries) {
        try {
          scope.put(entry.value);
        } catch (e) {
          // Continue restoration
        }
      }
    } catch (e) {
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logWarning('Failed to fully restore scope state: $e');
      }
    }
  }

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
        final depModule = moduleMap[dep.name]!;
        visit(depModule);
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
