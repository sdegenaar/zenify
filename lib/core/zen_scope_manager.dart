import 'package:zenify/core/zen_scope.dart';
import 'package:zenify/core/zen_scope_stack_tracker.dart';
import 'zen_logger.dart';

/// Comprehensive scope manager with lifecycle management and hierarchy navigation
/// Handles both scope creation/disposal and hierarchy traversal operations
class ZenScopeManager {
  static final Map<String, ZenScope> _persistentScopes = {};
  static final Map<String, ZenScope> _autoDisposeScopes = {};
  static final Map<String, Set<String>> _childScopes = {};
  static final Map<String, String?> _parentScopes = {};
  static final Map<String, Set<String>> _activeAutoDisposeChildren = {};
  static final Set<String> _explicitlyPersistentScopes = {};

  static ZenScope? _rootScope;

  static ZenScope get rootScope {
    if (_rootScope == null || _rootScope!.isDisposed) {
      _rootScope = ZenScope(name: 'RootScope');
      ZenLogger.logDebug('🌱 Created root scope: ${_rootScope!.id}');
    }
    return _rootScope!;
  }

  //
  // CORE SCOPE LIFECYCLE MANAGEMENT
  //

  /// Creates or retrieves a scope with intelligent parent-child linking
  ///
  /// Auto-dispose behavior:
  /// - null parent → auto-dispose = true (temporary scope)
  /// - has parent → auto-dispose = false (persistent scope)
  /// - explicit autoDispose → overrides auto-detection
  static ZenScope getOrCreateScope({
    required String name,
    ZenScope? parentScope,
    bool? autoDispose,
    bool useRootAsDefault = false,
  }) {
    // Check for existing scope
    ZenScope? existingScope =
        _persistentScopes[name] ?? _autoDisposeScopes[name];
    if (existingScope != null && !existingScope.isDisposed) {
      final currentParent = existingScope.parent;
      final newParent = parentScope;

      if (currentParent != newParent) {
        ZenLogger.logDebug(
            '🔄 Scope $name exists but parent changed. Recreating scope.');
        _disposeScopeAndCleanup(name, existingScope);
      } else {
        ZenLogger.logDebug('♻️ Reusing existing scope: $name');
        return existingScope;
      }
    } else if (existingScope != null && existingScope.isDisposed) {
      _removeScopeFromTracking(name);
    }

    // Determine effective parent scope
    ZenScope? effectiveParentScope;
    if (parentScope != null) {
      effectiveParentScope = parentScope;
    } else if (useRootAsDefault) {
      effectiveParentScope = rootScope;
    }

    // Determine auto-dispose behavior
    bool effectiveAutoDispose;
    String? effectiveParentName = effectiveParentScope?.name;

    if (autoDispose != null) {
      effectiveAutoDispose = autoDispose;
      if (autoDispose == false) {
        _explicitlyPersistentScopes.add(name);
      }
    } else {
      effectiveAutoDispose = (effectiveParentName == null);
      ZenLogger.logDebug(
          '🎯 Auto-configured scope "$name" with autoDispose=$effectiveAutoDispose');
    }

    // Create new scope
    final newScope = ZenScope(name: name, parent: effectiveParentScope);

    // Track scope
    if (effectiveAutoDispose) {
      _autoDisposeScopes[name] = newScope;
      if (effectiveParentName != null && effectiveParentName != 'RootScope') {
        _parentScopes[name] = effectiveParentName;
        _activeAutoDisposeChildren
            .putIfAbsent(effectiveParentName, () => <String>{})
            .add(name);
      }
      ZenLogger.logDebug('⚡ Created auto-dispose scope: $name');
    } else {
      _persistentScopes[name] = newScope;
      if (effectiveParentName != null && effectiveParentName != 'RootScope') {
        _parentScopes[name] = effectiveParentName;
        _childScopes
            .putIfAbsent(effectiveParentName, () => <String>{})
            .add(name);
      }
      ZenLogger.logDebug('🔒 Created persistent scope: $name');
    }

    return newScope;
  }

  static void _disposeScopeAndCleanup(String scopeName, ZenScope scope) {
    try {
      if (!scope.isDisposed) {
        scope.dispose();
        ZenLogger.logDebug('🗑️ Disposed scope for recreation: $scopeName');
      }
    } catch (e, stackTrace) {
      ZenLogger.logError('Error disposing scope $scopeName', e, stackTrace);
    }
    _removeScopeFromTracking(scopeName);
  }

