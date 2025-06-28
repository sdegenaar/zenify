// lib/debug/zen_hierarchy_debug.dart
import 'package:zenify/core/core.dart';

import '../di/zen_di.dart';
import '../utils/zen_scope_inspector.dart';

/// Debug utilities for building and analyzing Zen scope hierarchies
/// Contains debug-specific functionality like dumping and visualization
class ZenHierarchyDebug {

  /// Build a complete hierarchy tree starting from root
  static Map<String, dynamic> buildHierarchyTree([ZenScope? startScope]) {
    final scope = startScope ?? Zen.rootScope;

    return {
      'scope': ZenScopeInspector.toDebugMap(scope),
      'children': scope.childScopes
          .map((child) => buildHierarchyTree(child))
          .toList(),
    };
  }

  /// Get comprehensive hierarchy information
  static Map<String, dynamic> getCompleteHierarchyInfo() {
    final rootScope = Zen.rootScope;
    final allScopes = ZenScopeManager.getAllScopes();

    return {
      'currentScope': ZenScopeInspector.toDebugMap(Zen.currentScope),
      'rootScope': ZenScopeInspector.toDebugMap(rootScope),
      'hierarchy': buildHierarchyTree(rootScope),
      'scopeStats': {
        'totalScopes': allScopes.length,
        'activeScopes': allScopes.where((s) => !s.isDisposed).length,
        'disposedScopes': allScopes.where((s) => s.isDisposed).length,
      },
    };
  }

  /// Dump the complete hierarchy as a formatted string
  static String dumpCompleteHierarchy() {
    final buffer = StringBuffer();
    final rootScope = Zen.rootScope;

    buffer.writeln('=== ZEN SCOPE HIERARCHY ===');
    buffer.writeln();

    _dumpScopeRecursively(rootScope, buffer, 0);

    return buffer.toString();
  }

  /// Recursively dump scope information with indentation
  static void _dumpScopeRecursively(ZenScope scope, StringBuffer buffer, int depth) {
    final indent = '  ' * depth;
    final scopeInfo = ZenScopeInspector.toDebugMap(scope);
    final scopeData = scopeInfo['scopeInfo'] as Map<String, dynamic>;
    final dependencies = scopeInfo['dependencies'] as Map<String, dynamic>;

    buffer.writeln('$indent📁 ${scopeData['name']}');
    buffer.writeln('$indent   Status: ${scopeData['disposed'] ? 'Disposed' : 'Active'}');
    buffer.writeln('$indent   Dependencies: ${dependencies['totalDependencies']}');

    if (dependencies['totalDependencies'] > 0) {
      final breakdown = ZenScopeInspector.getDependencyBreakdown(scope);
      final summary = breakdown['summary'] as Map<String, dynamic>;

      if (summary['totalControllers'] > 0) {
        buffer.writeln('$indent   └─ Controllers: ${summary['totalControllers']}');
      }
      if (summary['totalServices'] > 0) {
        buffer.writeln('$indent   └─ Services: ${summary['totalServices']}');
      }
    }

    // Recursively dump child scopes
    for (final child in scope.childScopes) {
      _dumpScopeRecursively(child, buffer, depth + 1);
    }
  }
}