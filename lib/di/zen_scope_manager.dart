// lib/di/zen_scope_manager.dart
import '../core/zen_scope.dart';

/// Manages hierarchical scopes
class ZenScopeManager {
  // Root scope for the application
  final ZenScope _rootScope = ZenScope(name: 'RootScope');

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

  /// Dispose all scopes
  void dispose() {
    _rootScope.dispose();
  }
}