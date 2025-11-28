// lib/debug/zen_debug.dart
import '../core/zen_scope.dart';
import '../di/zen_di.dart';
import 'debug.dart';

/// Debugging and introspection utilities
///
/// Separated from main API to keep Zen class clean.
class ZenDebug {
  ZenDebug._();

  /// Get all active scopes starting from root
  ///
  /// This recursively collects all scopes in the hierarchy starting
  /// from the root scope. Scopes created outside the root hierarchy
  /// (standalone scopes) won't be included.
  static List<ZenScope> get allScopes {
    final scopes = <ZenScope>[];
    _collectScopesRecursively(Zen.rootScope, scopes);
    return scopes;
  }

  /// Helper to recursively collect all scopes
  static void _collectScopesRecursively(
      ZenScope scope, List<ZenScope> collection) {
    if (!collection.contains(scope)) {
      collection.add(scope);
      for (final child in scope.childScopes) {
        _collectScopesRecursively(child, collection);
      }
    }
  }

  /// Get comprehensive hierarchy information
  static Map<String, dynamic> getHierarchyInfo() =>
      ZenHierarchyDebug.getCompleteHierarchyInfo();

  /// Get detailed system statistics
  static Map<String, dynamic> getSystemStats() =>
      ZenSystemStats.getSystemStats();

  /// Find all instances of a specific type across all scopes
  static List<T> findAllInstancesOfType<T>() =>
      ZenSystemStats.findAllInstancesOfType<T>();

  /// Find which scope contains a specific instance
  static ZenScope? findScopeContaining(dynamic instance) =>
      ZenSystemStats.findScopeContaining(instance);

  /// Dump scope hierarchy for debugging
  static String dumpScopes() => ZenHierarchyDebug.dumpCompleteHierarchy();

  /// Dump module registry
  static String dumpModules() {
    final buffer = StringBuffer();
    buffer.writeln('=== MODULE REGISTRY ===');

    final modules = Zen.getAllModules();
    buffer.writeln('Total: ${modules.length}');
    buffer.writeln();

    for (final entry in modules.entries) {
      buffer.writeln('📦 ${entry.key}');
      buffer.writeln('   Type: ${entry.value.runtimeType}');
      if (entry.value.dependencies.isNotEmpty) {
        buffer.writeln(
            '   Dependencies: ${entry.value.dependencies.map((d) => d.name).join(', ')}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Generate comprehensive system report
  static String generateSystemReport() => ZenSystemStats.generateSystemReport();
}
