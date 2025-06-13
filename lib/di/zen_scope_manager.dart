
// lib/di/zen_scope_manager.dart
import 'package:flutter/foundation.dart';
import '../core/zen_scope.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';

/// Manages hierarchical scopes for dependency injection
class ZenScopeManager {
  // Singleton instance
  static final ZenScopeManager instance = ZenScopeManager._();

  // Root scope for the application
  late ZenScope _rootScope;

  // Map of scope IDs to scopes for faster lookups
  final Map<String, ZenScope> _scopesById = {};

  // Map of scope names to scopes for faster lookups
  final Map<String, List<ZenScope>> _scopesByName = {};

  // Private constructor for singleton
  ZenScopeManager._() {
    _rootScope = ZenScope(name: 'RootScope');
    _registerScopeInMaps(_rootScope);
  }

  /// Get the root scope
  ZenScope get rootScope => _rootScope;

  /// Initializes or reinitializes the scope manager
  void initialize() {
    // Dispose existing root scope if it exists
    try {
      if (!_rootScope.isDisposed) {
        _rootScope.dispose();
      }
    } catch (e) {
      // Ignore any errors during disposal
    }

    // Clear scope maps
    _scopesById.clear();
    _scopesByName.clear();

    // Create a new root scope
    _rootScope = ZenScope(name: 'RootScope');
    _registerScopeInMaps(_rootScope);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ZenScopeManager initialized with root scope: ${_rootScope.id}');
    }
  }

  /// Create a new scope with optional parent
  ZenScope createScope({String? name, ZenScope? parent}) {
    final scope = ZenScope(
      parent: parent ?? _rootScope,
      name: name,
    );

    // Register in lookup maps
    _registerScopeInMaps(scope);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Created scope: ${scope.name} (${scope.id}) with parent: ${scope.parent?.name}');
    }

    return scope;
  }

  /// Register a scope in the lookup maps
  void _registerScopeInMaps(ZenScope scope) {
    // Add to ID map
    _scopesById[scope.id] = scope;

    // Add to name map
    if (scope.name != null) {
      _scopesByName.putIfAbsent(scope.name!, () => []).add(scope);
    }

    // Clean up when the scope is disposed
    scope.registerDisposer(() {
      _scopesById.remove(scope.id);
      if (scope.name != null) {
        final nameList = _scopesByName[scope.name!];
        nameList?.remove(scope);
        if (nameList?.isEmpty ?? false) {
          _scopesByName.remove(scope.name);
        }
      }
    });
  }

  /// Find a scope by ID
  ZenScope? findScopeById(String id) {
    return _scopesById[id];
  }

  /// Find scopes by name (may return multiple)
  List<ZenScope> findScopesByName(String name) {
    return _scopesByName[name] ?? const [];
  }

  /// Delete all dependencies from all scopes
  void deleteAll({bool force = false}) {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Deleting all dependencies across all scopes${force ? ' (forced)' : ''}');
    }

    final allScopes = getAllScopes();

    for (final scope in allScopes) {
      if (!scope.isDisposed) {
        scope.clearAll(force: force);
      }
    }

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Finished deleting all dependencies');
    }
  }

  /// Get all scopes in the hierarchy
  List<ZenScope> getAllScopes() {
    return _scopesById.values.toList();
  }

  /// Create a hierarchical dump of scopes for debugging
  String dumpScopeHierarchy() {
    final buffer = StringBuffer();

    void dumpScope(ZenScope scope, int depth) {
      final indent = '  ' * depth;
      final dependencyCount = scope.getAllDependencies().length;
      buffer.writeln('$indent- ${scope.name} (${scope.id}): $dependencyCount dependencies');

      for (final child in scope.childScopes) {
        dumpScope(child, depth + 1);
      }
    }

    dumpScope(_rootScope, 0);
    return buffer.toString();
  }

  /// Dispose all scopes
  @mustCallSuper
  void dispose() {
    if (!_rootScope.isDisposed) {
      _rootScope.dispose();
    }

    // Ensure maps are cleared in case some callbacks failed
    _scopesById.clear();
    _scopesByName.clear();
  }
}