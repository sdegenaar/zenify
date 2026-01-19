// lib/core/zen_scope.dart
import 'package:flutter/foundation.dart';
import '../controllers/zen_controller.dart';
import '../controllers/zen_service.dart';
import '../di/zen_lifecycle.dart';
import 'zen_logger.dart';

/// Hierarchical dependency injection scope
///
/// ZenScope is a pure dependency container that manages:
/// - Type-based and tag-based dependency registration
/// - Lazy initialization with factories
/// - Hierarchical lookup (searches parent scopes)
/// - Automatic lifecycle management (init/dispose)
/// - Child scope tracking
///
/// Architecture:
/// - No global state - scopes are independent objects
/// - Parent-child relationships managed via object references
/// - Widget tree integration handled by ZenScopeWidget
/// - Automatic disposal when owner widget is disposed
///
/// Example:
/// ```dart
/// final parentScope = ZenScope(name: 'Parent');
/// final childScope = ZenScope(name: 'Child', parent: parentScope);
///
/// childScope.put<MyService>(MyService());
/// final service = childScope.find<MyService>(); // Found in child
/// ```
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

  // Store factory functions for lazy initialization
  final Map<String, Function> _factories = {};

  // Track child scopes
  final List<ZenScope> _childScopes = [];

  // Track use count for dependencies (for auto-disposal)
  // Values: -1 = permanent, 0 = temporary, -2 = factory (always new)
  final Map<dynamic, int> _useCount = {};

  // Store custom disposal functions
  final List<Function()> _disposers = [];

  // Add lifecycle manager access
  static final ZenLifecycleManager _lifecycleManager =
      ZenLifecycleManager.instance;

  /// Creates a new scope
  ZenScope({
    this.parent,
    this.name,
    String? id,
  }) : id = id ??
            '${name ?? 'scope'}-${DateTime.now().millisecondsSinceEpoch}' {
    // Add to parent's child scopes
    parent?._childScopes.add(this);

    ZenLogger.logDebug('Created scope: $name (id: $id)');
  }

  /// Check if scope is disposed
  bool get isDisposed => _disposed;

  /// Get all child scopes (immutable view)
  List<ZenScope> get childScopes => List.unmodifiable(_childScopes);

  //
  // MAIN REGISTRATION METHODS
  //

  /// Register a dependency in this scope
  T put<T>(T instance, {String? tag, bool isPermanent = false}) {
    if (_disposed) {
      throw Exception('Cannot register in a disposed scope: $name');
    }

    // Smart default: ZenService instances default to permanent (same as Zen.put)
    final permanent = instance is ZenService ? true : isPermanent;

    // Auto-initialize ZenController instances
    if (instance is ZenController) {
      _initializeController(instance);
    }
    // Auto-initialize ZenService instances via lifecycle manager (same as Zen.put)
    else if (instance is ZenService) {
      _lifecycleManager.initializeService(instance);
    }

    if (tag != null) {
      // Check if we're replacing a dependency
      final oldInstance = _taggedBindings[tag];
      if (oldInstance != null) {
        ZenLogger.logWarning('Replacing existing dependency with tag: $tag');
        // Dispose old controller if it's a ZenController
        if (oldInstance is ZenController && !oldInstance.isDisposed) {
          oldInstance.dispose();
        }
      }

      // Store by tag
      _taggedBindings[tag] = instance;

      // Track by type for faster lookups
      _typeToTags.putIfAbsent(T, () => <String>{}).add(tag);

      // Set initial use count
      final key = _getDependencyKey(T, tag);
      _useCount[key] = permanent ? -1 : 0;
    } else {
      // Check if we're replacing a dependency
      final oldInstance = _typeBindings[T];
      if (oldInstance != null) {
        ZenLogger.logWarning('Replacing existing dependency of type: $T');
        // Dispose old controller if it's a ZenController
        if (oldInstance is ZenController && !oldInstance.isDisposed) {
          oldInstance.dispose();
        }
      }

      // Store by type
      _typeBindings[T] = instance;

      // Set initial use count
      final key = _getDependencyKey(T, null);
      _useCount[key] = permanent ? -1 : 0;
    }

    ZenLogger.logDebug(
        'Registered $T${tag != null ? ' with tag $tag' : ''} (${permanent ? 'permanent' : 'temporary'})');

    return instance;
  }

  /// Register a lazy factory
  ///
  /// - Set [isPermanent] to true for permanent singletons (survive scope cleanup)
  /// - Set [isPermanent] to false for temporary singletons (cleaned up with scope)
  /// - Set [alwaysNew] to true to create fresh instance on each find() call
  ///
  /// Note: Cannot set both isPermanent and alwaysNew to true
  void putLazy<T>(
    T Function() factory, {
    String? tag,
    bool isPermanent = false,
    bool alwaysNew = false,
  }) {
    if (_disposed) {
      throw Exception('Cannot register in a disposed scope: $name');
    }

    if (isPermanent && alwaysNew) {
      throw ArgumentError('Cannot set both isPermanent and alwaysNew to true. '
          'A factory that creates new instances cannot be permanent.');
    }

    final key = _makeKey<T>(tag);
    final trackingKey = _getDependencyKey(T, tag);

    // Store the factory for later use
    _factories[key] = factory;

    // Set the use count based on behavior
    // -1 = permanent singleton
    // 0 = temporary singleton
    // -2 = factory (always creates new)
    _useCount[trackingKey] = alwaysNew ? -2 : (isPermanent ? -1 : 0);

    final behavior = alwaysNew
        ? 'factory (always new)'
        : (isPermanent ? 'permanent singleton' : 'temporary singleton');

    ZenLogger.logDebug(
        'Registered lazy $behavior for $T${tag != null ? ' with tag $tag' : ''}');
  }

  //
  // LOOKUP METHODS
  //

  /// Find a dependency by type and optional tag (searches hierarchy)
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
    return parent?.find<T>(tag: tag);
  }

  /// Find a dependency only in this specific scope (not in parents)
  T? findInThisScope<T>({String? tag}) {
    if (_disposed) {
      return null;
    }

    final key = _makeKey<T>(tag);

    if (tag != null) {
      // Check if this tag exists in this scope
      final instance = _taggedBindings[tag];
      if (instance != null && instance is T) {
        return instance;
      }

      // Check for factory
      if (_factories.containsKey(key)) {
        return _createFromFactory<T>(key, tag);
      }

      return null;
    } else {
      // Try to find by type in this scope only
      final instance = _typeBindings[T];
      if (instance != null) {
        return instance as T;
      }

      // Check for factory
      if (_factories.containsKey(key)) {
        return _createFromFactory<T>(key, null);
      }

      return null;
    }
  }

  /// Find a dependency (throws if not found)
  T findRequired<T>({String? tag}) {
    final result = find<T>(tag: tag);
    if (result == null) {
      throw Exception(
          'Dependency of type $T${tag != null ? ' with tag $tag' : ''} not found in scope: $name');
    }
    return result;
  }

  /// Check if a dependency exists
  bool exists<T>({String? tag}) {
    return find<T>(tag: tag) != null;
  }

  /// Find all instances of a given type in this scope and child scopes
  List<T> findAllOfType<T>() {
    if (_disposed) {
      return [];
    }

    final result = <T>[];
    final seen = <dynamic>{};

    // Check type bindings (untagged instances) - explicitly check for type T
    final typeInstance = _typeBindings[T];
    if (typeInstance != null &&
        typeInstance is T &&
        !seen.contains(typeInstance)) {
      result.add(typeInstance);
      seen.add(typeInstance);
    }

    // Also check all type bindings in case there are inheritance relationships
    for (final entry in _typeBindings.entries) {
      final instance = entry.value;
      if (instance is T && !seen.contains(instance)) {
        result.add(instance);
        seen.add(instance);
      }
    }

    // Check ALL tagged bindings for instances that are assignable to T
    for (final entry in _taggedBindings.entries) {
      final instance = entry.value;
      if (instance is T && !seen.contains(instance)) {
        result.add(instance);
        seen.add(instance);
      }
    }

    // Also check child scopes
    for (final child in _childScopes) {
      final childResults = child.findAllOfType<T>();
      for (final childInstance in childResults) {
        if (!seen.contains(childInstance)) {
          result.add(childInstance);
          seen.add(childInstance);
        }
      }
    }

    return result;
  }

  //
  // DELETION METHODS
  //

  /// Delete a dependency by type and optional tag
  bool delete<T>({String? tag, bool force = false}) {
    if (_disposed) {
      return false;
    }

    final key = _getDependencyKey(T, tag);
    final factoryKey = _makeKey<T>(tag);

    // Check if permanent
    if (_useCount.containsKey(key)) {
      final permanent = _useCount[key] == -1;
      if (permanent && !force) {
        ZenLogger.logWarning(
            'Attempted to delete permanent dependency of type $T${tag != null ? ' with tag $tag' : ''}. Use force=true to override.');
        return false;
      }
    }

    dynamic instanceToDelete;

    // Check if we have a factory registered
    if (_factories.containsKey(factoryKey)) {
      _factories.remove(factoryKey);
      _useCount.remove(key);
      return true;
    }

    if (tag != null) {
      instanceToDelete = _taggedBindings[tag];
      if (instanceToDelete == null) {
        return false;
      }

      // Remove from tag map
      _taggedBindings.remove(tag);

      // Update type-to-tags tracking using the GENERIC type T, not runtimeType
      _typeToTags[T]?.remove(tag);
      if (_typeToTags[T]?.isEmpty ?? false) {
        _typeToTags.remove(T);
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

    // Dispose if it's a controller OR service
    if (instanceToDelete is ZenController && !instanceToDelete.isDisposed) {
      instanceToDelete.dispose();
    } else if (instanceToDelete is ZenService && !instanceToDelete.isDisposed) {
      instanceToDelete.dispose();
    }

    ZenLogger.logDebug(
        'Deleted dependency $T${tag != null ? ' with tag $tag' : ''}');

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
      ZenLogger.logWarning(
          'Attempted to delete permanent dependency with tag $tag. Use force=true to override.');
      return false;
    }

    // Remove from tag map
    _taggedBindings.remove(tag);

    // Update type-to-tags tracking
    _typeToTags[type]?.remove(tag);
    if (_typeToTags[type]?.isEmpty ?? false) {
      _typeToTags.remove(type);
    }

    // Remove from use count tracking
    _useCount.remove(key);

    // Dispose if it's a controller OR service
    if (instance is ZenController && !instance.isDisposed) {
      instance.dispose();
    } else if (instance is ZenService && !instance.isDisposed) {
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
      ZenLogger.logWarning(
          'Attempted to delete permanent dependency of type $type. Use force=true to override.');
      return false;
    }

    // Remove from type map
    _typeBindings.remove(type);

    // Remove from use count tracking
    _useCount.remove(key);

    // Dispose if it's a controller OR service
    if (instance is ZenController && !instance.isDisposed) {
      instance.dispose();
    } else if (instance is ZenService && !instance.isDisposed) {
      instance.dispose();
    }

    return true;
  }

  //
  // SCOPE MANAGEMENT
  //

  /// Create a child scope from this scope
  ///
  /// Child scopes automatically inherit dependencies from their parent
  /// and are automatically disposed when the parent is disposed.
  ZenScope createChild({String? name}) {
    final childName = name ?? 'Child-${DateTime.now().microsecondsSinceEpoch}';

    // Create child scope with proper parent relationship
    // Parent tracking is automatic via constructor
    final child = ZenScope(name: childName, parent: this);

    return child;
  }

  /// Register a function that will be called when this scope is disposed
  void registerDisposer(void Function() disposer) {
    if (_disposed) {
      throw Exception('Cannot register disposer on a disposed scope: $name');
    }

    _disposers.add(disposer);

    ZenLogger.logDebug('Registered disposer in scope: $name');
  }

  /// Dispose this scope and all its dependencies
  @mustCallSuper
  void dispose() {
    if (_disposed) {
      return;
    }

    ZenLogger.logDebug('Disposing scope: $name');

    // Run all registered disposers
    for (final disposer in _disposers) {
      try {
        disposer();
      } catch (e) {
        ZenLogger.logWarning('Error executing disposer in scope $name: $e');
      }
    }

    // Dispose all controllers AND services
    for (final dep in _typeBindings.values) {
      if (dep is ZenController && !dep.isDisposed) {
        dep.dispose();
      } else if (dep is ZenService && !dep.isDisposed) {
        dep.dispose();
      }
    }

    for (final dep in _taggedBindings.values) {
      if (dep is ZenController && !dep.isDisposed) {
        dep.dispose();
      } else if (dep is ZenService && !dep.isDisposed) {
        dep.dispose();
      }
    }

    // Dispose child scopes
    final childrenToDispose = List.from(_childScopes);
    for (final child in childrenToDispose) {
      child.dispose();
    }

    // Clear all collections
    _typeBindings.clear();
    _taggedBindings.clear();
    _typeToTags.clear();
    _factories.clear();
    _childScopes.clear();
    _useCount.clear();
    _disposers.clear();

    // Remove this scope from parent's children
    parent?._childScopes.remove(this);

    _disposed = true;
  }

  /// Clear all dependencies from this scope
  void clearAll({bool force = false}) {
    if (_disposed) {
      return;
    }

    // Clear type bindings
    final typeInstances = Map<Type, dynamic>.from(_typeBindings);
    for (final entry in typeInstances.entries) {
      final type = entry.key;
      final instance = entry.value;

      // Check permanence
      final key = _getDependencyKey(type, null);
      final isPermanent = _useCount[key] == -1;

      if (!isPermanent || force) {
        _typeBindings.remove(type);
        _useCount.remove(key);

        // Dispose if it's a controller OR service
        if (instance is ZenController && !instance.isDisposed) {
          try {
            instance.dispose();
          } catch (e) {
            ZenLogger.logError(
                'Error disposing controller during clearAll: $e');
          }
        } else if (instance is ZenService && !instance.isDisposed) {
          try {
            instance.dispose();
          } catch (e) {
            ZenLogger.logError('Error disposing service during clearAll: $e');
          }
        }
      }
    }

    // Clear tagged bindings
    final taggedInstances = Map<String, dynamic>.from(_taggedBindings);
    for (final entry in taggedInstances.entries) {
      final tag = entry.key;
      final instance = entry.value;
      final type = instance.runtimeType;

      // Check permanence
      final key = _getDependencyKey(type, tag);
      final isPermanent = _useCount[key] == -1;

      if (!isPermanent || force) {
        _taggedBindings.remove(tag);
        _useCount.remove(key);

        // Update type-to-tags tracking
        _typeToTags[type]?.remove(tag);
        if (_typeToTags[type]?.isEmpty ?? false) {
          _typeToTags.remove(type);
        }

        // Dispose if it's a controller OR service
        if (instance is ZenController && !instance.isDisposed) {
          try {
            instance.dispose();
          } catch (e) {
            ZenLogger.logError(
                'Error disposing controller during clearAll: $e');
          }
        } else if (instance is ZenService && !instance.isDisposed) {
          try {
            instance.dispose();
          } catch (e) {
            ZenLogger.logError('Error disposing service during clearAll: $e');
          }
        }
      }
    }

    // Clear factories
    if (force) {
      _factories.clear();
      // Remove any remaining use count entries for factories
      _useCount.removeWhere((key, value) => value == -2);
    } else {
      // Only remove non-permanent factories
      final factoriesToRemove = <String>[];
      for (final entry in _factories.entries) {
        final factoryKey = entry.key;
        // Check if this factory is non-permanent
        final matchingKeys = _useCount.entries.where((e) =>
            e.value != -1 && // Not permanent
            e.value != -2); // Not a factory pattern

        if (matchingKeys.isNotEmpty) {
          factoriesToRemove.add(factoryKey);
        }
      }

      for (final key in factoriesToRemove) {
        _factories.remove(key);
      }
    }

    ZenLogger.logDebug('Cleared all dependencies from scope: $name');
  }

  //
  // UTILITY METHODS (Kept minimal for core functionality)
  //

  /// Get all dependencies in this scope (for debugging)
  List<dynamic> getAllDependencies() {
    if (_disposed) {
      return [];
    }

    final dependencies = <dynamic>[];
    dependencies.addAll(_typeBindings.values);
    dependencies.addAll(_taggedBindings.values);
    return dependencies;
  }

  /// Force complete reset of scope internal state (for rollback)
  void forceCompleteReset() {
    if (_disposed) {
      return; // Already disposed, nothing to reset
    }

    // Clear all dependency tracking maps
    _typeBindings.clear();
    _taggedBindings.clear();
    _typeToTags.clear();
    _factories.clear();
    _useCount.clear();

    // Don't clear _disposers as they might be needed for cleanup
    // Don't clear _childScopes as they are still valid

    ZenLogger.logDebug('Force reset scope: ${name ?? id}');
  }

  /// Get a tag for a specific instance if it exists
  String? getTagForInstance(dynamic instance) {
    if (_disposed) {
      return null;
    }

    for (final entry in _taggedBindings.entries) {
      if (identical(entry.value, instance)) {
        return entry.key;
      }
    }

    return null;
  }

  /// Check if a dependency is permanent
  bool isPermanent({required Type type, String? tag}) {
    if (_disposed) {
      return false;
    }

    final key = _getDependencyKey(type, tag);
    return _useCount.containsKey(key) && _useCount[key] == -1;
  }

  /// Check if instance exists in this scope hierarchy
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

  /// Checks if a type is registered (either as an instance or a factory)
  bool contains<T>({String? tag}) {
    if (_disposed) {
      return false;
    }

    final key = _makeKey<T>(tag);

    // Check for existing instance
    if (_instanceExists<T>(tag)) {
      return true;
    }

    // Check for factory
    return _factories.containsKey(key);
  }

  //
  // INTERNAL HELPER METHODS
  //

  /// Auto-initialize ZenController instances
  void _initializeController(ZenController controller) {
    if (!controller.isInitialized) {
      ZenLogger.logDebug(
          'Auto-initializing ZenController: ${controller.runtimeType}');
      controller.onInit();
    }
    if (!controller.isReady) {
      ZenLogger.logDebug(
          'Auto-readying ZenController: ${controller.runtimeType}');
      controller.onReady();
    }
  }

  /// Helper method to create a lookup key for type+tag
  String _makeKey<T>(String? tag) {
    return tag != null ? '${T.toString()}:$tag' : T.toString();
  }

  /// Check if an instance already exists (either regular or lazy)
  bool _instanceExists<T>(String? tag) {
    if (tag != null) {
      final instance = _taggedBindings[tag];
      return instance != null && instance is T;
    } else {
      return _typeBindings.containsKey(T);
    }
  }

  /// Create a dependency key for internal tracking
  dynamic _getDependencyKey(Type type, String? tag) {
    return tag != null ? '$type:$tag' : type;
  }

  /// Create instance from factory
  T _createFromFactory<T>(String key, String? tag) {
    final factory = _factories[key] as T Function();
    final instance = factory();

    // Auto-initialize ZenController instances
    if (instance is ZenController) {
      _initializeController(instance);
    }
    // Auto-initialize ZenService instances via lifecycle manager (same as Zen.put)
    else if (instance is ZenService) {
      _lifecycleManager.initializeService(instance);
    }

    // Check if this is a singleton factory or always-new factory
    final trackingKey = _getDependencyKey(T, tag);
    final isSingleton =
        _useCount[trackingKey] != -2; // -2 = factory (always new)

    // For singletons, store the instance and remove the factory
    if (isSingleton) {
      if (tag != null) {
        _taggedBindings[tag] = instance;
        _typeToTags.putIfAbsent(T, () => <String>{}).add(tag);
      } else {
        _typeBindings[T] = instance;
      }

      // Remove the factory since we've created the instance
      _factories.remove(key);
    }

    ZenLogger.logDebug(
        'Created ${isSingleton ? 'lazy' : 'factory'} instance for $T${tag != null ? ' with tag $tag' : ''}');

    return instance;
  }

  // =========================================================================
  // CONVENIENCE ALIASES (v1.6.4+)
  // =========================================================================

  /// Alias for [find]. Gets a dependency from the scope.
  ///
  /// This is a convenience alias that provides consistent verb naming
  /// across the Zenify API (get/put/remove/has).
  T? get<T>({String? tag}) => find<T>(tag: tag);

  /// Alias for [delete]. Removes a dependency from the scope.
  ///
  /// This is a convenience alias that provides consistent verb naming
  /// across the Zenify API (get/put/remove/has).
  bool remove<T>({String? tag, bool force = false}) =>
      delete<T>(tag: tag, force: force);

  /// Alias for [exists]. Checks if a dependency exists in the scope.
  ///
  /// This is a convenience alias that provides consistent verb naming
  /// across the Zenify API (get/put/remove/has).
  bool has<T>({String? tag}) => exists<T>(tag: tag);

  @override
  String toString() {
    return 'ZenScope{name: $name, id: $id, disposed: $_disposed, '
        'dependencies: ${_typeBindings.length + _taggedBindings.length}, '
        'lazy dependencies: ${_factories.length}, '
        'children: ${_childScopes.length}}';
  }
}