  /// Clean up all scopes except the specified one and the root scope
  /// This is called when a route with useParentScope=false is created or popped back to
  static void cleanupAllScopesExcept(String keepScopeName) {
    ZenLogger.logDebug('🧹 Cleaning up all scopes except: $keepScopeName');

    // Get all scopes to clean up (exclude root scope and the one to keep)
    final scopesToCleanup = <String>[];

    // Add persistent scopes (excluding root and the one to keep)
    for (final scopeName in _persistentScopes.keys) {
      if (scopeName != keepScopeName && scopeName != 'RootScope') {
        scopesToCleanup.add(scopeName);
      }
    }

    // Add auto-dispose scopes (excluding the one to keep)
    for (final scopeName in _autoDisposeScopes.keys) {
      if (scopeName != keepScopeName) {
        scopesToCleanup.add(scopeName);
      }
    }

    ZenLogger.logDebug('🧹 Scopes to cleanup: ${scopesToCleanup.join(', ')}');

    // Clean up each scope
    for (final scopeName in scopesToCleanup) {
      try {
        // Remove from explicitly persistent if it was there
        _explicitlyPersistentScopes.remove(scopeName);

        // Force dispose the scope
        final persistentScope = _persistentScopes.remove(scopeName);
        final autoDisposeScope = _autoDisposeScopes.remove(scopeName);

        final scope = persistentScope ?? autoDisposeScope;
        if (scope != null && !scope.isDisposed) {
          scope.dispose();
          ZenLogger.logDebug('🗑️ Disposed scope during cleanup: $scopeName');
        }

        // Remove from all tracking
        _removeScopeFromTracking(scopeName);
      } catch (e, stackTrace) {
        ZenLogger.logError('Error cleaning up scope $scopeName', e, stackTrace);
      }
    }

    ZenLogger.logDebug(
        '✅ Cleanup complete. Remaining scopes: ${_getAllScopeNames().join(', ')}');
  }

  /// Clean up only scopes that are tracked in the scope stack
  /// This preserves manually created scopes that aren't part of navigation
  static void cleanupStackTrackedScopesExcept(String keepScopeName) {
    final stackScopes = ZenScopeStackTracker.getCurrentStack();
    final scopesToCleanup =
        stackScopes.where((scopeName) => scopeName != keepScopeName).toList();

    if (scopesToCleanup.isNotEmpty) {
      ZenLogger.logDebug(
          '🧹 Cleaning up stack-tracked scopes: ${scopesToCleanup.join(', ')}');
    }

    for (final scopeName in scopesToCleanup) {
      final scope =
          _persistentScopes[scopeName] ?? _autoDisposeScopes[scopeName];
      if (scope != null && !scope.isDisposed) {
        ZenLogger.logDebug('🗑️ Disposing stack-tracked scope: $scopeName');
        scope.dispose();

        // Remove from tracking maps ONLY after disposal to preserve hierarchy during disposal
        _persistentScopes.remove(scopeName);
        _autoDisposeScopes.remove(scopeName);
        _removeScopeFromTracking(scopeName);
      }
    }
  }

  /// 🔥 NEW: Helper method to get all scope names for debugging
  static List<String> _getAllScopeNames() {
    final names = <String>[];
    names.addAll(_persistentScopes.keys);
    names.addAll(_autoDisposeScopes.keys);
    if (_rootScope != null && !_rootScope!.isDisposed) {
      names.add('RootScope');
    }
    return names;
  }

  /// Called when widget disposes - handles complete disposal logic
  static void onWidgetDispose(String scopeName, bool autoDispose) {
    ZenLogger.logDebug(
        '📤 Widget disposing: $scopeName (autoDispose: $autoDispose)');

    if (autoDispose) {
      // Dispose auto-dispose scope completely
      final scope = _autoDisposeScopes.remove(scopeName);
      if (scope != null && !scope.isDisposed) {
        try {
          scope.dispose();
          ZenLogger.logDebug('🗑️ Disposed auto-dispose scope: $scopeName');
        } catch (e, stackTrace) {
          ZenLogger.logError(
              'Error disposing auto-dispose scope $scopeName', e, stackTrace);
        }
      }

      // Clean up all tracking for auto-dispose scope
      _removeScopeFromTracking(scopeName);
    } else {
      // Handle persistent scope widget disposal
      if (!_explicitlyPersistentScopes.contains(scopeName)) {
        final children = _getRemainingChildren(scopeName);
        if (children.isEmpty) {
          _disposeDirectly(scopeName);
        } else {
          ZenLogger.logDebug(
              '⏳ Keeping scope $scopeName alive (has children: ${children.join(', ')})');
        }
      } else {
        ZenLogger.logDebug(
            '🔒 Persistent scope widget disposed but scope remains: $scopeName');
      }
    }
  }

