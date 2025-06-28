// lib/debug/zen_scope_inspector.dart
import '../core/zen_scope.dart';
import '../controllers/zen_controller.dart';

/// Debugging and introspection utilities for ZenScope
/// Separated from core functionality to keep ZenScope clean
class ZenScopeInspector {

  /// Get all instances registered in a scope (for debugging and introspection)
  /// Returns a map of Type -> instance for easy inspection
  static Map<Type, dynamic> getAllInstances(ZenScope scope) {
    if (scope.isDisposed) {
      return <Type, dynamic>{};
    }

    final instances = <Type, dynamic>{};

    // We need to access the private members, so we'll add these as methods to ZenScope
    // For now, let's use the existing getAllDependencies method and enhance it
    final dependencies = scope.getAllDependencies();

    for (final instance in dependencies) {
      instances[instance.runtimeType] = instance;
    }

    return Map.unmodifiable(instances);
  }

  /// Get all registered types (including tagged instances)
  /// Useful for debugging what types are available in a scope
  static List<Type> getRegisteredTypes(ZenScope scope) {
    if (scope.isDisposed) {
      return <Type>[];
    }

    final types = <Type>{};
    final dependencies = scope.getAllDependencies();

    for (final instance in dependencies) {
      types.add(instance.runtimeType);
    }

    return types.toList();
  }

  /// Get comprehensive debugging information about a scope
  /// Perfect for DevTools integration or debug logs
  static Map<String, dynamic> toDebugMap(ZenScope scope) {
    final dependencies = scope.getAllDependencies();

    return {
      'scopeInfo': {
        'name': scope.name ?? 'unnamed',
        'id': scope.id,
        'disposed': scope.isDisposed,
        'hasParent': scope.parent != null,
        'parentName': scope.parent?.name,
        'childCount': scope.childScopes.length,
      },
      'dependencies': {
        'totalDependencies': dependencies.length,
      },
      'registeredTypes': getRegisteredTypes(scope).map((t) => t.toString()).toList(),
      'children': scope.childScopes.map((child) => {
        'name': child.name ?? 'unnamed',
        'id': child.id,
        'dependencyCount': child.getAllDependencies().length,
      }).toList(),
    };
  }

  /// Get a detailed breakdown of dependencies by category
  /// Useful for understanding what's in your scope
  static Map<String, dynamic> getDependencyBreakdown(ZenScope scope) {
    if (scope.isDisposed) {
      return {'error': 'Scope is disposed'};
    }

    final controllers = <String>[];
    final services = <String>[];
    final others = <String>[];

    final dependencies = scope.getAllDependencies();

    // Categorize dependencies
    for (final instance in dependencies) {
      final typeName = instance.runtimeType.toString();
      if (instance is ZenController) {
        controllers.add(typeName);
      } else if (typeName.toLowerCase().contains('service')) {
        services.add(typeName);
      } else {
        others.add(typeName);
      }
    }

    return {
      'controllers': controllers,
      'services': services,
      'others': others,
      'summary': {
        'totalControllers': controllers.length,
        'totalServices': services.length,
        'totalOthers': others.length,
        'grandTotal': controllers.length + services.length + others.length,
      }
    };
  }

  /// Find the path from root scope to a given scope
  /// Useful for understanding scope hierarchy
  static List<String> getScopePath(ZenScope scope) {
    final path = <String>[];
    ZenScope? current = scope;

    while (current != null) {
      path.insert(0, current.name ?? current.id);
      current = current.parent;
    }

    return path;
  }

  /// Recursively dump scope information with proper indentation
  static void dumpScope(ZenScope scope, StringBuffer buffer, int indent) {
    final indentStr = '  ' * indent;
    final dependencies = scope.getAllDependencies();

    buffer.writeln('$indentStr📁 ${scope.name ?? 'unnamed'} (${scope.id})');
    buffer.writeln('$indentStr   Dependencies: ${dependencies.length}');
    buffer.writeln('$indentStr   Disposed: ${scope.isDisposed}');

    if (dependencies.isNotEmpty) {
      final types = dependencies.map((d) => d.runtimeType.toString()).toSet();
      buffer.writeln('$indentStr   Types: ${types.join(', ')}');
    }

    // Recursively dump child scopes
    for (final child in scope.childScopes) {
      dumpScope(child, buffer, indent + 1);
    }
  }
}