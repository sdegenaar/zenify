// lib/debug/zen_system_stats.dart
import 'zen_debug.dart';
import 'package:zenify/core/core.dart';
import 'package:zenify/debug/zen_hierarchy_debug.dart';
import '../utils/zen_scope_inspector.dart';

/// System-wide statistics and analysis utilities
class ZenSystemStats {
  /// Get detailed statistics about the entire Zen system
  /// Useful for monitoring and performance analysis
  static Map<String, dynamic> getSystemStats() {
    final allScopes = ZenDebug.allScopes;
    var totalDependencies = 0;
    var totalControllers = 0;
    var totalServices = 0;

    for (final scope in allScopes) {
      if (scope.isDisposed) continue; // Skip disposed scopes

      final breakdown = ZenScopeInspector.getDependencyBreakdown(scope);
      final summary = breakdown['summary'] as Map<String, dynamic>? ?? {};

      totalDependencies += (summary['grandTotal'] as int?) ?? 0;
      totalControllers += (summary['totalControllers'] as int?) ?? 0;
      totalServices += (summary['totalServices'] as int?) ?? 0;
    }

    final activeScopes = allScopes.where((s) => !s.isDisposed).length;
    final disposedScopes = allScopes.where((s) => s.isDisposed).length;

    return {
      'scopes': {
        'total': allScopes.length,
        'active': activeScopes,
        'disposed': disposedScopes,
      },
      'dependencies': {
        'total': totalDependencies,
        'controllers': totalControllers,
        'services': totalServices,
        'others': totalDependencies - totalControllers - totalServices,
      },
      'performance': {
        'averageDependenciesPerScope': activeScopes > 0
            ? (totalDependencies / activeScopes).toStringAsFixed(2)
            : '0',
      }
    };
  }

  /// Find all instances of a specific type across all scopes
  /// Only searches in active (non-disposed) scopes
  static List<T> findAllInstancesOfType<T>() {
    final results = <T>[];
    final seen = <dynamic>{};

    for (final scope in ZenDebug.allScopes) {
      if (scope.isDisposed) continue; // Skip disposed scopes

      // Get all instances from this specific scope
      final instances = ZenScopeInspector.getAllInstances(scope);

      for (final entry in instances.entries) {
        final instance = entry.value;
        if (instance is T && !seen.contains(instance)) {
          results.add(instance);
          seen.add(instance);
        }
      }
    }

    return results;
  }

  /// Find which scope contains a specific instance
  /// Returns the first scope found that contains the instance
  static ZenScope? findScopeContaining(dynamic instance) {
    for (final scope in ZenDebug.allScopes) {
      if (scope.isDisposed) continue; // Skip disposed scopes

      // Check if this scope contains the instance
      final instances = ZenScopeInspector.getAllInstances(scope);
      if (instances.values.contains(instance)) {
        return scope;
      }
    }
    return null;
  }

  /// Generate a comprehensive system report
  static String generateSystemReport() {
    final buffer = StringBuffer();
    final stats = getSystemStats();

    buffer.writeln('=== ZEN SYSTEM REPORT ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln();

    buffer.writeln('SCOPES:');
    buffer.writeln('  Total: ${stats['scopes']['total']}');
    buffer.writeln('  Active: ${stats['scopes']['active']}');
    buffer.writeln('  Disposed: ${stats['scopes']['disposed']}');
    buffer.writeln();

    buffer.writeln('DEPENDENCIES:');
    buffer.writeln('  Total: ${stats['dependencies']['total']}');
    buffer.writeln('  Controllers: ${stats['dependencies']['controllers']}');
    buffer.writeln('  Services: ${stats['dependencies']['services']}');
    buffer.writeln('  Others: ${stats['dependencies']['others']}');
    buffer.writeln();

    buffer.writeln('PERFORMANCE:');
    buffer.writeln(
        '  Avg Dependencies/Scope: ${stats['performance']['averageDependenciesPerScope']}');
    buffer.writeln();

    buffer.writeln('=== HIERARCHY ===');
    buffer.writeln(ZenHierarchyDebug.dumpCompleteHierarchy());

    return buffer.toString();
  }
}
