// lib/zen_state/zen_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';

/// Base controller class similar to GetX controller
abstract class ZenController {
  final List<VoidCallback> _disposers = [];
  final DateTime _createdAt = DateTime.now();
  bool _disposed = false;

  DateTime get createdAt => _createdAt;
  bool get isDisposed => _disposed;

  void addDisposer(VoidCallback callback) {
    if (_disposed) {
      ZenLogger.logWarning('Attempted to add disposer to disposed controller $runtimeType');
      return;
    }
    _disposers.add(callback);
  }

  /// Adds a Riverpod listener to the disposers
  void addListener<T>(
      ProviderListenable<T> provider,
      void Function(T) listener, {
        ProviderContainer? container
      }) {
    final subscription = (container ?? Zen.container).listen<T>(
      provider,
          (_, value) => listener(value),
    );
    addDisposer(() => subscription.close());
  }

  // Helper to create a worker that will be auto-disposed
  VoidCallback createWorker(VoidCallback disposer) {
    addDisposer(disposer);
    return disposer;
  }

  // Maps update IDs to their listener callbacks
  final Map<String, Set<VoidCallback>> _updateListeners = {};
  
  /// Register a listener for a specific update ID
  void addUpdateListener(String id, VoidCallback listener) {
    _updateListeners.putIfAbsent(id, () => {}).add(listener);
  }
  
  /// Remove a listener for a specific update ID
  void removeUpdateListener(String id, VoidCallback listener) {
    _updateListeners[id]?.remove(listener);
    if (_updateListeners[id]?.isEmpty ?? false) {
      _updateListeners.remove(id);
    }
  }
  
  /// Trigger an update for a specific ID
  void update([List<String>? ids]) {
    if (ids == null || ids.isEmpty) {
      // Update all listeners if no IDs specified
      _updateListeners.values.expand((listeners) => listeners).forEach((listener) => listener());
    } else {
      // Update only the specified IDs
      for (final id in ids) {
        _updateListeners[id]?.forEach((listener) => listener());
      }
    }
  }

  void dispose() {
    if (_disposed) {
      ZenLogger.logWarning('Controller $runtimeType already disposed');
      return;
    }

    for (final disposer in _disposers) {
      try {
        disposer();
      } catch (e, stack) {
        ZenLogger.logError('Error disposing controller $runtimeType', e, stack);
      }
    }

    _disposers.clear();
    _disposed = true;

    // Track metrics
    ZenMetrics.recordControllerDisposal(runtimeType);

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Controller $runtimeType disposed');
    }
    _updateListeners.clear();
  }
}

/// Dependency injection container similar to Get.put/find
/// Dependency injection container similar to Get.put/find
class Zen {
  Zen._(); // Private constructor

  // Will be initialized with the app's ProviderContainer in main.dart
  static late ProviderContainer _container;
  static final Map<Type, ZenController> _controllers = {};
  static final Map<String, ZenController> _taggedControllers = {};
  static final Map<Type, int> _typeUseCount = {}; // Use count for Type keys
  static final Map<String, int> _tagUseCount = {}; // Use count for String keys
  static final Map<Type, Function> _typeFactories = {}; // For lazy instantiation by Type
  static final Map<String, Function> _taggedFactories = {}; // For lazy instantiation by tag

  // Initialize with the app's root container
  static void init(ProviderContainer container) {
    _container = container;

    if (ZenConfig.enableAutoDispose) {
      _startAutoDisposeTimer();
    }
  }

  // Similar to Get.put with optional tag
  static T put<T extends ZenController>(
      T controller, {
        String? tag,
        bool permanent = false,
      }) {
    if (tag != null) {
      _taggedControllers[tag] = controller;
      // Set initial use count
      _tagUseCount[tag] = permanent ? -1 : 0; // -1 means permanent
    } else {
      _controllers[T] = controller;
      // Set initial use count
      _typeUseCount[T] = permanent ? -1 : 0; // -1 means permanent
    }

    // Track metrics
    ZenMetrics.recordControllerCreation(T);

    return controller;
  }

  // Similar to Get.find with optional tag
  static T? find<T extends ZenController>({String? tag}) {
    if (tag != null) {
      return _taggedControllers[tag] as T?;
    }
    return _controllers[T] as T?;
  }

  // Get controller, create if it doesn't exist (similar to GetX's Get.find with true)
  static T get<T extends ZenController>({String? tag, bool permanent = false}) {
    final existing = find<T>(tag: tag);
    if (existing != null) {
      return existing;
    }

    // Check for factory
    Function? factory;
    if (tag != null) {
      factory = _taggedFactories[tag];
    } else {
      factory = _typeFactories[T];
    }

    if (factory != null) {
      final controller = factory() as T;
      return put<T>(controller, tag: tag, permanent: permanent);
    }

    throw Exception('Controller $T${tag != null ? ' with tag $tag' : ''} not found and no factory registered');
  }

