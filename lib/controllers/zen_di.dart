// lib/controllers/zen_di.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../core/zen_metrics.dart';
import 'zen_controller.dart';

/// Type-safe reference to a controller
/// Enhances type safety and editor autocomplete when working with controllers
class ControllerRef<T extends ZenController> {
  final String? tag;

  const ControllerRef({this.tag});

  /// Get the controller instance
  /// Creates the controller if it doesn't exist and a factory is registered
  T get() => Zen.get<T>(tag: tag);

  /// Get the controller if it exists, otherwise null
  T? find() => Zen.find<T>(tag: tag);

  /// Register a controller instance
  T put(T controller, {bool permanent = false}) =>
      Zen.put<T>(controller, tag: tag, permanent: permanent);

  /// Register a factory for lazy creation
  void lazyPut(T Function() factory, {bool permanent = false}) =>
      Zen.lazyPut<T>(factory, tag: tag, permanent: permanent);

  /// Delete the controller
  bool delete({bool force = false}) =>
      Zen.delete<T>(tag: tag, force: force);

  /// Check if controller exists
  bool exists() => find() != null;

  /// Increment use count
  int incrementUseCount() => Zen.incrementUseCount<T>(tag: tag);

  /// Decrement use count
  int decrementUseCount() => Zen.decrementUseCount<T>(tag: tag);
}

/// Dependency injection container similar to Get.put/find
class Zen {
  Zen._(); // Private constructor

  // Will be initialized with the app's root container
  static late ProviderContainer _container;
  static final Map<Type, ZenController> _controllers = {};
  static final Map<String, ZenController> _taggedControllers = {};
  static final Map<Type, int> _typeUseCount = {}; // Use count for Type keys
  static final Map<String, int> _tagUseCount = {}; // Use count for String keys
  static final Map<Type, Function> _typeFactories = {}; // For lazy instantiation by Type
  static final Map<String, Function> _taggedFactories = {}; // For lazy instantiation by tag
  static _ZenAppLifecycleObserver? _lifecycleObserver;

  // Initialize with the app's root container
  static void init(ProviderContainer container) {
    _container = container;

    if (ZenConfig.enableAutoDispose) {
      _startAutoDisposeTimer();
    }

    // Set up app lifecycle observer
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _ZenAppLifecycleObserver();
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Zen lifecycle observer initialized');
      }
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

    // Call lifecycle methods
    try {
      controller.onInit();

      // Schedule onReady to be called after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.isDisposed) {
          controller.onReady();
        }
      });
    } catch (e, stack) {
      ZenLogger.logError('Error initializing controller $T', e, stack);
    }

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

  /// Create a type-safe controller reference
  /// This provides enhanced type safety and editor autocomplete
  static ControllerRef<T> ref<T extends ZenController>({String? tag}) {
    return ControllerRef<T>(tag: tag);
  }

  /// Register a controller and return a type-safe reference
  static ControllerRef<T> putRef<T extends ZenController>(T controller, {String? tag, bool permanent = false}) {
    put<T>(controller, tag: tag, permanent: permanent);
    return ref<T>(tag: tag);
  }

  /// Register a factory and return a type-safe reference
  static ControllerRef<T> lazyRef<T extends ZenController>(T Function() factory, {String? tag, bool permanent = false}) {
    lazyPut<T>(factory, tag: tag, permanent: permanent);
    return ref<T>(tag: tag);
  }

  /// Clean up resources when app is terminating
  static void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }

    // Clean up all controllers
    deleteAll(force: true);
  }

  /// Get all active controllers for management and debugging
  static List<ZenController> get allControllers {
    return [
      ..._controllers.values,
      ..._taggedControllers.values,
    ];
  }

  /// Get the current use count for a controller type or tag
  static int getUseCount<T extends ZenController>({String? tag}) {
    if (tag != null) {
      // Use count for tagged controller
      return _tagUseCount[tag] ?? 0;
    } else {
      // Use count for type-based controller
      return _typeUseCount[T] ?? 0;
    }
  }
}

/// Extension methods for the ZenController class
extension ZenControllerExtension on ZenController {
  /// Create a typed reference to this controller instance
  ControllerRef<T> createRef<T extends ZenController>({String? tag, bool permanent = false}) {
    if (this is T) {
      return Zen.putRef<T>(this as T, tag: tag, permanent: permanent);
    }
    throw Exception('Controller is not of type $T');
  }
}

/// Monitors app lifecycle events and forwards them to controllers
class _ZenAppLifecycleObserver extends WidgetsBindingObserver {
  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Forward lifecycle events to all controllers
    final allControllers = Zen.allControllers;

    switch (state) {
      case AppLifecycleState.resumed:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onResume();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onResume for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.inactive:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onInactive();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onInactive for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.paused:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onPause();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onPause for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.detached:
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              controller.onDetached();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onDetached for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
      case AppLifecycleState.hidden:
      // The app is currently hidden but still running (e.g. on iOS when showing the app switcher)
        for (final controller in allControllers) {
          if (!controller.isDisposed) {
            try {
              // We can decide to call a specific method here, or use onInactive as it's similar
              // For now, let's add a specific method to ZenController
              controller.onHidden();
            } catch (e, stack) {
              ZenLogger.logError(
                  'Error in onHidden for controller ${controller.runtimeType}',
                  e, stack
              );
            }
          }
        }
        break;
    }
  }
}