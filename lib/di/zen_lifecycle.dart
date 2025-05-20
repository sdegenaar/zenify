// lib/di/zen_lifecycle.dart
import 'package:flutter/widgets.dart';
import 'package:zenify/di/zen_di.dart';

import '../controllers/zen_controller.dart' show ZenController;
import '../core/zen_config.dart';
import '../core/zen_logger.dart' show ZenLogger;
import '../core/zen_scope.dart';

/// Manages lifecycle events for controllers
class ZenLifecycleManager {
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
          'Error initializing controller ${controller.runtimeType}',
          e, stack
      );
    }
  }

  /// Initialize the app lifecycle observer
  void initLifecycleObserver() {
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _ZenAppLifecycleObserver();
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Zen lifecycle observer initialized');
      }
    }
  }

  /// Start auto dispose timer for cleaning up unused controllers
  void startAutoDisposeTimer(
      List<ZenController> Function() getAllControllers,
      ZenScope? Function(ZenController) findControllerScope,
      ) {
    Future.delayed(ZenConfig.controllerCacheExpiry, () {
      if (!ZenConfig.enableAutoDispose) return;

      final now = DateTime.now();
      final controllers = getAllControllers();

      for (final controller in controllers) {
        if (controller.isDisposed) continue;

        // Try to find the scope this controller is in
        ZenScope? controllerScope = findControllerScope(controller);
        if (controllerScope == null) continue;

        // Skip if permanent
        final tag = controllerScope.getTagForInstance(controller);
        final type = controller.runtimeType;

        if (controllerScope.isPermanent(type: type, tag: tag)) {
          continue;
        }

        // Check if use count is 0
        final useCount = tag != null
            ? controllerScope.getUseCountByType(type: type, tag: tag)
            : controllerScope.getUseCountByType(type: type, tag: null);

        if (useCount > 0) continue;

        // Check if expired
        final age = now.difference(controller.createdAt);
        if (age > ZenConfig.controllerCacheExpiry) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug('Auto-disposing unused controller $type${tag != null ? ' with tag $tag' : ''} after ${age.inSeconds}s');
          }

          if (tag != null) {
            controllerScope.deleteByTag(tag);
          } else {
            controllerScope.deleteByType(type);
          }
        }
      }

      // Schedule next check
      startAutoDisposeTimer(getAllControllers, findControllerScope);
    });
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
    // Forward lifecycle events to all controllers
    final allControllers = Zen.allControllers;

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
      List<ZenController> controllers,
      Function(ZenController) callback
      ) {
    for (final controller in controllers) {
      if (!controller.isDisposed) {
        try {
          callback(controller);
        } catch (e, stack) {
          ZenLogger.logError(
              'Error in lifecycle method for controller ${controller.runtimeType}',
              e, stack
          );
        }
      }
    }
  }
}