// lib/di/zen_lifecycle.dart
import 'package:flutter/widgets.dart';
import '../controllers/zen_controller.dart';
import '../controllers/zen_service.dart';
import '../core/zen_logger.dart';
import '../core/zen_scope.dart';
import '../query/core/zen_query_cache.dart';
import 'zen_di.dart';

/// Manages lifecycle events for controllers
class ZenLifecycleManager {
  // Singleton instance
  static final ZenLifecycleManager instance = ZenLifecycleManager._();

  // Private constructor
  ZenLifecycleManager._();

  // App lifecycle observer
  _ZenAppLifecycleObserver? _lifecycleObserver;

  // Generic lifecycle listeners
  final List<void Function(AppLifecycleState)> _lifecycleListeners = [];

  void initializeController(ZenController controller) {
    try {
      if (!controller.isInitialized) {
        controller.onInit();

        // Schedule onReady to be called after the current frame (if in widget context)
        // For pure DI tests, call onReady immediately
        try {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!controller.isDisposed) {
              controller.onReady();
            }
          });
        } catch (_) {
          // WidgetsBinding not initialized - we're in a pure unit test
          // Call onReady immediately
          if (!controller.isDisposed) {
            controller.onReady();
          }
        }
      }
    } catch (e, stack) {
      ZenLogger.logError(
          'Error initializing controller ${controller.runtimeType}', e, stack);
    }
  }

  // New: provide a consistent entry point for services
  void initializeService(ZenService service) {
    // Initialize immediately (services are long-lived)
    service.ensureInitialized();
  }

  /// Initialize the app lifecycle observer
  void initLifecycleObserver() {
    if (_lifecycleObserver == null) {
      try {
        _lifecycleObserver = _ZenAppLifecycleObserver();
        WidgetsBinding.instance.addObserver(_lifecycleObserver!);
        ZenLogger.logDebug('Zen lifecycle observer initialized');
      } catch (_) {
        // WidgetsBinding not initialized - skip lifecycle observer for pure unit tests
        _lifecycleObserver = null;
      }
    }
  }

  /// Add a listener for app lifecycle changes
  void addLifecycleListener(void Function(AppLifecycleState) listener) {
    _lifecycleListeners.add(listener);
  }

  /// Remove a listener for app lifecycle changes
  void removeLifecycleListener(void Function(AppLifecycleState) listener) {
    _lifecycleListeners.remove(listener);
  }

  /// Get all controllers from all scopes
  List<ZenController> _getAllControllers() {
    final controllers = <ZenController>[];

    // Get all scopes - start with root and traverse hierarchy
    final allScopes = _getAllScopes();

    for (final scope in allScopes) {
      if (!scope.isDisposed) {
        controllers.addAll(scope.findAllOfType<ZenController>());
      }
    }

    return controllers;
  }

  /// Get all scopes in the system by traversing from root
  List<ZenScope> _getAllScopes() {
    final allScopes = <ZenScope>[];
    final visited = <String>{};

    void traverseScope(ZenScope scope) {
      if (visited.contains(scope.id) || scope.isDisposed) return;

      visited.add(scope.id);
      allScopes.add(scope);

      // Traverse all child scopes
      for (final child in scope.childScopes) {
        traverseScope(child);
      }
    }

    // Start from root scope
    traverseScope(Zen.rootScope);

    return allScopes;
  }

  /// Clean up resources
  void dispose() {
    if (_lifecycleObserver != null) {
      // Only remove observer if WidgetsBinding is initialized
      // This allows pure DI tests without requiring Flutter bindings
      try {
        WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      } catch (_) {
        // WidgetsBinding not initialized - nothing to remove
      }
      _lifecycleObserver = null;
    }
    _lifecycleListeners.clear();
  }
}

/// Monitors app lifecycle events and forwards them to controllers
class _ZenAppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 1. Notify generic listeners (like ZenQueryCache)
    for (final listener in ZenLifecycleManager.instance._lifecycleListeners) {
      try {
        listener(state);
      } catch (e, stack) {
        ZenLogger.logError('Error in lifecycle listener', e, stack);
      }
    }

    // 2. Notify controllers
    // Get all controllers from lifecycle manager
    final allControllers = ZenLifecycleManager.instance._getAllControllers();

    switch (state) {
      case AppLifecycleState.resumed:
        _notifyControllers(allControllers, (c) => c.onResume());
        _resumeQueries();
        break;
      case AppLifecycleState.inactive:
        _notifyControllers(allControllers, (c) => c.onInactive());
        _pauseQueries();
        break;
      case AppLifecycleState.paused:
        _notifyControllers(allControllers, (c) => c.onPause());
        _pauseQueries();
        break;
      case AppLifecycleState.detached:
        _notifyControllers(allControllers, (c) => c.onDetached());
        break;
      case AppLifecycleState.hidden:
        _notifyControllers(allControllers, (c) => c.onHidden());
        _pauseQueries();
        break;
    }
  }

  void _pauseQueries() {
    try {
      final queries = ZenQueryCache.instance.getAllQueries();
      for (final query in queries) {
        if (query.config.autoPauseOnBackground) {
          query.pause();
        }
      }
      ZenLogger.logDebug('Paused ${queries.length} queries');
    } catch (e, stack) {
      ZenLogger.logError('Error pausing queries', e, stack);
    }
  }

  void _resumeQueries() {
    try {
      final queries = ZenQueryCache.instance.getAllQueries();
      for (final query in queries) {
        query.resume();
      }
      ZenLogger.logDebug('Resumed ${queries.length} queries');
    } catch (e, stack) {
      ZenLogger.logError('Error resuming queries', e, stack);
    }
  }

  void _notifyControllers(
      List<ZenController> controllers, Function(ZenController) callback) {
    for (final controller in controllers) {
      if (!controller.isDisposed) {
        try {
          callback(controller);
        } catch (e, stack) {
          ZenLogger.logError(
              'Error in lifecycle method for controller ${controller.runtimeType}',
              e,
              stack);
        }
      }
    }
  }
}
