// lib/controllers/zen_route_observer.dart
import 'package:flutter/material.dart';
import '../core/zen_metrics.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../di/zen_di.dart';
import '../core/zen_scope.dart';

/// Navigator observer that automatically disposes controllers when routes are popped
/// and allows for custom route change callbacks
///
/// Features:
/// - Automatic controller disposal when routes are removed
/// - Route-to-controller mapping with scope support
/// - Tagged controller support
/// - Custom route change callbacks
/// - Performance metrics tracking
/// - Production-safe logging
///
/// Usage:
/// ```dart
/// final routeObserver = ZenRouteObserver(
///   onRouteChanged: (route, previousRoute) {
///     print('Route changed to: ${route?.settings.name}');
///   },
/// );
///
/// // Register controllers for routes
/// routeObserver.registerForRoute('/home', [HomeController]);
/// routeObserver.registerTaggedForRoute('/profile', ['profile-controller']);
///
/// MaterialApp(
///   navigatorObservers: [routeObserver],
///   ...
/// )
/// ```
class ZenRouteObserver extends NavigatorObserver {
  /// Map of route names to the controller types they use
  final Map<String, List<Type>> _routeControllers = {};

  /// Map of route names to the controller tags they use
  final Map<String, List<String>> _routeControllerTags = {};

  /// Map of route names to their associated scopes
  final Map<String, ZenScope> _routeScopes = {};

  /// Callback for when routes change
  final void Function(Route? route, Route? previousRoute)? onRouteChanged;

  /// Creates a ZenRouteObserver
  ///
  /// [onRouteChanged] - Optional callback that will be called whenever a route changes,
  /// providing access to both the current and previous routes.
  ZenRouteObserver({this.onRouteChanged});

  /// Register controllers for a specific route
  ///
  /// Controllers will be automatically disposed when the route is popped or removed.
  ///
  /// Example:
  /// ```dart
  /// routeObserver.registerForRoute(
  ///   '/home',
  ///   [HomeController, NavController],
  ///   scope: myScope,
  /// );
  /// ```
  void registerForRoute(String routeName, List<Type> controllerTypes,
      {ZenScope? scope}) {
    _routeControllers[routeName] = controllerTypes;

    if (scope != null) {
      _routeScopes[routeName] = scope;
    }

    // Changed from logDebug to logInfo - important configuration event
    ZenLogger.logInfo(
        'Registered ${controllerTypes.length} controllers for route $routeName${scope != null ? ' in scope ${scope.name ?? scope.id}' : ''}');
  }

