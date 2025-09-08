// lib/di/internal/zen_container.dart

/// Internal storage implementation for the DI system
class ZenContainer {
  // Singleton instance
  static final ZenContainer instance = ZenContainer._();

  // Private constructor
  ZenContainer._();

  // Maps for instances and factories
  final Map<Type, Map<String?, dynamic>> _instances = {};
  final Map<dynamic, Function> _factories = {};

  // Cache for getKey operations
  final Map<String, dynamic> _keyCache = {};

  /// Register an instance
  void registerInstance<T>(T instance, String? tag) {
    // Store the instance by its exact generic type T
    _instances.putIfAbsent(T, () => {});
    _instances[T]![tag] = instance;

    // Also store by runtime type if it's different from T
    final runtimeType = instance.runtimeType;
    if (runtimeType != T) {
      _instances.putIfAbsent(runtimeType, () => {});
      _instances[runtimeType]![tag] = instance;
    }
  }

  /// Find an instance by tag
  T? findByTag<T>(String tag) {
    // Look for an instance with this tag that is of type T
    // First check the map for the specific type
    if (_instances.containsKey(T)) {
      final instanceMap = _instances[T];
      if (instanceMap != null && instanceMap.containsKey(tag)) {
        return instanceMap[tag] as T;
      }
    }

    // If not found, scan all types for a matching tag
    for (final entry in _instances.entries) {
      final typeMap = entry.value;
      if (typeMap.containsKey(tag)) {
        final instance = typeMap[tag];
        if (instance is T) {
          return instance;
        }
      }
    }

    return null;
  }

  /// Find an instance by type
  T? findByType<T>() {
    // First check the map for the specific type
    if (_instances.containsKey(T)) {
      final instanceMap = _instances[T];
      if (instanceMap != null) {
        // Try to get the untagged instance first
        if (instanceMap.containsKey(null)) {
          return instanceMap[null] as T;
        }

        // If no untagged instance, return the first tagged one
        if (instanceMap.isNotEmpty) {
          return instanceMap.values.first as T;
        }
      }
    }

    // If not found by exact type, scan all instances for a matching type
    for (final typeMap in _instances.values) {
      for (final instance in typeMap.values) {
        if (instance is T) {
          return instance;
        }
      }
    }

    return null;
  }

  /// Find an instance by exact type and tag
  T? findExact<T>(String? tag) {
    if (!_instances.containsKey(T)) return null;

    final instanceMap = _instances[T];
    if (instanceMap == null || !instanceMap.containsKey(tag)) return null;

    return instanceMap[tag] as T;
  }

  /// Remove an instance
  bool removeInstance<T>(String? tag) {
    if (!_instances.containsKey(T)) return false;

    final removed = _instances[T]?.remove(tag);

    // Clean up empty maps
    if (_instances[T]?.isEmpty ?? false) {
      _instances.remove(T);
    }

    return removed != null;
  }

  /// Remove an instance by its type and tag
  bool removeInstanceByTypeAndTag(Type type, String? tag) {
    if (!_instances.containsKey(type)) return false;

    final removed = _instances[type]?.remove(tag);

    // Clean up empty maps
    if (_instances[type]?.isEmpty ?? false) {
      _instances.remove(type);
    }

    return removed != null;
  }

  /// Get all registered types
  Set<Type> getAllTypes() {
    return _instances.keys.toSet();
  }

  /// Get all instances of a specific type
  List<T> getAllOfType<T>() {
    final result = <T>[];

    // Check direct type matches first
    if (_instances.containsKey(T)) {
      result.addAll(_instances[T]!.values.cast<T>());
    }

    // Also check for subtype matches
    for (final typeMap in _instances.values) {
      for (final instance in typeMap.values) {
        if (instance is T && !result.contains(instance)) {
          result.add(instance);
        }
      }
    }

    return result;
  }

  /// Register a factory
  void registerFactory(dynamic key, Function factory) {
    _factories[key] = factory;
  }

  /// Get a factory
  Function? getFactory(dynamic key) {
    return _factories[key];
  }

  /// Remove a factory
  bool removeFactory(dynamic key) {
    return _factories.remove(key) != null;
  }

  /// Remove factories by tag pattern
  void removeFactoriesByTag(String tag) {
    // More efficient implementation using a single pass
    _factories.removeWhere((key, _) {
      return key is String && key.contains(':$tag');
    });
  }

  /// Remove factories by type
  void removeFactoriesByType(Type type) {
    // More efficient implementation using a single pass
    _factories.removeWhere((key, _) {
      return key == type || (key is String && key.startsWith('$type:'));
    });
  }

  /// Clear all instances and factories
  void clear() {
    _instances.clear();
    _factories.clear();
    _keyCache.clear();
  }

  /// Get a key for associating factories and instances with types and tags
  dynamic getKey(Type type, String? tag) {
    if (tag == null) return type;

    // Use cached key if available
    final cacheKey = '${type.hashCode}:$tag';
    if (_keyCache.containsKey(cacheKey)) {
      return _keyCache[cacheKey];
    }

    final key = '$type:$tag';
    _keyCache[cacheKey] = key;
    return key;
  }

  /// Get all factory keys
  List<dynamic> getAllFactoryKeys() {
    return _factories.keys.toList();
  }

  /// Check if a factory exists for a key
  bool hasFactory(dynamic key) {
    return _factories.containsKey(key);
  }

  /// Check if an instance exists for a type and tag
  bool hasInstance<T>(String? tag) {
    return _instances.containsKey(T) && _instances[T]!.containsKey(tag);
  }
}
