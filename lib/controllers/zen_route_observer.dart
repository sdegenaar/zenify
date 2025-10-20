// lib/zenify/zen_route_observer.dart
import 'package:flutter/material.dart';
import '../core/zen_metrics.dart';
import '../core/zen_logger.dart';
import '../core/zen_config.dart';
import '../di/zen_di.dart';
import '../core/zen_scope.dart';

/// Navigator observer that automatically disposes controllers when routes are popped
/// and allows for custom route change callbacks
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
  void registerForRoute(String routeName, List<Type> controllerTypes,
      {ZenScope? scope}) {
    _routeControllers[routeName] = controllerTypes;

    if (scope != null) {
      _routeScopes[routeName] = scope;
    }

    ZenLogger.logDebug(
        'Registered ${controllerTypes.length} controllers for route $routeName${scope != null ? ' in scope ${scope.name ?? scope.id}' : ''}');
  }

  /// Register tagged controllers for a specific route
  void registerTaggedForRoute(String routeName, List<String> controllerTags,
      {ZenScope? scope}) {
    _routeControllerTags[routeName] = controllerTags;

    if (scope != null) {
      _routeScopes[routeName] = scope;
    }

    ZenLogger.logDebug(
        'Registered ${controllerTags.length} tagged controllers for route $routeName${scope != null ? ' in scope ${scope.name ?? scope.id}' : ''}');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    // Notify listener of route change
    onRouteChanged?.call(route, previousRoute);

    ZenLogger.logDebug('Route pushed: ${route.settings.name ?? 'unnamed'}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    // Notify listener of route change
    onRouteChanged?.call(newRoute, oldRoute);

    ZenLogger.logDebug(
        'Route replaced: ${oldRoute?.settings.name ?? 'unnamed'} -> ${newRoute?.settings.name ?? 'unnamed'}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    // Notify listener of route change
    onRouteChanged?.call(previousRoute, route);

    _disposeControllersForRoute(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    // Notify listener of route change
    onRouteChanged?.call(previousRoute, route);

    _disposeControllersForRoute(route);
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

          ZenLogger.logDebug(
              'Auto-disposing controller $controllerType for route $routeName: ${disposed ? 'success' : 'not found'}');

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

          ZenLogger.logDebug(
              'Auto-disposing tagged controller \'$tag\' for route $routeName: ${disposed ? 'success' : 'not found'}');
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

        ZenLogger.logDebug('Disposed empty route scope for $routeName');
      } else {
        ZenLogger.logDebug(
            'Route scope for $routeName still has ${dependencies.length} dependencies, keeping alive');
      }
    } catch (e) {
      ZenLogger.logError('Failed to cleanup route scope for $routeName', e);
    }
  }

  /// Clear all route registrations
  void clearAllRoutes() {
    _routeControllers.clear();
    _routeControllerTags.clear();
    _routeScopes.clear();

    ZenLogger.logDebug('Cleared all route controller registrations');
  }

  /// Get debug information about registered routes
  Map<String, dynamic> getDebugInfo() {
    return {
      'routeControllers': _routeControllers
          .map((k, v) => MapEntry(k, v.map((t) => t.toString()).toList())),
      'routeControllerTags': Map.from(_routeControllerTags),
      'routeScopes': _routeScopes.map((k, v) => MapEntry(k, v.name ?? v.id)),
    };
  }
}
