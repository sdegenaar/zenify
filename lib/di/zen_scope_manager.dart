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

  // Current scope (used as default when not specified)
  late ZenScope _currentScope;

  // Map of scope IDs to scopes for faster lookups
  final Map<String, ZenScope> _scopesById = {};

  // Map of scope names to scopes for faster lookups
  final Map<String, List<ZenScope>> _scopesByName = {};

  // Private constructor for singleton
  ZenScopeManager._() {
    _rootScope = ZenScope(name: 'RootScope');
    _currentScope = _rootScope;
    _registerScopeInMaps(_rootScope);
  }

  /// Get the current scope
  ZenScope get currentScope => _currentScope;

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
    _currentScope = _rootScope;
    _registerScopeInMaps(_rootScope);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ZenScopeManager initialized with root scope: ${_rootScope.id}');
    }
  }

  /// Reset all use counts in all scopes
  void resetAllUseCounts() {
    final allScopes = getAllScopes();
    for (final scope in allScopes) {
      scope.resetAllUseCounts();
    }
  }

  /// Create a new scope with optional parent
  ZenScope createScope({ZenScope? parent, String? name, String? id}) {
    final scope = ZenScope(
      parent: parent ?? _rootScope,
      name: name,
      id: id,
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

    // Use the existing registerDisposer method to clean up when the scope is disposed
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

  /// Register a dependency in the current scope
  T put<T>(T instance, {String? tag, bool permanent = false, List<dynamic> dependencies = const []}) {
    return _currentScope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
      declaredDependencies: dependencies,
    );
  }

  /// Register a dependency in the root scope (global)
  T putGlobal<T>(T instance, {String? tag, bool permanent = false, List<dynamic> dependencies = const []}) {
    return _rootScope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
      declaredDependencies: dependencies,
    );
  }

  /// Register a dependency in a specific scope
  T putIn<T>(T instance, {
    String? tag,
    required ZenScope scope,
    bool permanent = false,
    List<dynamic> dependencies = const [],
  }) {
    return scope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
      declaredDependencies: dependencies,
    );
  }

  /// Register a lazily initialized dependency in the current scope
  T? lazily<T>(T Function() factory, {String? tag}) {
    return _currentScope.lazily<T>(
      factory,
      tag: tag,
    );
  }

  /// Register a lazily initialized dependency in the root scope (global)
  T? lazilyGlobal<T>(T Function() factory, {String? tag}) {
    return _rootScope.lazily<T>(
      factory,
      tag: tag,
    );
  }

  /// Register a lazily initialized dependency in a specific scope
  T? lazilyIn<T>(
      T Function() factory, {
        String? tag,
        required ZenScope scope,
      }) {
    return scope.lazily<T>(
      factory,
      tag: tag,
    );
  }

  /// Register a factory function in the current scope
  void putFactory<T>(T Function() factory, {String? tag}) {
    _currentScope.putFactory<T>(factory, tag: tag);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''} in current scope');
    }
  }

  /// Register a factory function in the root scope
  void putFactoryGlobal<T>(T Function() factory, {String? tag}) {
    _rootScope.putFactory<T>(factory, tag: tag);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''} in root scope');
    }
  }

  /// Register a factory function in a specific scope
  void putFactoryIn<T>(T Function() factory, {required ZenScope scope, String? tag}) {
    scope.putFactory<T>(factory, tag: tag);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''} in scope: ${scope.name}');
    }
  }

  /// Find a dependency in the current scope hierarchy
  T? find<T>({String? tag}) {
    return _currentScope.find<T>(tag: tag);
  }

  /// Find a dependency in the root scope hierarchy
  T? findGlobal<T>({String? tag}) {
    return _rootScope.find<T>(tag: tag);
  }

  /// Find a dependency in a specific scope hierarchy
  T? findIn<T>({String? tag, required ZenScope scope}) {
    return scope.find<T>(tag: tag);
  }

  /// Delete a dependency from the current scope
  bool delete<T>({String? tag, bool force = false}) {
    return _currentScope.delete<T>(tag: tag, force: force);
  }

  /// Delete a dependency from the root scope
  bool deleteGlobal<T>({String? tag, bool force = false}) {
    return _rootScope.delete<T>(tag: tag, force: force);
  }

  /// Register a cleanup function for the current scope
  void registerDisposer(void Function() disposer) {
    _currentScope.registerDisposer(disposer);
  }

  /// Register a cleanup function for a specific scope
  void registerDisposerIn({required ZenScope scope, required void Function() disposer}) {
    scope.registerDisposer(disposer);
  }

  /// Register a cleanup function for the root scope
  void registerGlobalDisposer(void Function() disposer) {
    _rootScope.registerDisposer(disposer);
  }

  /// Get all scopes in the hierarchy (optimized implementation)
  List<ZenScope> getAllScopes() {
    return _scopesById.values.toList();
  }

  /// Begin a scope session - sets the current scope and returns a ScopeSession
  /// to automatically restore the previous scope when done
  ScopeSession beginSession(ZenScope scope) {
    final previousScope = _currentScope;
    _currentScope = scope;
    return ScopeSession._(
      manager: this,
      previousScope: previousScope,
    );
  }

  /// Set the current scope directly
  void setCurrentScope(ZenScope scope) {
    if (!_scopesById.containsKey(scope.id)) {
      // Register the scope if it's not already tracked
      _registerScopeInMaps(scope);
    }
    _currentScope = scope;
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
      // Don't clear maps here, let the dispose callbacks do it
      _rootScope.dispose();
    }

    // Ensure maps are cleared in case some callbacks failed
    _scopesById.clear();
    _scopesByName.clear();
  }
}

/// Helper class to manage scope sessions
class ScopeSession {
  final ZenScopeManager manager;
  final ZenScope previousScope;
  bool _ended = false;

  ScopeSession._({
    required this.manager,
    required this.previousScope,
  });

  /// End the session and restore the previous scope
  void end() {
    if (!_ended) {
      manager.setCurrentScope(previousScope);
      _ended = true;
    }
  }
}