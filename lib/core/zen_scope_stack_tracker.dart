import 'zen_config.dart';
import 'zen_logger.dart';
import 'zen_scope_manager.dart';
import 'zen_scope.dart';

/// Stack-based scope parent tracking for reliable hierarchical scope inheritance
///
/// This class maintains a stack of active scopes to enable automatic parent
/// scope resolution based on the actual navigation/widget hierarchy.
class ZenScopeStackTracker {
  static final List<String> _scopeStack = <String>[];
  static final Map<String, DateTime> _scopeCreationTimes = <String, DateTime>{};
  static final Map<String, bool> _scopeUsesParentScope = <String, bool>{};

  /// Called when a new scope is created and becomes active
  static void pushScope(String scopeName, {bool useParentScope = false}) {
    // Remove if already exists (in case of rebuilds)
    _scopeStack.remove(scopeName);

    // Add to top of stack
    _scopeStack.add(scopeName);
    _scopeCreationTimes[scopeName] = DateTime.now();
    _scopeUsesParentScope[scopeName] = useParentScope;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug(
          '📚 Scope stack push: ${_formatStack()} (useParentScope: $useParentScope)');
    }
  }

  /// Called when a scope is disposed or becomes inactive
  static void popScope(String scopeName) {
    final removed = _scopeStack.remove(scopeName);
    _scopeCreationTimes.remove(scopeName);
    _scopeUsesParentScope.remove(scopeName);

    if (removed && ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('📚 Scope stack pop: ${_formatStack()}');

      // Check if we're popping back to a non-parent-scope route
      final currentTopScope = getCurrentScope();
      if (currentTopScope != null) {
        final topScopeUsesParentScope =
            _scopeUsesParentScope[currentTopScope] ?? true;
        if (!topScopeUsesParentScope) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug(
                '🧹 Popped back to non-parent-scope route: $currentTopScope. Triggering cleanup.');
          }
          // Trigger cleanup when popping back to a route that doesn't use parent scope
          ZenScopeManager.cleanupAllScopesExcept(currentTopScope);
        }
      }
    }
  }

  /// Get the parent scope name for a given scope
  /// Returns the scope that was active immediately before the given scope
  static String? getParentScope(String scopeName) {
    final index = _scopeStack.indexOf(scopeName);
    if (index > 0) {
      // Return the scope immediately before this one in the stack
      return _scopeStack[index - 1];
    }
    return null; // No parent (root level)
  }

  /// Get the current active scope stack
  static List<String> getCurrentStack() {
    return List.from(_scopeStack);
  }

  /// Get the most recent scope (top of stack)
  static String? getCurrentScope() {
    return _scopeStack.isEmpty ? null : _scopeStack.last;
  }

  /// Check if a scope is currently in the stack
  static bool isActive(String scopeName) {
    return _scopeStack.contains(scopeName);
  }

  /// Get the creation time of a scope
  static DateTime? getCreationTime(String scopeName) {
    return _scopeCreationTimes[scopeName];
  }

  /// 🔥 NEW: Get the useParentScope setting for a specific scope
  static bool? getUseParentScope(String scopeName) {
    return _scopeUsesParentScope[scopeName];
  }

  /// Clear the entire stack (useful for testing or app reset)
  static void clear() {
    _scopeStack.clear();
    _scopeCreationTimes.clear();
    _scopeUsesParentScope.clear();
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('📚 Scope stack cleared');
    }
  }

  /// Get debug information about the current stack state
  static Map<String, dynamic> getDebugInfo() {
    return {
      'stack': List.from(_scopeStack),
      'stackSize': _scopeStack.length,
      'currentScope': getCurrentScope(),
      'creationTimes': Map.from(_scopeCreationTimes),
      'useParentScopeSettings': Map.from(_scopeUsesParentScope),
    };
  }

  /// Format the stack for logging
  static String _formatStack() {
    if (_scopeStack.isEmpty) return '[empty]';
    return _scopeStack.join(' -> ');
  }

  /// Get parent scope instance using the stack
  static ZenScope? getParentScopeInstance(String scopeName) {
    final parentScopeName = getParentScope(scopeName);
    if (parentScopeName != null) {
      final parentScope = ZenScopeManager.getScope(parentScopeName);
      if (parentScope != null && !parentScope.isDisposed) {
        return parentScope;
      }
    }
    return null;
  }
}