  static void _disposeDirectly(String scopeName) {
    ZenLogger.logDebug('🗑️ Directly disposing scope: $scopeName');

    final scope = _persistentScopes.remove(scopeName);
    if (scope != null && !scope.isDisposed) {
      try {
        scope.dispose();
        ZenLogger.logDebug('✅ Disposed scope: $scopeName');
      } catch (e, stackTrace) {
        ZenLogger.logError('Error disposing scope $scopeName', e, stackTrace);
      }
    }
    _removeScopeFromTracking(scopeName);
  }

  static Set<String> _getRemainingChildren(String parentScopeName) {
    final children = <String>{};
    children.addAll(_childScopes[parentScopeName] ?? {});
    children.addAll(_activeAutoDisposeChildren[parentScopeName] ?? {});
    return children;
  }

  static ZenScope? getScope(String name) {
    final scope = _persistentScopes[name] ?? _autoDisposeScopes[name];
    // Return null if scope is disposed
    if (scope != null && scope.isDisposed) {
      return null;
    }
    return scope;
  }

  static void disposeAll() {
    ZenLogger.logInfo('🧹 Disposing all scopes');

    // Dispose all persistent scopes
    final persistentToDispose = List<String>.from(_persistentScopes.keys);
    for (final scopeName in persistentToDispose) {
      final scope = _persistentScopes[scopeName];
      if (scope != null && !scope.isDisposed) {
        try {
          scope.dispose();
        } catch (e, stackTrace) {
          ZenLogger.logError(
              'Error disposing persistent scope $scopeName', e, stackTrace);
        }
      }
    }

    // Dispose all auto-dispose scopes
    final autoDisposeToDispose = List<String>.from(_autoDisposeScopes.keys);
    for (final scopeName in autoDisposeToDispose) {
      final scope = _autoDisposeScopes[scopeName];
      if (scope != null && !scope.isDisposed) {
        try {
          scope.dispose();
        } catch (e, stackTrace) {
          ZenLogger.logError(
              'Error disposing auto-dispose scope $scopeName', e, stackTrace);
        }
      }
    }

    // Clear all tracking
    _persistentScopes.clear();
    _autoDisposeScopes.clear();
    _childScopes.clear();
    _parentScopes.clear();
    _activeAutoDisposeChildren.clear();
    _explicitlyPersistentScopes.clear();

    // Dispose root scope
    if (_rootScope != null && !_rootScope!.isDisposed) {
      try {
        _rootScope!.dispose();
      } catch (e, stackTrace) {
        ZenLogger.logError('Error disposing root scope', e, stackTrace);
      }
    }
    _rootScope = null;

    ZenLogger.logInfo('✅ All scopes disposed and tracking cleared');
  }

  //
  // SCOPE REGISTRY AND TRACKING
  //

  /// Get all tracked scopes (persistent + auto-dispose + root)
  /// This ensures we capture both tracked scopes and dynamically created child scopes
  static List<ZenScope> getAllTrackedScopes() {
    final allScopes = <ZenScope>[];

    // Add all persistent scopes
    allScopes.addAll(_persistentScopes.values);

    // Add all auto-dispose scopes
    allScopes.addAll(_autoDisposeScopes.values);

    // Always include root scope if not already tracked
    if (!allScopes.contains(rootScope)) {
      allScopes.add(rootScope);
    }

    return allScopes;
  }

  /// Get all scopes in the system recursively
  /// This is the core method that must properly traverse child scopes
  /// Maintains API compatibility with previous ZenHierarchyManager
  static List<ZenScope> getAllScopes() {
    return getAllTrackedScopes();
  }

  /// Internal method to register child scopes created via createChild()
  static void registerChildScope(ZenScope childScope) {
    final name = childScope.name;

    // Skip registration if name is null
    if (name == null) {
      ZenLogger.logWarning('Cannot register child scope without a name');
      return;
    }

    // Register as auto-dispose scope since it's created on-demand
    _autoDisposeScopes[name] = childScope;

    // Set up parent tracking if parent exists
    if (childScope.parent != null) {
      final parentName = childScope.parent!.name;
      if (parentName != null) {
        _parentScopes[name] = parentName;
        _activeAutoDisposeChildren
            .putIfAbsent(parentName, () => <String>{})
            .add(name);
      }
    }

    ZenLogger.logDebug('📝 Registered child scope: $name');
  }

  //
  // HIERARCHY NAVIGATION METHODS
  //

  /// Find scope by name in the hierarchy
  static ZenScope? findScopeByName(String name) {
    final allScopes = getAllScopes();

    for (final scope in allScopes) {
      if (scope.name == name) {
        return scope;
      }
    }

    return null;
  }

