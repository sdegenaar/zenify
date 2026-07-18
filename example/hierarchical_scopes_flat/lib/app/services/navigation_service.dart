import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

/// Navigation service that manages breadcrumbs and navigation state
/// Demonstrates shared state across hierarchical scopes
class NavigationService {
  final _breadcrumbs = RxList<NavigationItem>([]);
  final _currentPath = ''.obs();
  final _navigationCount = 0.obs();

  // Global navigator key for navigation
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Reactive getters
  RxList<NavigationItem> get breadcrumbs => _breadcrumbs;
  Rx<String> get currentPath => _currentPath;
  Rx<int> get navigationCount => _navigationCount;

  /// Navigate to a route
  Future<T?> navigateTo<T extends Object?>(String route,
      {Map<String, dynamic>? arguments}) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      ZenLogger.logError(
          'Navigator not available. Make sure to set NavigationService.navigatorKey in your MaterialApp');
      return null;
    }

    try {
      _currentPath.value = route;
      _navigationCount.value++;

      ZenLogger.logInfo('Navigation: Navigating to $route');
      return await navigator.pushNamed(route, arguments: arguments);
    } catch (e) {
      ZenLogger.logError('Navigation failed to $route', e);
      return null;
    }
  }

  /// Navigate and replace current route
  Future<T?> navigateAndReplace<T extends Object?, TO extends Object?>(
    String route, {
    Map<String, dynamic>? arguments,
    TO? result,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      ZenLogger.logError('Navigator not available');
      return null;
    }

    try {
      _currentPath.value = route;
      _navigationCount.value++;

      ZenLogger.logInfo('Navigation: Replacing current route with $route');
      return await navigator.pushReplacementNamed(route,
          arguments: arguments, result: result);
    } catch (e) {
      ZenLogger.logError('Navigation replacement failed to $route', e);
      return null;
    }
  }

  /// Navigate and clear stack
  Future<T?> navigateAndClearStack<T extends Object?>(String route,
      {Map<String, dynamic>? arguments}) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      ZenLogger.logError('Navigator not available');
      return null;
    }

    try {
      _currentPath.value = route;
      _navigationCount.value++;

      // Clear breadcrumbs since we're clearing the stack
      clear();

      ZenLogger.logInfo('Navigation: Clearing stack and navigating to $route');
      return await navigator.pushNamedAndRemoveUntil(route, (route) => false,
          arguments: arguments);
    } catch (e) {
      ZenLogger.logError('Navigation with clear stack failed to $route', e);
      return null;
    }
  }

  /// Go back
  void goBack<T extends Object?>([T? result]) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      ZenLogger.logError('Navigator not available');
      return;
    }

    if (navigator.canPop()) {
      navigator.pop(result);
      popLast(); // Remove last breadcrumb
      ZenLogger.logInfo('Navigation: Going back');
    } else {
      ZenLogger.logWarning('Navigation: Cannot go back, no routes to pop');
    }
  }

  /// Check if can go back
  bool canGoBack() {
    final navigator = navigatorKey.currentState;
    return navigator?.canPop() ?? false;
  }

  /// Add a breadcrumb for navigation tracking
  void pushBreadcrumb(String title, String route,
      {Map<String, dynamic>? args}) {
    // Don't add duplicate breadcrumbs
    if (_breadcrumbs.isNotEmpty && _breadcrumbs.last.route == route) {
      return;
    }

    _breadcrumbs.add(NavigationItem(
      title: title,
      route: route,
      arguments: args,
      timestamp: DateTime.now(),
    ));

    _currentPath.value = route;
    _navigationCount.value++;

    ZenLogger.logInfo('Navigation: Added breadcrumb "$title" -> $route');
  }

  /// Remove breadcrumbs to a specific level
  void popToLevel(int level) {
    if (level >= 0 && level < _breadcrumbs.length) {
      final removed = _breadcrumbs.length - level;

      // Create a new list with only the items we want to keep
      final newBreadcrumbs = _breadcrumbs.take(level).toList();
      _breadcrumbs.value = newBreadcrumbs;

      // Update current path
      if (_breadcrumbs.isNotEmpty) {
        _currentPath.value = _breadcrumbs.last.route;
      } else {
        _currentPath.value = '/';
      }

      ZenLogger.logInfo(
          'Navigation: Removed $removed breadcrumbs, back to level $level');
    }
  }

  /// Pop the last breadcrumb
  void popLast() {
    if (_breadcrumbs.isNotEmpty) {
      final removed = _breadcrumbs.last; // Get the last item first

      // Remove the last item using reactive-friendly approach
      final newBreadcrumbs =
          _breadcrumbs.take(_breadcrumbs.length - 1).toList();
      _breadcrumbs.value = newBreadcrumbs;

      // Update current path
      if (_breadcrumbs.isNotEmpty) {
        _currentPath.value = _breadcrumbs.last.route;
      } else {
        _currentPath.value = '/';
      }

      ZenLogger.logInfo('Navigation: Removed breadcrumb "${removed.title}"');
    }
  }

  /// Clear all breadcrumbs
  void clear() {
    _breadcrumbs.clear();
    _currentPath.value = '/';
    ZenLogger.logInfo('Navigation: Cleared all breadcrumbs');
  }

  /// Get navigation depth
  int get depth => _breadcrumbs.length;

  /// Get current breadcrumb
  NavigationItem? get current =>
      _breadcrumbs.isNotEmpty ? _breadcrumbs.last : null;

  /// Get breadcrumb at specific level
  NavigationItem? getBreadcrumbAt(int level) {
    return (level >= 0 && level < _breadcrumbs.length)
        ? _breadcrumbs[level]
        : null;
  }

  /// Check if we're at a specific route
  bool isAtRoute(String route) => _currentPath.value == route;

  /// Get navigation statistics
  Map<String, dynamic> getStats() {
    return {
      'currentDepth': depth,
      'totalNavigations': _navigationCount.value,
      'currentPath': _currentPath.value,
      'breadcrumbCount': _breadcrumbs.length,
      'canGoBack': canGoBack(),
    };
  }

  void dispose() {
    _breadcrumbs.clear();
    ZenLogger.logInfo('NavigationService disposed');
  }
}

/// Navigation item representing a breadcrumb
class NavigationItem {
  final String title;
  final String route;
  final Map<String, dynamic>? arguments;
  final DateTime timestamp;

  NavigationItem({
    required this.title,
    required this.route,
    this.arguments,
    required this.timestamp,
  });

  @override
  String toString() => 'NavigationItem(title: $title, route: $route)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          route == other.route;

  @override
  int get hashCode => title.hashCode ^ route.hashCode;
}
