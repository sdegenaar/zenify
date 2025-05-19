// lib/core/zen_scope.dart
import 'package:flutter/foundation.dart';
import '../controllers/zen_controller.dart';
import 'zen_logger.dart';
import 'zen_config.dart';

/// Dependency scoping mechanism for hierarchical access to dependencies
class ZenScope {
  // Parent scope for hierarchical lookup
  final ZenScope? parent;

  // Name for debugging
  final String? name;

  // Unique identifier for the scope
  final String id;

  // Flag to track if scope is disposed
  bool _disposed = false;

  // Dependency maps for this scope
  final Map<Type, dynamic> _typeBindings = {};
  final Map<String, dynamic> _taggedBindings = {};

  // Track which tag belongs to which type for faster lookups
  final Map<Type, Set<String>> _typeToTags = {};

  // Track child scopes
  final List<ZenScope> _childScopes = [];

  // Track use count for dependencies (for auto-disposal)
  final Map<dynamic, int> _useCount = {};

  // Track dependencies between objects (for cycle detection)
  final Map<dynamic, Set<dynamic>> _dependencyGraph = {};


  /// Creates a new scope
  ZenScope({
    this.parent,
    this.name,
    String? id,
  }) : id = id ?? '${name ?? 'scope'}-${DateTime.now().millisecondsSinceEpoch}' {
    // Add to parent's child scopes
    parent?._childScopes.add(this);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Created scope: $name (id: $id)');
    }
  }

  /// Check if scope is disposed
  bool get isDisposed => _disposed;

  /// Register a dependency in this scope
  T register<T>(
      T instance, {
        String? tag,
        bool permanent = false,
        List<dynamic> declaredDependencies = const [],
      }) {
    if (_disposed) {
      throw Exception('Cannot register in a disposed scope: $name');
    }

    // Handle storage and use count setup first...
    if (tag != null) {
      // Check if we're replacing a dependency
      final oldInstance = _taggedBindings[tag];
      if (oldInstance != null && ZenConfig.enableDebugLogs) {
        ZenLogger.logWarning('Replacing existing dependency with tag: $tag');

        // Dispose old controller if it's a ZenController
        if (oldInstance is ZenController && !oldInstance.isDisposed) {
          oldInstance.dispose();
        }
      }

      // Store by tag
      _taggedBindings[tag] = instance;

      // Also track by type for faster lookups
      final type = T;
      if (!_typeToTags.containsKey(type)) {
        _typeToTags[type] = <String>{};
      }
      _typeToTags[type]!.add(tag);

      // Set initial use count
      _useCount[_getDependencyKey(type, tag)] = permanent ? -1 : 0; // -1 means permanent
    } else {
      // Check if we're replacing a dependency
      final oldInstance = _typeBindings[T];
      if (oldInstance != null && ZenConfig.enableDebugLogs) {
        ZenLogger.logWarning('Replacing existing dependency of type: $T');

        // Dispose old controller if it's a ZenController
        if (oldInstance is ZenController && !oldInstance.isDisposed) {
          oldInstance.dispose();
        }
      }

      // Store by type
      _typeBindings[T] = instance;

      // Set initial use count
      _useCount[_getDependencyKey(T, null)] = permanent ? -1 : 0; // -1 means permanent
    }

    // Handle dependencies in a safer way - store them but don't check cycles here
    if (declaredDependencies.isNotEmpty) {
      _dependencyGraph[instance] = Set.from(declaredDependencies);
    }

    return instance;
  }

  /// Helper method for modules to register dependencies
  /// This is a public method that can be used by modules
  T registerFromModule<T>(T instance, {String? tag, bool permanent = false}) {
    return register<T>(
        instance,
        tag: tag,
        permanent: permanent
    );
  }

  // Helper method for modules to register dependencies
  /// This is a public method that can be used by modules
  T registerDependency<T>(T instance, {String? tag, bool permanent = false}) {
    return register<T>(
        instance,
        tag: tag,
        permanent: permanent
    );
  }


  /// Detect circular dependencies starting from the given object
  bool detectCycles(dynamic start) {
    try {
      // If start is null, there can't be cycles
      if (start == null) return false;

      final visited = <dynamic>{};
      final recursionStack = <dynamic>{};

      return _detectCyclesInternal(start, start, visited, recursionStack);
    } catch (e) {
      // Handle any errors during cycle detection
      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logWarning('Error during cycle detection, assuming circular dependency exists: $e');
      }
      return true; // Assume a cycle exists if detection fails
    }
  }

  /// Internal method to detect cycles within this scope
  /// Only used by Zen for comprehensive cycle detection
  bool _detectCyclesInternal(dynamic start, dynamic current, Set<dynamic> visited, Set<dynamic> recursionStack) {
    // If current is null, skip this branch
    if (current == null) return false;

    // If current is already in the recursion stack, we found a cycle
    if (recursionStack.contains(current)) {
      return true;
    }

    // If we've already processed this node in another path and didn't find a cycle, skip it
    if (visited.contains(current)) {
      return false;
    }

    // Mark as visited and add to recursion stack
    visited.add(current);
    recursionStack.add(current);

    // Recurse into dependencies in this scope
    final dependencies = _dependencyGraph[current];
    if (dependencies != null) {
      for (final dependency in dependencies) {
        // Skip null dependencies
        if (dependency == null) continue;

        if (_detectCyclesInternal(start, dependency, visited, recursionStack)) {
          return true;
        }
      }
    }

    // Remove from recursion stack as we're done with this path
    recursionStack.remove(current);
    return false;
  }

  /// Find a dependency in this scope or any parent scope
  T? find<T>({String? tag}) {
    if (_disposed) {
      return null;
    }

    // First try in this scope
    final result = findInThisScope<T>(tag: tag);
    if (result != null) {
      return result;
    }

    // If not found and we have a parent, look there
    if (parent != null) {
      return parent!.find<T>(tag: tag);
    }

    return null;
  }

  /// Find a dependency only in this specific scope (not in parents)
  T? findInThisScope<T>({String? tag}) {
    if (_disposed) {
      return null;
    }

    if (tag != null) {
      // First check if this tag exists
      final instance = _taggedBindings[tag];
      if (instance != null && instance is T) {
        return instance;
      }

      return null;
    } else {
      // Try to find by type
      final instance = _typeBindings[T];
      if (instance != null) {
        return instance as T;
      }

      return null;
    }
  }

  /// Find all instances of a given type in this scope and child scopes
  List<T> findAllOfType<T>() {
    if (_disposed) {
      return [];
    }

    final result = <T>[];

    // Check instance by type
    final instance = _typeBindings[T];
    if (instance != null) {
      result.add(instance as T);
    }

    // Check tagged instances of this type
    if (_typeToTags.containsKey(T)) {
      for (final tag in _typeToTags[T]!) {
        final taggedInstance = _taggedBindings[tag];
        if (taggedInstance != null && taggedInstance is T) {
          result.add(taggedInstance);
        }
      }
    }

    // Also check child scopes
    for (final child in _childScopes) {
      result.addAll(child.findAllOfType<T>());
    }

    return result;
  }


  /// Find a dependency by runtime Type
  dynamic findByType(Type type, {String? tag}) {
    if (_disposed) {
      return null;
    }

    // First try in this scope
    if (tag != null) {
      // Check tagged bindings
      final instance = _taggedBindings[tag];
      if (instance != null && instance.runtimeType == type) {
        return instance;
      }
    } else {
      // Check type bindings
      final instance = _typeBindings[type];
      if (instance != null) {
        return instance;
      }
    }

    // If not found and have parent, try parent
    if (parent != null) {
      return parent!.findByType(type, tag: tag);
    }

    return null;
  }


  /// Delete a dependency by type and optional tag
  bool delete<T>({String? tag, bool force = false}) {
    if (_disposed) {
      return false;
    }

    dynamic instanceToDelete;
    bool permanent = false;

    final key = _getDependencyKey(T, tag);

    // Check if permanent
    if (_useCount.containsKey(key)) {
      permanent = _useCount[key] == -1;

      if (permanent && !force) {
        ZenLogger.logWarning('Attempted to delete permanent dependency of type $T${tag != null ? ' with tag $tag' : ''}. Use force=true to override.');
        return false;
      }
    }

    if (tag != null) {
      instanceToDelete = _taggedBindings[tag];
      if (instanceToDelete == null || instanceToDelete is! T) {
        return false;
      }

      // Remove from tag map
      _taggedBindings.remove(tag);

      // Update type-to-tags tracking
      if (_typeToTags.containsKey(T)) {
        _typeToTags[T]!.remove(tag);
        if (_typeToTags[T]!.isEmpty) {
          _typeToTags.remove(T);
        }
      }
    } else {
      instanceToDelete = _typeBindings[T];
      if (instanceToDelete == null) {
        return false;
      }

      // Remove from type map
      _typeBindings.remove(T);
    }

    // Remove from use count tracking
    _useCount.remove(key);

    // Remove from dependency graph
    _dependencyGraph.remove(instanceToDelete);

    // Dispose if it's a controller
    if (instanceToDelete is ZenController && !instanceToDelete.isDisposed) {
      instanceToDelete.dispose();
    }

    return true;
  }

  /// Delete a dependency by tag only (without knowing the type)
  bool deleteByTag(String tag, {bool force = false}) {
    if (_disposed) {
      return false;
    }

    final instance = _taggedBindings[tag];
    if (instance == null) {
      return false;
    }

    final type = instance.runtimeType;
    final key = _getDependencyKey(type, tag);

    // Check if permanent
    if (_useCount.containsKey(key) && _useCount[key] == -1 && !force) {
      ZenLogger.logWarning('Attempted to delete permanent dependency with tag $tag. Use force=true to override.');
      return false;
    }

    // Remove from tag map
    _taggedBindings.remove(tag);

    // Update type-to-tags tracking
    if (_typeToTags.containsKey(type)) {
      _typeToTags[type]!.remove(tag);
      if (_typeToTags[type]!.isEmpty) {
        _typeToTags.remove(type);
      }
    }

    // Remove from use count tracking
    _useCount.remove(key);

    // Remove from dependency graph
    _dependencyGraph.remove(instance);

    // Dispose if it's a controller
    if (instance is ZenController && !instance.isDisposed) {
      instance.dispose();
    }

    return true;
  }

  /// Delete a dependency by runtime type only
  bool deleteByType(Type type, {bool force = false}) {
    if (_disposed) {
      return false;
    }

    final instance = _typeBindings[type];
    if (instance == null) {
      return false;
    }

    final key = _getDependencyKey(type, null);

    // Check if permanent
    if (_useCount.containsKey(key) && _useCount[key] == -1 && !force) {
      ZenLogger.logWarning('Attempted to delete permanent dependency of type $type. Use force=true to override.');
      return false;
    }

    // Remove from type map
    _typeBindings.remove(type);

    // Remove from use count tracking
    _useCount.remove(key);

    // Remove from dependency graph
    _dependencyGraph.remove(instance);

    // Dispose if it's a controller
    if (instance is ZenController && !instance.isDisposed) {
      instance.dispose();
    }

    return true;
  }

  /// Get all dependencies in this scope and child scopes
  List<dynamic> getAllDependencies() {
    if (_disposed) {
      return [];
    }

    final result = <dynamic>[];

    // Add dependencies from this scope
    result.addAll(_typeBindings.values);
    result.addAll(_taggedBindings.values);

    // Add dependencies from child scopes
    for (final child in _childScopes) {
      result.addAll(child.getAllDependencies());
    }

    return result;
  }

  /// Dispose this scope and all its dependencies
  @mustCallSuper
  void dispose() {
    if (_disposed) {
      return;
    }

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Disposing scope: $name');
    }

    // Dispose all controllers
    for (final dep in _typeBindings.values) {
      if (dep is ZenController && !dep.isDisposed) {
        dep.dispose();
      }
    }

    for (final dep in _taggedBindings.values) {
      if (dep is ZenController && !dep.isDisposed) {
        dep.dispose();
      }
    }

    // Dispose child scopes - make a copy to avoid concurrent modification
    final childrenToDispose = List.from(_childScopes);
    for (final child in childrenToDispose) {
      child.dispose();
    }

    // Clear all collections
    _typeBindings.clear();
    _taggedBindings.clear();
    _typeToTags.clear();
    _childScopes.clear();
    _useCount.clear();
    _dependencyGraph.clear();

    // Remove this scope from parent's children
    parent?._childScopes.remove(this);

    _disposed = true;
  }

  /// Get a tag for a specific instance if it exists
  String? getTagForInstance(dynamic instance) {
    if (_disposed) {
      return null;
    }

    // Try to find in tagged bindings
    for (final entry in _taggedBindings.entries) {
      if (identical(entry.value, instance)) {
        return entry.key;
      }
    }

    return null;
  }

  /// Create a dependency key for internal tracking
  dynamic _getDependencyKey(Type type, String? tag) {
    return tag != null ? '$type:$tag' : type;
  }

  /// Increment use count for a dependency
  int incrementUseCount<T>({String? tag}) {
    if (_disposed) {
      return -1;
    }

    // Find in this scope
    final exists = findInThisScope<T>(tag: tag) != null;
    if (!exists) {
      // If not in this scope but exists in parent, delegate to parent
      if (parent != null && parent!.find<T>(tag: tag) != null) {
        return parent!.incrementUseCount<T>(tag: tag);
      }
      return -1; // Not found
    }

    final key = _getDependencyKey(T, tag);
    if (!_useCount.containsKey(key) || _useCount[key] == -1) {
      return -1; // Permanent or not found
    }

    final count = (_useCount[key] ?? 0) + 1;
    _useCount[key] = count;
    return count;
  }

  /// Decrement use count for a dependency
  int decrementUseCount<T>({String? tag}) {
    if (_disposed) {
      return -1;
    }

    // Find in this scope
    final exists = findInThisScope<T>(tag: tag) != null;
    if (!exists) {
      // If not in this scope but exists in parent, delegate to parent
      if (parent != null && parent!.find<T>(tag: tag) != null) {
        return parent!.decrementUseCount<T>(tag: tag);
      }
      return -1; // Not found
    }

    final key = _getDependencyKey(T, tag);
    if (!_useCount.containsKey(key) || _useCount[key] == -1) {
      return -1; // Permanent or not found
    }

    final count = (_useCount[key] ?? 1) - 1;
    _useCount[key] = count;
    return count;
  }

  /// Get current use count for a dependency by runtime type
  int getUseCountByType({required Type type, String? tag}) {
    if (_disposed) {
      return 0;
    }

    final key = _getDependencyKey(type, tag);
    if (!_useCount.containsKey(key)) {
      // If dependency doesn't exist in this scope, try parent
      if (parent != null) {
        return parent!.getUseCountByType(type: type, tag: tag);
      }
      return 0;
    }

    return _useCount[key] ?? 0;
  }

  /// Get current use count for a dependency by type parameter
  int getUseCount<T>({String? tag}) {
    return getUseCountByType(type: T, tag: tag);
  }

  /// Check if a dependency is permanent
  bool isPermanent({required Type type, String? tag}) {
    if (_disposed) {
      return false;
    }

    final key = _getDependencyKey(type, tag);
    return _useCount.containsKey(key) && _useCount[key] == -1;
  }

  /// Check if instance exists in this scope
  bool containsInstance(dynamic instance) {
    if (_disposed) {
      return false;
    }

    // Check in type bindings
    if (_typeBindings.containsValue(instance)) {
      return true;
    }

    // Check in tagged bindings
    if (_taggedBindings.containsValue(instance)) {
      return true;
    }

    // Check in child scopes
    for (final child in _childScopes) {
      if (child.containsInstance(instance)) {
        return true;
      }
    }

    return false;
  }

  /// Get dependencies of an instance
  Set<dynamic> getDependenciesOf(dynamic instance) {
    if (_disposed) {
      return {};
    }

    // Check in this scope
    if (_dependencyGraph.containsKey(instance)) {
      return _dependencyGraph[instance]!;
    }

    // Check in child scopes
    for (final child in _childScopes) {
      final deps = child.getDependenciesOf(instance);
      if (deps.isNotEmpty) {
        return deps;
      }
    }

    return {};
  }

  /// Check if an instance has dependencies
  bool hasDependencies(dynamic instance) {
    return getDependenciesOf(instance).isNotEmpty;
  }

  Set<dynamic> getAllDependenciesOf(dynamic instance) {
    final result = getDependenciesOf(instance);

    // Also check parent scope
    if (parent != null) {
      result.addAll(parent!.getAllDependenciesOf(instance));
    }

    return result;
  }

  /// Access child scopes (for introspection)
  List<ZenScope> get childScopes => List.unmodifiable(_childScopes);

  @override
  String toString() {
    return 'ZenScope{name: $name, id: $id, disposed: $_disposed, '
        'dependencies: ${_typeBindings.length + _taggedBindings.length}, '
        'children: ${_childScopes.length}}';
  }
}