  /// Get hierarchy depth for a specific scope
  static int getScopeDepth(ZenScope targetScope) {
    int depth = 0;
    ZenScope? current = targetScope.parent;

    while (current != null) {
      depth++;
      current = current.parent;
    }

    return depth;
  }

  /// Get all scopes at a specific depth level
  static List<ZenScope> getScopesAtDepth(int depth) {
    final allScopes = getAllScopes();

    return allScopes.where((scope) => getScopeDepth(scope) == depth).toList();
  }

  /// Recursively collect all scopes starting from a given scope
  static void collectScopesRecursively(
      ZenScope scope, List<ZenScope> collection) {
    // Add the current scope
    collection.add(scope);

    // Recursively add all child scopes
    for (final child in scope.childScopes) {
      collectScopesRecursively(child, collection);
    }
  }

  //
  // INSPECTION AND DEBUGGING
  //

  static String debugHierarchy() {
    if (_persistentScopes.isEmpty && _autoDisposeScopes.isEmpty) {
      return 'No scopes being tracked';
    }

    final buffer = StringBuffer();
    buffer.writeln('🏗️ Scope Hierarchy:');

    if (_persistentScopes.isNotEmpty) {
      buffer.writeln('🔒 Persistent Scopes (${_persistentScopes.length}):');
      for (final entry in _persistentScopes.entries) {
        final childCount = _childScopes[entry.key]?.length ?? 0;
        final autoDisposeChildCount =
            _activeAutoDisposeChildren[entry.key]?.length ?? 0;
        final parent = _parentScopes[entry.key] ?? 'root';
        final depCount = entry.value.getAllDependencies().length;
        final isExplicit = _explicitlyPersistentScopes.contains(entry.key);

        buffer.writeln(
            '  📦 ${entry.key} ${isExplicit ? '(explicit)' : '(implicit)'}');
        buffer.writeln('     ├─ Parent: $parent');
        buffer.writeln('     ├─ Dependencies: $depCount');
        buffer.writeln('     ├─ Persistent children: $childCount');
        buffer.writeln('     └─ Auto-dispose children: $autoDisposeChildCount');
      }
    }

    if (_autoDisposeScopes.isNotEmpty) {
      buffer.writeln('⚡ Auto-Dispose Scopes (${_autoDisposeScopes.length}):');
      for (final entry in _autoDisposeScopes.entries) {
        final parent = _parentScopes[entry.key] ?? 'root';
        final depCount = entry.value.getAllDependencies().length;

        buffer.writeln('  ⚡ ${entry.key}');
        buffer.writeln('     ├─ Parent: $parent');
        buffer.writeln('     └─ Dependencies: $depCount');
      }
    }

    return buffer.toString();
  }

  static Map<String, int> getStats() {
    return {
      'persistentScopes': _persistentScopes.length,
      'autoDisposeScopes': _autoDisposeScopes.length,
      'explicitlyPersistentScopes': _explicitlyPersistentScopes.length,
      'totalParentChildRelationships': _parentScopes.length,
    };
  }

  static bool isTracking(String scopeName) {
    return _persistentScopes.containsKey(scopeName) ||
        _autoDisposeScopes.containsKey(scopeName);
  }

  static Set<String> getChildScopes(String parentScopeName) {
    final children = <String>{};
    children.addAll(_childScopes[parentScopeName] ?? {});
    children.addAll(_activeAutoDisposeChildren[parentScopeName] ?? {});
    return children;
  }

  /// Remove scope from all tracking maps
  static void _removeScopeFromTracking(String scopeName) {
    ZenLogger.logDebug('🗑️ Removing scope from tracking: $scopeName');

    // Remove from scope maps
    _persistentScopes.remove(scopeName);
    _autoDisposeScopes.remove(scopeName);

    // Remove from explicit persistence tracking
    _explicitlyPersistentScopes.remove(scopeName);

    // Remove from parent-child relationships
    final parentName = _parentScopes.remove(scopeName);
    if (parentName != null) {
      _childScopes[parentName]?.remove(scopeName);
      _activeAutoDisposeChildren[parentName]?.remove(scopeName);
    }

    // Remove as parent
    _childScopes.remove(scopeName);
    _activeAutoDisposeChildren.remove(scopeName);

    // Remove orphaned entries
    _parentScopes.removeWhere((child, parent) => parent == scopeName);
  }

  static bool isExplicitlyPersistent(String scopeName) {
    return _explicitlyPersistentScopes.contains(scopeName);
  }

  static void forceDispose(String scopeName) {
    ZenLogger.logDebug('🔥 Force disposing scope: $scopeName');

    _explicitlyPersistentScopes.remove(scopeName);
    _disposeDirectly(scopeName);
  }
}