  /// Register tagged controllers for a specific route
  ///
  /// Tagged controllers will be automatically disposed when the route is popped or removed.
  ///
  /// Example:
  /// ```dart
  /// routeObserver.registerTaggedForRoute(
  ///   '/profile',
  ///   ['profile-controller', 'user-data'],
  ///   scope: profileScope,
  /// );
  /// ```
  void registerTaggedForRoute(String routeName, List<String> controllerTags,
      {ZenScope? scope}) {
    _routeControllerTags[routeName] = controllerTags;

    if (scope != null) {
      _routeScopes[routeName] = scope;
    }

    // Changed from logDebug to logInfo - important configuration event
    ZenLogger.logInfo(
        'Registered ${controllerTags.length} tagged controllers for route $routeName${scope != null ? ' in scope ${scope.name ?? scope.id}' : ''}');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    // Notify listener of route change
    onRouteChanged?.call(route, previousRoute);

    // Only log if route logging is enabled AND log level permits
    if (ZenConfig.shouldLogRoutes) {
      final routeName = route.settings.name ?? 'unnamed';
      final previousRouteName = previousRoute?.settings.name ?? 'none';
      ZenLogger.logInfo('Route pushed: $routeName (from: $previousRouteName)');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    // Notify listener of route change
    onRouteChanged?.call(newRoute, oldRoute);

    // Only log if route logging is enabled AND log level permits
    if (ZenConfig.shouldLogRoutes) {
      final newRouteName = newRoute?.settings.name ?? 'unnamed';
      final oldRouteName = oldRoute?.settings.name ?? 'unnamed';
      ZenLogger.logInfo('Route replaced: $oldRouteName → $newRouteName');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    // Notify listener of route change
    onRouteChanged?.call(previousRoute, route);

    // Only log if route logging is enabled AND log level permits
    if (ZenConfig.shouldLogRoutes) {
      final routeName = route.settings.name ?? 'unnamed';
      final previousRouteName = previousRoute?.settings.name ?? 'none';
      ZenLogger.logInfo('Route popped: $routeName (to: $previousRouteName)');
    }

    // Dispose controllers associated with the popped route
    _disposeControllersForRoute(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    // Notify listener of route change
    onRouteChanged?.call(previousRoute, route);

    // Only log if route logging is enabled AND log level permits
    if (ZenConfig.shouldLogRoutes) {
      final routeName = route.settings.name ?? 'unnamed';
      ZenLogger.logInfo('Route removed: $routeName');
    }

    // Dispose controllers associated with the removed route
    _disposeControllersForRoute(route);
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didStartUserGesture(route, previousRoute);

    // Only log if navigation logging is enabled AND log level permits
    if (ZenConfig.shouldLogNavigation) {
      final routeName = route.settings.name ?? 'unnamed';
      ZenLogger.logDebug('Navigation gesture started on: $routeName');
    }
  }

  @override
  void didStopUserGesture() {
    super.didStopUserGesture();

    // Only log if navigation logging is enabled AND log level permits
    if (ZenConfig.shouldLogNavigation) {
      ZenLogger.logDebug('Navigation gesture stopped');
    }
  }

  /// Dispose controllers associated with a route
  void _disposeControllersForRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName == null) return;

    final routeScope = _routeScopes[routeName];

    try {
      // Dispose controllers by type
      if (_routeControllers.containsKey(routeName)) {
        for (final controllerType in _routeControllers[routeName]!) {
          bool disposed = false;

          if (routeScope != null) {
            // Delete from specific scope by type
            disposed = routeScope.deleteByType(controllerType, force: true);
          } else {
            // Delete from root scope by type
            disposed = Zen.rootScope.deleteByType(controllerType, force: true);
          }

          // Changed from logDebug to logInfo - important lifecycle event
          if (disposed) {
            ZenLogger.logInfo(
                'Auto-disposed controller $controllerType for route $routeName');
          } else {
            ZenLogger.logDebug(
                'Controller $controllerType not found for route $routeName (may have been manually disposed)');
          }

          // Track metrics
          if (disposed && ZenConfig.enablePerformanceMetrics) {
            ZenMetrics.recordControllerDisposal(controllerType);
          }
        }
      }

      // Dispose controllers by tag
      if (_routeControllerTags.containsKey(routeName)) {
        for (final tag in _routeControllerTags[routeName]!) {
          bool disposed = false;

          if (routeScope != null) {
            // Delete from specific scope by tag
            disposed = _deleteByTagFromScope(tag, routeScope);
          } else {
            // Delete from root scope by tag
            disposed = _deleteByTagFromScope(tag, Zen.rootScope);
          }

          // Changed from logDebug to logInfo - important lifecycle event
          if (disposed) {
            ZenLogger.logInfo(
                'Auto-disposed tagged controller \'$tag\' for route $routeName');
          } else {
            ZenLogger.logDebug(
                'Tagged controller \'$tag\' not found for route $routeName (may have been manually disposed)');
          }
        }
      }

      // Clean up route scope if it's empty and was created for this route
      if (routeScope != null && _isRouteSpecificScope(routeName, routeScope)) {
        _cleanupRouteScope(routeName, routeScope);
      }
    } catch (e, stack) {
      ZenLogger.logError(
          'Error disposing controllers for route $routeName', e, stack);
    }
  }

  /// Delete a dependency by tag from a specific scope
  bool _deleteByTagFromScope(String tag, ZenScope scope) {
    try {
      return scope.deleteByTag(tag, force: true);
    } catch (e) {
      ZenLogger.logWarning(
          'Failed to delete tag \'$tag\' from scope ${scope.name ?? scope.id}: $e');
      return false;
    }
  }

  /// Check if a scope was created specifically for a route
  bool _isRouteSpecificScope(String routeName, ZenScope scope) {
    // Simple heuristic: if scope name contains route name, it's likely route-specific
    return scope.name?.contains(routeName) == true;
  }

  /// Clean up a route-specific scope
  void _cleanupRouteScope(String routeName, ZenScope scope) {
    try {
      if (scope.isDisposed) return;

      final dependencies = scope.getAllDependencies();
      if (dependencies.isEmpty) {
        scope.dispose();
        _routeScopes.remove(routeName);

        // Changed from logDebug to logInfo - important lifecycle event
        ZenLogger.logInfo('Disposed empty route scope for $routeName');
      } else {
        ZenLogger.logDebug(
            'Route scope for $routeName still has ${dependencies.length} dependencies, keeping alive');
      }
    } catch (e) {
      ZenLogger.logError('Failed to cleanup route scope for $routeName', e);
    }
  }

  /// Clear all route registrations
  ///
  /// Useful for resetting the observer state during testing or app reconfiguration.
  void clearAllRoutes() {
    _routeControllers.clear();
    _routeControllerTags.clear();
    _routeScopes.clear();

    // Changed from logDebug to logInfo - important configuration event
    ZenLogger.logInfo('Cleared all route controller registrations');
  }

  /// Get debug information about registered routes
  ///
  /// Returns a map containing:
  /// - `routeControllers`: Map of route names to controller types
  /// - `routeControllerTags`: Map of route names to controller tags
  /// - `routeScopes`: Map of route names to scope names/IDs
  ///
  /// Useful for debugging route configuration issues.
  Map<String, dynamic> getDebugInfo() {
    return {
      'routeControllers': _routeControllers
          .map((k, v) => MapEntry(k, v.map((t) => t.toString()).toList())),
      'routeControllerTags': Map.from(_routeControllerTags),
      'routeScopes': _routeScopes.map((k, v) => MapEntry(k, v.name ?? v.id)),
      'totalRoutes': _routeControllers.length + _routeControllerTags.length,
    };
  }

  /// Get all registered route names
  Set<String> getRegisteredRoutes() {
    return {..._routeControllers.keys, ..._routeControllerTags.keys};
  }

  /// Check if a route has registered controllers
  bool hasControllersForRoute(String routeName) {
    return _routeControllers.containsKey(routeName) ||
        _routeControllerTags.containsKey(routeName);
  }

  /// Get the scope associated with a route (if any)
  ZenScope? getScopeForRoute(String routeName) {
    return _routeScopes[routeName];
  }
}