  // Register a factory for lazy creation
  static void lazyPut<T extends ZenController>(
      T Function() factory, {
        String? tag,
        bool permanent = false,
      }) {
    if (tag != null) {
      _taggedFactories[tag] = factory;
    } else {
      _typeFactories[T] = factory;
    }

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Factory registered for $T${tag != null ? ' with tag $tag' : ''}');
    }
  }

  // Similar to Get.delete
  static bool delete<T extends ZenController>({String? tag, bool force = false}) {
    if (tag != null) {
      final controller = _taggedControllers[tag];
      if (controller != null) {
        // Check if permanent
        if (_tagUseCount[tag] == -1 && !force) {
          ZenLogger.logWarning('Attempted to delete permanent controller $T with tag $tag. Use force=true to override.');
          return false;
        }

        _taggedControllers.remove(tag);
        _taggedFactories.remove(tag);
        _tagUseCount.remove(tag);
        controller.dispose();
        return true;
      }
    } else {
      final controller = _controllers[T];
      if (controller != null) {
        // Check if permanent
        if (_typeUseCount[T] == -1 && !force) {
          ZenLogger.logWarning('Attempted to delete permanent controller $T. Use force=true to override.');
          return false;
        }

        _controllers.remove(T);
        _typeFactories.remove(T);
        _typeUseCount.remove(T);
        controller.dispose();
        return true;
      }
    }
    return false;
  }

  // Delete by tag only
  static bool deleteByTag(String tag, {bool force = false}) {
    final controller = _taggedControllers[tag];
    if (controller != null) {
      // Check if permanent
      if (_tagUseCount[tag] == -1 && !force) {
        ZenLogger.logWarning('Attempted to delete permanent controller with tag $tag. Use force=true to override.');
        return false;
      }

      _taggedControllers.remove(tag);
      _taggedFactories.remove(tag);
      _tagUseCount.remove(tag);
      controller.dispose();
      return true;
    }
    return false;
  }

  // Delete all controllers
  static void deleteAll({bool force = false}) {
    // Delete by Type
    final typeKeysToDelete = _controllers.keys.where(
            (type) => force || _typeUseCount[type] != -1
    ).toList();

    for (final type in typeKeysToDelete) {
      final controller = _controllers[type];
      if (controller != null) {
        controller.dispose();
      }
    }

    // Delete by Tag
    final tagKeysToDelete = _taggedControllers.keys.where(
            (tag) => force || _tagUseCount[tag] != -1
    ).toList();

    for (final tag in tagKeysToDelete) {
      final controller = _taggedControllers[tag];
      if (controller != null) {
        controller.dispose();
      }
    }

    // Clear maps
    _controllers.removeWhere((type, _) => typeKeysToDelete.contains(type));
    _taggedControllers.removeWhere((tag, _) => tagKeysToDelete.contains(tag));
    _typeFactories.removeWhere((type, _) => typeKeysToDelete.contains(type));
    _taggedFactories.removeWhere((tag, _) => tagKeysToDelete.contains(tag));

    // Clear use count
    for (final key in typeKeysToDelete) {
      _typeUseCount.remove(key);
    }
    for (final key in tagKeysToDelete) {
      _tagUseCount.remove(key);
    }
  }

  // Track usage count (for auto-disposal)
  static int incrementUseCount<T extends ZenController>({String? tag}) {
    if (tag != null) {
      final count = (_tagUseCount[tag] ?? 0) + 1;
      _tagUseCount[tag] = count;
      return count;
    } else {
      final count = (_typeUseCount[T] ?? 0) + 1;
      _typeUseCount[T] = count;
      return count;
    }
  }

  static int decrementUseCount<T extends ZenController>({String? tag}) {
    if (tag != null) {
      if (!_tagUseCount.containsKey(tag) || _tagUseCount[tag] == -1) {
        return -1; // Permanent or not found
      }

      final count = (_tagUseCount[tag] ?? 1) - 1;
      _tagUseCount[tag] = count;
      return count;
    } else {
      if (!_typeUseCount.containsKey(T) || _typeUseCount[T] == -1) {
        return -1; // Permanent or not found
      }

      final count = (_typeUseCount[T] ?? 1) - 1;
      _typeUseCount[T] = count;
      return count;
    }
  }

  // Auto-dispose unused controllers after a timeout
  static void _startAutoDisposeTimer() {
    Future.delayed(ZenConfig.controllerCacheExpiry, () {
      if (!ZenConfig.enableAutoDispose) return;

      final now = DateTime.now();

      // Check controllers by Type
      for (final entry in _controllers.entries) {
        final type = entry.key;
        final controller = entry.value;

        // Skip if permanent or in use
        if (_typeUseCount[type] == -1 || (_typeUseCount[type] ?? 0) > 0) continue;

        // Check if expired
        final age = now.difference(controller.createdAt);
        if (age > ZenConfig.controllerCacheExpiry) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug('Auto-disposing unused controller $type after ${age.inSeconds}s');
          }
          // Fix: Use a generic Type parameter here
          delete<ZenController>();
        }
      }

      // Check controllers by Tag
      for (final entry in _taggedControllers.entries) {
        final tag = entry.key;
        final controller = entry.value;

        // Skip if permanent or in use
        if (_tagUseCount[tag] == -1 || (_tagUseCount[tag] ?? 0) > 0) continue;

        // Check if expired
        final age = now.difference(controller.createdAt);
        if (age > ZenConfig.controllerCacheExpiry) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug('Auto-disposing unused controller with tag $tag after ${age.inSeconds}s');
          }
          deleteByTag(tag);
        }
      }

      // Schedule next check
      _startAutoDisposeTimer();
    });
  }

  // Access the ProviderContainer for raw Riverpod usage
  static ProviderContainer get container => _container;

  /// Delete a controller by its runtime Type
  /// This is provided for backward compatibility with code that uses Type objects
  static bool deleteByType(Type type) {
    // Check if the type exists in the controllers map
    if (_controllers.containsKey(type)) {
      final controller = _controllers[type]!;
      controller.dispose();
      _controllers.remove(type);
      
      // Update tracking counts
      if (_typeUseCount.containsKey(type)) {
        _typeUseCount.remove(type);
      }
      
      return true;
    }
    return false;
  }
}