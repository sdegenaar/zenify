// lib/di/internal/zen_container.dart

/// Internal storage implementation for the DI system
class ZenContainer {
  // Maps for instances and factories
  final Map<Type, Map<String?, dynamic>> _instances = {};
  final Map<dynamic, Function> _factories = {};

  /// Register an instance
  void registerInstance<T>(T instance, String? tag) {
    _instances.putIfAbsent(T, () => {});
    _instances[T]![tag] = instance;
  }

  /// Remove an instance
  bool removeInstance<T>(String? tag) {
    if (!_instances.containsKey(T)) return false;

    final removed = _instances[T]?.remove(tag);
    if (_instances[T]?.isEmpty ?? false) {
      _instances.remove(T);
    }

    return removed != null;
  }

  /// Remove an instance by its type and tag
  bool removeInstanceByTypeAndTag(Type type, String? tag) {
    if (!_instances.containsKey(type)) return false;

    final removed = _instances[type]?.remove(tag);
    if (_instances[type]?.isEmpty ?? false) {
      _instances.remove(type);
    }

    return removed != null;
  }

  /// Get an instance
  T? getInstance<T>(String? tag) {
    return _instances[T]?[tag] as T?;
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
    final keysToRemove = <dynamic>[];

    for (final key in _factories.keys) {
      if (key is String && key.contains(':$tag')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _factories.remove(key);
    }
  }

  /// Remove factories by type
  void removeFactoriesByType(Type type) {
    final keysToRemove = <dynamic>[];

    for (final key in _factories.keys) {
      if (key == type || (key is String && key.startsWith('$type:'))) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _factories.remove(key);
    }
  }

  /// Clear all instances and factories
  void clear() {
    _instances.clear();
    _factories.clear();
  }

  /// Get a key for associating factories and instances with types and tags
  dynamic getKey(Type type, String? tag) {
    return tag != null ? '$type:$tag' : type;
  }
}