// lib/di/zen_dependency_analyzer.dart

import '../core/zen_config.dart';
import '../core/zen_logger.dart';
import '../core/zen_scope.dart';

/// Analyzes dependencies for issues like circular references
class ZenDependencyAnalyzer {
  /// Detect circular dependencies across all scopes
  bool detectCycles(dynamic start, List<ZenScope> scopes) {
    try {
      // Safety check - if start is null, there can't be a cycle
      if (start == null) return false;

      final visited = <dynamic>{};
      final recursionStack = <dynamic>{};

      // Helper function for recursion
      bool detectCyclesRecursive(dynamic current) {
        // Safety check
        if (current == null) return false;

        // Depth limiter
        if (recursionStack.length > 100) {
          ZenLogger.logWarning('Cycle detection reached depth limit - possible deep circular reference');
          return true;
        }

        // If already in stack, we found a cycle
        if (recursionStack.contains(current)) {
          return true;
        }

        // If already visited and no cycle found, skip
        if (visited.contains(current)) {
          return false;
        }

        visited.add(current);
        recursionStack.add(current);

        // Check dependencies in all scopes
        for (final scope in scopes) {
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

    // Check for circular dependencies
    for (final scope in scopes) {
      final allDeps = scope.findAllOfType<Object>();

      for (final dep in allDeps) {
        if (detectCycles(dep, scopes)) {
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
    for (final scope in scopes) {
      final deps = scope.findAllOfType<Object>();
      for (final dep in deps) {
        final type = dep.runtimeType;
        typeToScopes.putIfAbsent(type, () => []).add(scope);
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

    if (!problemFound) {
      buffer.writeln('No problematic dependencies detected');
    }

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
      buffer.writeln('SCOPE: ${scope.name ?? scope.id}');
      final dependencies = scope.findAllOfType<Object>();

      if (dependencies.isEmpty) {
        buffer.writeln('  No dependencies registered in this scope\n');
        continue;
      }

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

    return buffer.toString();
  }
}