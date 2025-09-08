// lib/di/zen_dependency_analyzer.dart

import '../core/zen_config.dart';
import '../core/zen_logger.dart';
import '../core/zen_scope.dart';

/// Analyzes dependencies for issues like circular references
class ZenDependencyAnalyzer {
  // Singleton instance
  static final ZenDependencyAnalyzer instance = ZenDependencyAnalyzer._();

  // Private constructor
  ZenDependencyAnalyzer._();

  /// Detect circular dependencies across all scopes
  /// Note: Basic implementation - real circular dependency detection would require
  /// analyzing constructor dependencies, which isn't available in the current scope API
  bool detectCycles(dynamic start, List<ZenScope> scopes) {
    try {
      // Safety check - if start is null, there can't be a cycle
      if (start == null) return false;

      // Since we don't have access to actual dependency relationships in the current
      // scope implementation, we can only do basic checks
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug(
            'Cycle detection is limited - requires constructor dependency analysis');
      }

      return false; // No cycles detectable with current API
    } catch (e, stack) {
      ZenLogger.logError('Error in cycle detection', e, stack);
      return true; // Assume cycle exists if error
    }
  }

  /// Generate a report of problematic dependencies
  String detectProblematicDependencies(List<ZenScope> scopes) {
    final buffer = StringBuffer();

    if (!ZenConfig.enableDependencyVisualization) {
      return 'Dependency detection is disabled. Enable it with ZenConfig.enableDependencyVisualization = true';
    }

    buffer.writeln('=== DEPENDENCY ANALYSIS ===\n');
    var problemFound = false;

    // Check for dependencies registered in multiple scopes
    final typeToScopes = <Type, List<ZenScope>>{};
    final instanceToScopes = <String, List<ZenScope>>{};

    for (final scope in scopes) {
      if (scope.isDisposed) continue;

      final deps = scope.findAllOfType<Object>();
      for (final dep in deps) {
        final type = dep.runtimeType;
        final instanceKey = '${type.toString()}_${dep.hashCode}';

        typeToScopes.putIfAbsent(type, () => []).add(scope);
        instanceToScopes.putIfAbsent(instanceKey, () => []).add(scope);
      }
    }

    // Report types registered in multiple scopes
    for (final entry in typeToScopes.entries) {
      if (entry.value.length > 1) {
        buffer.writeln(
            'MULTIPLE REGISTRATIONS: ${entry.key} is registered in multiple scopes:');
        for (final scope in entry.value) {
          buffer.writeln('  - ${scope.name ?? scope.id}');
        }
        problemFound = true;
        buffer.writeln();
      }
    }

    // Check for potential memory leaks (same instance in multiple scopes)
    for (final entry in instanceToScopes.entries) {
      if (entry.value.length > 1) {
        buffer.writeln(
            'POTENTIAL MEMORY LEAK: Same instance registered in multiple scopes:');
        for (final scope in entry.value) {
          buffer.writeln('  - ${scope.name ?? scope.id}');
        }
        problemFound = true;
        buffer.writeln();
      }
    }

    if (!problemFound) {
      buffer.writeln('No problematic dependencies detected');
    }

    buffer.writeln(
        '\nNOTE: Advanced circular dependency detection requires constructor');
    buffer.writeln(
        'dependency analysis, which is not available with the current scope API.');

    return buffer.toString();
  }

  /// Visualize dependency relationships for debugging
  String visualizeDependencyGraph(List<ZenScope> scopes) {
    final buffer = StringBuffer();

    if (!ZenConfig.enableDependencyVisualization) {
      return 'Dependency visualization is disabled. Enable it with ZenConfig.enableDependencyVisualization = true';
    }

    buffer.writeln('=== ZEN DEPENDENCY GRAPH ===\n');

    for (final scope in scopes) {
      if (scope.isDisposed) continue;

      buffer.writeln('SCOPE: ${scope.name ?? scope.id}');
      final dependencies = scope.findAllOfType<Object>();

      if (dependencies.isEmpty) {
        buffer.writeln('  No dependencies registered in this scope\n');
        continue;
      }

      // Group by type for better visualization
      final typeGroups = <Type, List<dynamic>>{};
      for (final instance in dependencies) {
        final type = instance.runtimeType;
        typeGroups.putIfAbsent(type, () => []).add(instance);
      }

      for (final entry in typeGroups.entries) {
        final type = entry.key;
        final instances = entry.value;

        if (instances.length == 1) {
          buffer.writeln('  $type');
        } else {
          buffer.writeln('  $type (${instances.length} instances)');
          for (int i = 0; i < instances.length; i++) {
            buffer.writeln('    [${i + 1}] ${instances[i].hashCode}');
          }
        }
      }
      buffer.writeln();
    }

    buffer.writeln(
        'NOTE: This visualization shows registered dependencies but cannot');
    buffer.writeln(
        'display actual dependency relationships without constructor analysis.');

    return buffer.toString();
  }

  /// Get a summary of all dependencies across scopes
  String getDependencySummary(List<ZenScope> scopes) {
    final buffer = StringBuffer();

    buffer.writeln('=== ZEN DEPENDENCY SUMMARY ===\n');

    var totalDependencies = 0;
    final allTypes = <Type>{};

    for (final scope in scopes) {
      if (scope.isDisposed) continue;

      final deps = scope.findAllOfType<Object>();
      totalDependencies += deps.length;

      for (final dep in deps) {
        allTypes.add(dep.runtimeType);
      }
    }

    buffer
        .writeln('Total Scopes: ${scopes.where((s) => !s.isDisposed).length}');
    buffer.writeln('Total Dependencies: $totalDependencies');
    buffer.writeln('Unique Types: ${allTypes.length}');
    buffer.writeln();

    // List all unique types
    if (allTypes.isNotEmpty) {
      buffer.writeln('Registered Types:');
      final sortedTypes = allTypes.toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      for (final type in sortedTypes) {
        buffer.writeln('  - $type');
      }
    }

    return buffer.toString();
  }

  /// Analyze scope hierarchy
  String analyzeScopeHierarchy(List<ZenScope> scopes) {
    final buffer = StringBuffer();

    buffer.writeln('=== SCOPE HIERARCHY ANALYSIS ===\n');

    // Find root scopes (those without parents)
    final rootScopes =
        scopes.where((s) => s.parent == null && !s.isDisposed).toList();

    if (rootScopes.isEmpty) {
      buffer.writeln('No root scopes found');
      return buffer.toString();
    }

    for (final rootScope in rootScopes) {
      _analyzeScope(rootScope, buffer, 0);
    }

    return buffer.toString();
  }

  void _analyzeScope(ZenScope scope, StringBuffer buffer, int depth) {
    final indent = '  ' * depth;
    final dependencies = scope.findAllOfType<Object>();

    buffer.write('$indent${scope.name ?? scope.id}');
    if (scope.isDisposed) {
      buffer.write(' (DISPOSED)');
    }
    buffer.writeln(' - ${dependencies.length} dependencies');

    // Analyze child scopes
    for (final child in scope.childScopes) {
      _analyzeScope(child, buffer, depth + 1);
    }
  }
}
