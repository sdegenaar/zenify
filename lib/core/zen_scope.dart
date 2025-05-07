// lib/core/zen_scope.dart
import '../controllers/zen_controller.dart';
import 'zen_logger.dart';
import 'zen_config.dart';

/// Dependency scoping mechanism for hierarchical access to dependencies
class ZenScope {
  // Parent scope for hierarchical lookup
  final ZenScope? parent;

  // Name for debugging
  final String? name;

  // Unique identifier for this scope
  final String id;

  // Storage for dependencies indexed by Type
  final Map<Type, dynamic> _typeBindings = {};

  // Storage for dependencies indexed by tag
  final Map<String, dynamic> _taggedBindings = {};

  // Map of dependency types to their tags for quick lookups
  final Map<Type, Set<String>> _typeToTags = {};

  // Track child scopes
  final List<ZenScope> _childScopes = [];

  // Track use count for dependencies (for auto-disposal)
  final Map<dynamic, int> _useCount = {};

  // Track dependency relationships for cycle detection
  final Map<dynamic, Set<dynamic>> _dependencyGraph = {};

  // Flag to indicate if this scope has been disposed
  bool _disposed = false;

  /// Create a new scope with optional parent
  ZenScope({
    this.parent,
    this.name,
    String? id,
  }) : id = id ?? _generateUniqueId() {
    if (parent != null) {
      parent!._childScopes.add(this);
    }

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Created scope $name ($id)${parent != null ? ' with parent ${parent!.name}' : ''}');
    }
  }

  /// Public API for registering dependencies
  void register<T>(
      T instance, {
        String? tag,
        List<dynamic> declaredDependencies = const [],
      }) {
    _registerImpl<T>(instance, tag: tag, declaredDependencies: declaredDependencies);
  }

  /// Implementation for registering dependencies
  /// This method should only be used within this class or by the Zen class
  void _registerImpl<T>(
      T instance, {
        String? tag,
        List<dynamic> declaredDependencies = const [],
      }) {
    if (_disposed) {
      throw StateError('Cannot register dependencies in a disposed scope');
    }

    if (tag != null) {
      _taggedBindings[tag] = instance;
      _typeToTags.putIfAbsent(T, () => {}).add(tag);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Registered $T with tag $tag in scope $name');
      }
    } else {
      _typeBindings[T] = instance;

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Registered $T in scope $name');
      }
    }

    // Track dependency relationships for cycle detection
    if (declaredDependencies.isNotEmpty) {
      _dependencyGraph[instance] = Set.from(declaredDependencies);

      // Check for cycles
      if (_detectCycles(instance)) {
        ZenLogger.logWarning('Circular dependency detected for $T');
      }
    }

    // Initialize use count
    _useCount[_getDependencyKey(T, tag)] = 0;
  }

  /// Find a dependency by type and optional tag
  /// Searches up the scope hierarchy if not found in this scope
  T? find<T>({String? tag}) {
    // First check in this scope
    final localResult = findInThisScope<T>(tag: tag);
    if (localResult != null) {
      return localResult;
    }

    // If not found and we have a parent, check there
    if (parent != null) {
      return parent!.find<T>(tag: tag);
    }

    // Not found anywhere in the hierarchy
    return null;
  }

  /// Find a dependency only in this scope (no parent lookup)
  T? findInThisScope<T>({String? tag}) {
    if (_disposed) {
      ZenLogger.logWarning('Attempted to find dependency in disposed scope');
      return null;
    }

    if (tag != null) {
      return _taggedBindings[tag] as T?;
    } else {
      return _typeBindings[T] as T?;
    }
  }

  /// Delete a dependency from this scope
  bool delete<T>({String? tag}) {
    if (_disposed) {
      ZenLogger.logWarning('Attempted to delete from disposed scope');
      return false;
    }

    bool deleted = false;

    if (tag != null) {
      if (_taggedBindings.containsKey(tag)) {
        final instance = _taggedBindings[tag];
        if (instance is ZenController && !instance.isDisposed) {
          instance.dispose();
        }

        _taggedBindings.remove(tag);

        // Update type-to-tags mapping
        if (_typeToTags.containsKey(T)) {
          _typeToTags[T]!.remove(tag);
          if (_typeToTags[T]!.isEmpty) {
            _typeToTags.remove(T);
          }
        }

        // Remove from dependency graph
        _dependencyGraph.remove(instance);

        // Remove use count
        _useCount.remove(_getDependencyKey(T, tag));

        deleted = true;
      }
    } else {
      if (_typeBindings.containsKey(T)) {
        final instance = _typeBindings[T];
        if (instance is ZenController && !instance.isDisposed) {
          instance.dispose();
        }

        _typeBindings.remove(T);

        // Remove from dependency graph
        _dependencyGraph.remove(instance);

        // Remove use count
        _useCount.remove(_getDependencyKey(T, null));

        deleted = true;
      }
    }

    return deleted;
  }

  /// Delete by tag only (without knowing the type)
  bool deleteByTag(String tag) {
    if (_disposed) {
      ZenLogger.logWarning('Attempted to delete from disposed scope');
      return false;
    }

    if (_taggedBindings.containsKey(tag)) {
      final instance = _taggedBindings[tag];

      // Dispose if it's a controller
      if (instance is ZenController && !instance.isDisposed) {
        instance.dispose();
      }

      // Remove from tag bindings
      _taggedBindings.remove(tag);

      // Update type to tags mapping
      for (final entry in _typeToTags.entries) {
        if (entry.value.contains(tag)) {
          entry.value.remove(tag);
          if (entry.value.isEmpty) {
            _typeToTags.remove(entry.key);
          }
          break;
        }
      }

      // Remove from dependency graph
      _dependencyGraph.remove(instance);

      // Remove use count
      final key = _getDependencyKeyByTag(tag);
      if (key != null) {
        _useCount.remove(key);
      }

      return true;
    }

    return false;
  }

  /// Delete by runtime type
  bool deleteByType(Type type) {
    if (_disposed) {
      ZenLogger.logWarning('Attempted to delete from disposed scope');
      return false;
    }

    if (_typeBindings.containsKey(type)) {
      final instance = _typeBindings[type];

      // Dispose if it's a controller
      if (instance is ZenController && !instance.isDisposed) {
        instance.dispose();
      }

      // Remove from type bindings
      _typeBindings.remove(type);

      // Remove from dependency graph
      _dependencyGraph.remove(instance);

      // Remove use count
      _useCount.remove(_getDependencyKey(type, null));

      return true;
    }

    return false;
  }

  /// Get all dependencies in this scope and child scopes
  List<dynamic> getAllDependencies() {
    if (_disposed) {
      return [];
    }

    final List<dynamic> result = [];

    // Add from type bindings
    result.addAll(_typeBindings.values);

    // Add from tagged bindings
    result.addAll(_taggedBindings.values);

    // Add from child scopes
    for (final child in _childScopes) {
      result.addAll(child.getAllDependencies());
    }

    return result;
  }

  /// Dispose this scope and all its dependencies
  void dispose() {
    if (_disposed) {
      return;
    }

    // Dispose child scopes first
    for (final child in _childScopes.toList()) {
      child.dispose();
    }
    _childScopes.clear();

    // Dispose all controllers in this scope
    for (final instance in _typeBindings.values) {
      if (instance is ZenController && !instance.isDisposed) {
        instance.dispose();
      }
    }

    for (final instance in _taggedBindings.values) {
      if (instance is ZenController && !instance.isDisposed) {
        instance.dispose();
      }
    }

    // Clear all maps
    _typeBindings.clear();
    _taggedBindings.clear();
    _typeToTags.clear();
    _dependencyGraph.clear();
    _useCount.clear();

    // Remove from parent's child list
    if (parent != null && !parent!._disposed) {
      parent!._childScopes.remove(this);
    }

    _disposed = true;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Disposed scope $name ($id)');
    }
  }

  /// Create a key for dependency tracking
  dynamic _getDependencyKey(Type type, String? tag) {
    return tag != null ? '$type:$tag' : type;
  }

  /// Get the dependency key for a tag (for cleanup)
  dynamic _getDependencyKeyByTag(String tag) {
    for (final typeEntry in _typeToTags.entries) {
      if (typeEntry.value.contains(tag)) {
        return _getDependencyKey(typeEntry.key, tag);
      }
    }
    return null;
  }

  /// Detect circular dependencies
  bool _detectCycles(dynamic start) {
    final visited = <dynamic>{};
    final recursionStack = <dynamic>{};

    bool dfs(dynamic current) {
      if (!_dependencyGraph.containsKey(current)) {
        return false;
      }

      visited.add(current);
      recursionStack.add(current);

      for (final dependency in _dependencyGraph[current]!) {
        if (!visited.contains(dependency)) {
          if (dfs(dependency)) {
            return true;
          }
        } else if (recursionStack.contains(dependency)) {
          // Found a cycle
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logError('Circular dependency detected involving ${current.runtimeType} and ${dependency.runtimeType}');
          }
          return true;
        }
      }

      recursionStack.remove(current);
      return false;
    }

    return dfs(start);
  }

  /// Generate a unique ID for the scope
  static String _generateUniqueId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  /// Get all instances of a specific type across all scopes
  List<T> findAllOfType<T>() {
    final List<T> result = [];

    // Add from this scope
    if (_typeBindings.containsKey(T)) {
      result.add(_typeBindings[T] as T);
    }

    // Add tagged instances of this type
    if (_typeToTags.containsKey(T)) {
      for (final tag in _typeToTags[T]!) {
        result.add(_taggedBindings[tag] as T);
      }
    }

    // Add from child scopes
    for (final child in _childScopes) {
      result.addAll(child.findAllOfType<T>());
    }

    return result;
  }

  /// Track dependency use count for auto-disposal
  void incrementUseCount<T>({String? tag}) {
    final key = _getDependencyKey(T, tag);
    _useCount[key] = (_useCount[key] ?? 0) + 1;
  }

  /// Decrement use count and return the new count
  int decrementUseCount<T>({String? tag}) {
    final key = _getDependencyKey(T, tag);
    if (!_useCount.containsKey(key)) {
      return 0;
    }

    final count = (_useCount[key] ?? 1) - 1;
    _useCount[key] = count;
    return count;
  }
}