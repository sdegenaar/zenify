// lib/di/zen_lifecycle.dart
import 'package:flutter/widgets.dart';
import '../controllers/zen_controller.dart';
import '../controllers/zen_service.dart';
import '../core/zen_logger.dart';
import '../core/zen_scope.dart';
import 'zen_di.dart';

/// Manages lifecycle events for controllers
class ZenLifecycleManager {
  // Singleton instance
  static final ZenLifecycleManager instance = ZenLifecycleManager._();

  // Private constructor
  ZenLifecycleManager._();

  // App lifecycle observer
  _ZenAppLifecycleObserver? _lifecycleObserver;

  /// Initialize a controller with lifecycle hooks
  void initializeController(ZenController controller) {
    try {
      controller.onInit();

      // Schedule onReady to be called after the current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.isDisposed) {
          controller.onReady();
        }
      });
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
      _lifecycleObserver = _ZenAppLifecycleObserver();
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);

      ZenLogger.logDebug('Zen lifecycle observer initialized');
    }
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
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
  }
}

/// Monitors app lifecycle events and forwards them to controllers
class _ZenAppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Get all controllers from lifecycle manager
    final allControllers = ZenLifecycleManager.instance._getAllControllers();

    switch (state) {
      case AppLifecycleState.resumed:
        _notifyControllers(allControllers, (c) => c.onResume());
        break;
      case AppLifecycleState.inactive:
        _notifyControllers(allControllers, (c) => c.onInactive());
        break;
      case AppLifecycleState.paused:
        _notifyControllers(allControllers, (c) => c.onPause());
        break;
      case AppLifecycleState.detached:
        _notifyControllers(allControllers, (c) => c.onDetached());
        break;
      case AppLifecycleState.hidden:
        _notifyControllers(allControllers, (c) => c.onHidden());
        break;
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
