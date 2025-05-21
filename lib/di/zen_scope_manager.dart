// lib/di/zen_scope_manager.dart
import 'package:zenify/di/zen_di.dart';

import '../core/zen_scope.dart';

/// Manages hierarchical scopes
class ZenScopeManager {
  // Singleton instance
  static final ZenScopeManager instance = ZenScopeManager._();

  // Root scope for the application - not final so we can replace it
  late ZenScope _rootScope;

  // Current scope (used as default when not specified)
  late ZenScope currentScope;

  // Private constructor for singleton
  ZenScopeManager._() {
    _rootScope = ZenScope(name: 'RootScope');
    currentScope = _rootScope;
  }

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

    // Create a new root scope
    _rootScope = ZenScope(name: 'RootScope');
    currentScope = _rootScope;

    // Also ensure the container is cleared to avoid leftover factories
    Zen.container.clear();
  }

  /// Reset all use counts in all scopes
  void resetAllUseCounts() {
    final allScopes = getAllScopes();
    for (final scope in allScopes) {
      scope.resetAllUseCounts();
    }
  }

  /// Get the root scope
  ZenScope get rootScope => _rootScope;

  /// Create a new scope with optional parent
  ZenScope createScope({ZenScope? parent, String? name, String? id}) {
    return ZenScope(
      parent: parent ?? _rootScope,
      name: name,
      id: id,
    );
  }

  /// Register a dependency in the current scope
  T put<T>(T instance, {String? tag, bool permanent = false}) {
    return currentScope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
    );
  }

  /// Register a dependency in the root scope (global)
  T putGlobal<T>(T instance, {String? tag, bool permanent = false}) {
    return _rootScope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
    );
  }

  /// Register a dependency in a specific scope
  T putIn<T>(T instance, {String? tag, required ZenScope scope, bool permanent = false}) {
    return scope.register<T>(
      instance,
      tag: tag,
      permanent: permanent,
    );
  }

  /// Register a lazily initialized dependency in the current scope
  T? lazily<T>(T Function() factory, {String? tag}) {
    // Use the current scope's lazily method instead of directly using Zen.container
    return currentScope.lazily<T>(
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
    currentScope.putFactory<T>(factory, tag: tag);
  }

  /// Register a factory function in the root scope
  void putFactoryGlobal<T>(T Function() factory, {String? tag}) {
    _rootScope.putFactory<T>(factory, tag: tag);
  }

  /// Register a factory function in a specific scope
  void putFactoryIn<T>(T Function() factory, {required ZenScope scope, String? tag}) {
    scope.putFactory<T>(factory, tag: tag);
  }

  /// Find a dependency in the current scope hierarchy
  T? find<T>({String? tag}) {
    return currentScope.find<T>(tag: tag);
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
    return currentScope.delete<T>(tag: tag, force: force);
  }

  /// Delete a dependency from the root scope
  bool deleteGlobal<T>({String? tag, bool force = false}) {
    return _rootScope.delete<T>(tag: tag, force: force);
  }

  // Example Register a database connection
  //   final db = await openDatabase('my_db.sqlite');
  //   manager.put<Database>(db);
  //
  // Register a disposer to close the database when the scope is disposed
  //   manager.registerDisposer(() {
  //   db.close();
  //   });

  /// Register a cleanup function for the current scope
  void registerDisposer(void Function() disposer) {
    currentScope.registerDisposer(disposer);
  }

  /// Register a cleanup function for a specific scope
  void registerDisposerIn({required ZenScope scope, required void Function() disposer}) {
    scope.registerDisposer(disposer);
  }

  /// Register a cleanup function for the root scope
  void registerGlobalDisposer(void Function() disposer) {
    _rootScope.registerDisposer(disposer);
  }

  /// Get all scopes in the hierarchy
  List<ZenScope> getAllScopes() {
    final List<ZenScope> result = [_rootScope];

    void addChildScopes(ZenScope scope) {
      final children = scope.childScopes;
      result.addAll(children);
      for (final child in children) {
        addChildScopes(child);
      }
    }

    addChildScopes(_rootScope);
    return result;
  }

  /// Begin a scope session - sets the current scope and returns a ScopeSession
  /// to automatically restore the previous scope when done
  ScopeSession beginSession(ZenScope scope) {
    final previousScope = currentScope;
    currentScope = scope;
    return ScopeSession._(
      manager: this,
      previousScope: previousScope,
    );
  }

  /// Dispose all scopes
  void dispose() {
    _rootScope.dispose();
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
      manager.currentScope = previousScope;
      _ended = true;
    }
  }
}
