// lib/zenify/zen_route_observer.dart
import 'package:flutter/material.dart';
import '../core/zen_metrics.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../di/zen_di.dart';

/// Navigator observer that automatically disposes controllers when routes are popped
class ZenRouteObserver extends NavigatorObserver {
  /// Map of route names to the controller types they use
  final Map<String, List<Type>> _routeControllers = {};

  /// Map of route names to the controller tags they use
  final Map<String, List<String>> _routeControllerTags = {};

  /// Register controllers for a specific route
  void registerForRoute(String routeName, List<Type> controllerTypes) {
    _routeControllers[routeName] = controllerTypes;

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Registered ${controllerTypes.length} controllers for route $routeName');
    }
  }

  /// Register tagged controllers for a specific route
  void registerTaggedForRoute(String routeName, List<String> controllerTags) {
    _routeControllerTags[routeName] = controllerTags;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    final routeName = route.settings.name;
    if (routeName != null) {
      // Dispose controllers by type
      if (_routeControllers.containsKey(routeName)) {
        for (final controllerType in _routeControllers[routeName]!) {
          if (ZenConfig.enableDebugLogs) {
            ZenLogger.logDebug('Auto-disposing controller $controllerType for route $routeName');
          }

          // Use the deleteByType method instead
          final result = Zen.deleteByType(controllerType);

          // Track metrics
          if (result) {
            ZenMetrics.recordControllerDisposal(controllerType);
          }
        }
      }

      // Dispose controllers by tag
      if (_routeControllerTags.containsKey(routeName)) {
        for (final tag in _routeControllerTags[routeName]!) {
          Zen.deleteByTag(tag);
        }
      }
    }
  }
}